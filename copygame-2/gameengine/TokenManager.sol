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
contract TokenManager is Ownable, ERC721Holder, ERC1155Holder, ContextMixin, NativeMetaTransaction {
  using SafeERC20 for IERC20;
  using SafeERC20 for IMintableERC20;

  struct Invoice {
    uint256 id;
    address user;
    address token;
    uint256 tokenId;
    uint256 amount;
  }

  mapping(address => bool) public allowedToken;
  mapping(address => bool) public operators;
  mapping(uint256 => ITokenManagerAction) public actions;
  mapping(uint256 => bool) public isPublicAction;
  Invoice[] public deposits;
  mapping(uint256 => Invoice) public withdraws;

  mapping(address => uint256) public dailyWithdrawLimit;
  mapping(address => mapping(uint256 => uint256)) public dailyWithdraw;

  constructor() {
    _initializeEIP712("TokenManager");
  }

  modifier onlyOperator {
    require(operators[msgSender()], "Only Operator");
    _;
  }

  event SetAllowedToken(address indexed setter, address indexed token, bool allowed);
  function setAllowedToken(address token, bool allowed) external onlyOwner {
    allowedToken[token] = allowed;
    emit SetAllowedToken(msgSender(), token, allowed);
  }

  event SetOperator(address indexed setter, address indexed operator, bool allowed);
  function setOperator(address operator, bool allowed) external onlyOwner {
    operators[operator] = allowed;
    emit SetOperator(msgSender(), operator, allowed);
  }

  event SetAction(address indexed setter, uint256 indexed id, address indexed action, bool isPublic);
  function setAction(uint256 id, ITokenManagerAction action, bool isPublic) external onlyOwner {
    actions[id] = action;
    isPublicAction[id] = isPublic;
    emit SetAction(msg.sender, id, address(action), isPublic);
  }

  event DepositERC20(uint256 indexed invoiceId, address indexed token, address indexed from, uint256 amount, bytes note);
  function depositERC20(IERC20 token, uint256 amount, bytes memory note) external {
    require(allowedToken[address(token)], "Invalid token");

    uint256 invoiceId = deposits.length;
    address from = msgSender();

    
    token.safeTransferFrom(from, address(this), amount);
    deposits.push(Invoice({
      id: invoiceId,
      user: from,
      token: address(token),
      tokenId: 0,
      amount: amount
    }));

    emit DepositERC20(invoiceId, address(token), from, amount, note);
  }

  event DepositERC721(uint256 indexed invoiceId, address indexed token, address indexed from, uint256 tokenId, bytes data, bytes note);
  function depositERC721(IERC721 token, uint256 tokenId, bytes memory data, bytes memory note) external {
    require(allowedToken[address(token)], "Invalid token");

    uint256 invoiceId = deposits.length;
    address from = msgSender();

    
    token.safeTransferFrom(from, address(this), tokenId, data);
    deposits.push(Invoice({
      id: invoiceId,
      user: from,
      token: address(token),
      tokenId: tokenId,
      amount: 1
    }));

    emit DepositERC721(invoiceId, address(token), from, tokenId, data, note);
  }

  event DepositERC1155(uint256 indexed invoiceId, address indexed token, address indexed from, uint256 tokenId, uint256 amount, bytes data, bytes note);
  function depositERC1155(IERC1155 token, uint256 tokenId, uint256 amount, bytes memory data, bytes memory note) external {
    require(allowedToken[address(token)], "Invalid token");

    uint256 invoiceId = deposits.length;
    address from = msgSender();

    
    token.safeTransferFrom(from, address(this), tokenId, amount, data);
    deposits.push(Invoice({
      id: invoiceId,
      user: from,
      token: address(token),
      tokenId: tokenId,
      amount: amount
    }));

    emit DepositERC1155(invoiceId, address(token), from, tokenId, amount, data, note);
  }

  event WithdrawERC20(uint256 indexed invoiceId, address indexed token, address indexed to, uint256 amount);
  function withdrawERC20(uint256 invoiceId, IMintableERC20 token, address to, uint256 amount) external onlyOperator {
    require(allowedToken[address(token)], "Invalid token");
    require(withdraws[invoiceId].id == 0, "Already Withdraw");

    
    uint256 toMint = token.balanceOf(address(this)) < amount ? amount - token.balanceOf(address(this)) : 0;
    uint256 toTransfer = amount - toMint;

    if (toTransfer > 0) {
      token.safeTransfer(to, toTransfer);
    }

    if (toMint > 0) {
      token.mint(to, toMint);
    }

    withdraws[invoiceId] = Invoice({
      id: invoiceId,
      user: to,
      token: address(token),
      tokenId: 0,
      amount: amount
    });

    emit WithdrawERC20(invoiceId, address(token), to, amount);
  }

  event WithdrawERC721(uint256 indexed invoiceId, address indexed token, address indexed to, uint256 tokenId);
  function withdrawERC721(uint256 invoiceId, IMintableERC721 token, address to, uint256 tokenId) external onlyOperator {
    require(allowedToken[address(token)], "Invalid token");
    require(withdraws[invoiceId].id == 0, "Already Withdraw");

    
    token.safeTransferFrom(address(this), to, tokenId);
    withdraws[invoiceId] = Invoice({
      id: invoiceId,
      user: to,
      token: address(token),
      tokenId: tokenId,
      amount: 1
    });

    emit WithdrawERC721(invoiceId, address(token), to, tokenId);
  }

  event WithdrawERC1155(uint256 indexed invoiceId, address indexed token, address indexed to, uint256 tokenId, uint256 amount, bytes data);
  function withdrawERC1155(uint256 invoiceId, IMintableERC1155 token, address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyOperator {
    require(allowedToken[address(token)], "Invalid token");
    require(withdraws[invoiceId].id == 0, "Already Withdraw");

    
    uint256 toMint = token.balanceOf(address(this), tokenId) < amount ? amount - token.balanceOf(address(this), tokenId) : 0;
    uint256 toTransfer = amount - toMint;

    if (toTransfer > 0) {
      token.safeTransferFrom(address(this), to, tokenId, toTransfer, data);
    }

    if (toMint > 0) {
      token.mint(to, tokenId, toMint, data);
    }

    withdraws[invoiceId] = Invoice({
      id: invoiceId,
      user: to,
      token: address(token),
      tokenId: tokenId,
      amount: amount
    });

    emit WithdrawERC1155(invoiceId, address(token), to, tokenId, amount, data);
  }

  event PerformAction(address indexed caller, uint256 indexed actionId, uint256 indexed requestId, address action, bytes bytesIn, bytes bytesOut);
  function performAction(uint256 actionId, uint256 requestId, bytes memory bytesIn) public returns (bytes memory bytesOut) {
    require(address(actions[actionId]) != address(0), "No action");
    require(isPublicAction[actionId] || operators[msgSender()], "Forbidden");

    bytesOut = actions[actionId].execute(msg.sender, actionId, bytesIn);

    emit PerformAction(msg.sender, actionId, requestId, address(actions[actionId]), bytesIn, bytesOut);
  }
}