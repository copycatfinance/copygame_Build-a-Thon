// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ITokenManagerAction.sol";
import "./meta-transactions/NativeMetaTransaction.sol";
import "./meta-transactions/ContextMixin.sol";

import "../lib/SafeERC20.sol";

interface IMintableERC20 is IERC20 {
  function mint(address _to, uint256 _amount) external;
  function burn(uint256 _amount) external;
}

interface IMintableERC721 is IERC721 {
  function mint(address _to, uint256 _tokenId, bytes memory _data) external;
  function burn(uint256 _tokenId) external;
}

interface IMintableERC1155 is IERC1155 {
  function mint(address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) external;
  function burn(uint256 _tokenId, uint256 _amount) external;
}

// This contract is for interaction with backend for depositing, withdrawing and other transaction that require backend
contract Marketplace is Ownable, ERC721Holder, ERC1155Holder, ContextMixin, NativeMetaTransaction {
  using SafeERC20 for IERC20;
  using SafeERC20 for IMintableERC20;

  struct Invoice {
    uint256 id;
    address user;
    address token;
    uint256 tokenId;
    uint256 amount;
    address targetToken;
    uint256 price;
    bool active;
  }

  uint256 public systemFeePercent = 2e6;
  address public feeAddress;
  mapping(address => bool) public operators;
  mapping(address => address) public tokenDev; // token => devAddress
  mapping(address => uint256) public tokenFee; // token => devFee
  Invoice[] public orders;

  constructor() {
    feeAddress = msg.sender;
    _initializeEIP712("Marketplace");
  }

  modifier onlyOperator {
    require(operators[msgSender()], "Only Operator");
    _;
  }

  event SetTokenDev(address indexed setter, address indexed token, address indexed dev);
  function setTokenDev(address token, address dev) external onlyOwner {
    tokenDev[token] = dev;
    emit SetTokenDev(msgSender(), token, dev);
  }

  event SetTokenFee(address indexed setter, address indexed token, uint256 fee);
  function setTokenFee(address token, uint256 fee) external onlyOwner {
    tokenFee[token] = fee;
    emit SetTokenFee(msgSender(), token, fee);
  }

  event SetOperator(address indexed setter, address indexed operator, bool allowed);
  function setOperator(address operator, bool allowed) external onlyOwner {
    operators[operator] = allowed;
    emit SetOperator(msgSender(), operator, allowed);
  }

  event SetSystemFeePercent(address indexed setter, uint256 newPercent);
  function setSystemFeePercent(uint256 newPercent) external onlyOwner {
    systemFeePercent = newPercent;
    emit SetSystemFeePercent(msg.sender, newPercent);
  }

  event SetFeeAddress(address indexed setter, address indexed newAddress);
  function setFeeAddress(address newAddress) external onlyOwner {
    feeAddress = newAddress;
    emit SetFeeAddress(msg.sender, newAddress);
  }

  event DepositERC20(uint256 indexed orderId, address indexed token, address indexed from, uint256 amount, address targetToken, uint256 price);
  function depositERC20(IERC20 token, uint256 amount, address targetToken, uint256 price) external {
    require(tokenDev[address(token)] != address(0) && tokenDev[address(targetToken)] != address(0), "Invalid token");

    uint256 orderId = orders.length;
    address from = msgSender();
    
    token.safeTransferFrom(from, address(this), amount);
    orders.push(Invoice({
      id: orderId,
      user: from,
      token: address(token),
      tokenId: 0,
      amount: amount,
      targetToken: targetToken,
      price: price,
      active: true
    }));

    emit DepositERC20(orderId, address(token), from, amount, targetToken, price);
  }

  event DepositERC721(uint256 indexed orderId, address indexed token, address indexed from, uint256 tokenId, bytes data, address targetToken, uint256 price);
  function depositERC721(IERC721 token, uint256 tokenId, bytes memory data, address targetToken, uint256 price) external {
    require(tokenDev[address(token)] != address(0) && tokenDev[address(targetToken)] != address(0), "Invalid token");

    uint256 orderId = orders.length;
    address from = msgSender();

    token.safeTransferFrom(from, address(this), tokenId, data);
    orders.push(Invoice({
      id: orderId,
      user: from,
      token: address(token),
      tokenId: tokenId,
      amount: 1,
      targetToken: targetToken,
      price: price,
      active: true
    }));

    emit DepositERC721(orderId, address(token), from, tokenId, data, targetToken, price);
  }

  event DepositERC1155(uint256 indexed orderId, address indexed token, address indexed from, uint256 tokenId, uint256 amount, bytes data, address targetToken, uint256 price);
  function depositERC1155(IERC1155 token, uint256 tokenId, uint256 amount, bytes memory data, address targetToken, uint256 price) external {
    require(tokenDev[address(token)] != address(0) && tokenDev[address(targetToken)] != address(0), "Invalid token");

    uint256 orderId = orders.length;
    address from = msgSender();
    
    token.safeTransferFrom(from, address(this), tokenId, amount, data);
    orders.push(Invoice({
      id: orderId,
      user: from,
      token: address(token),
      tokenId: tokenId,
      amount: amount,
      targetToken: targetToken,
      price: price,
      active: true
    }));

    emit DepositERC1155(orderId, address(token), from, tokenId, amount, data, targetToken, price);
  }

  function collectMoney(uint256 orderId) internal {
    uint256 price = orders[orderId].price;
    IERC20 token = IERC20(orders[orderId].targetToken);
    address from = msgSender();

    uint256 systemFee = price * systemFeePercent / 1e18;
    uint256 devFee = price * tokenFee[address(token)] / 1e18;

    token.safeTransferFrom(from, feeAddress, systemFee);
    token.safeTransferFrom(from, tokenDev[address(token)], devFee);
    token.safeTransferFrom(from, address(this), price - systemFee - devFee);
  }

  event WithdrawERC20(uint256 indexed orderId, address indexed token, address indexed to, uint256 amount);
  function withdrawERC20(uint256 orderId, IMintableERC20 token, address to, uint256 amount) external {
    require(tokenDev[address(token)] != address(0), "Invalid token");
    require(orders[orderId].active == true, "Already Withdraw");

    collectMoney(orderId);
    token.safeTransfer(to, amount);
    orders[orderId].active = false;

    emit WithdrawERC20(orderId, address(token), to, amount);
  }

  event WithdrawERC721(uint256 indexed orderId, address indexed token, address indexed to, uint256 tokenId);
  function withdrawERC721(uint256 orderId, IMintableERC721 token, address to, uint256 tokenId) external {
    require(tokenDev[address(token)] != address(0), "Invalid token");
    require(orders[orderId].active == true, "Already Withdraw");

    collectMoney(orderId);
    token.safeTransferFrom(address(this), to, tokenId, "");
    orders[orderId].active = false;

    emit WithdrawERC721(orderId, address(token), to, tokenId);
  }

  event WithdrawERC1155(uint256 indexed orderId, address indexed token, address indexed to, uint256 tokenId, uint256 amount, bytes data);
  function withdrawERC1155(uint256 orderId, IMintableERC1155 token, address to, uint256 tokenId, uint256 amount, bytes memory data) external {
    require(tokenDev[address(token)] != address(0), "Invalid token");
    require(orders[orderId].active == true, "Already Withdraw");

    collectMoney(orderId);
    token.safeTransferFrom(address(this), to, tokenId, amount, "");
    orders[orderId].active = false;

    emit WithdrawERC1155(orderId, address(token), to, tokenId, amount, data);
  }

  event CancelOrder(address indexed caller, uint256 indexed orderId);
  function cancelOrder(uint256 orderId) public {
    require(orders[orderId].user == msgSender());
    orders[orderId].active = false;
    emit CancelOrder(msgSender(), orderId);
  }
}