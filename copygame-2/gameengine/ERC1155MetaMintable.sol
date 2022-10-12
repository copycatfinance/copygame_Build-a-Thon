// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./meta-transactions/NativeMetaTransaction.sol";
import "./meta-transactions/ContextMixin.sol";

abstract contract ERC1155MetaMintable is ERC1155, Ownable, NativeMetaTransaction, ContextMixin {
  address[] public minters;
  mapping(address => bool) public allowMinting;
  mapping(address => bool) public allowTransfer;
  mapping(uint256 => bool) public orderMinted;
  uint256 public totalBurn = 0;

  modifier onlyMinter {
    require(allowMinting[_msgSender()], "NM");
    _;
  }

  constructor(string memory uri_) ERC1155(uri_) {
    _initializeEIP712(uri_);
  }

  function _msgSender() internal view override virtual returns (address) {
    return msgSender();
  }

  event AllowMinter(address indexed setter, address indexed target, bool allowed);
  function setAllowMinting(address _address, bool _allowed) public onlyOwner {
    allowMinting[_address] = _allowed;
    if (_allowed) {
      minters.push(_address);
    }
    emit AllowMinter(_msgSender(), _address, _allowed);
  }

  event AllowTransfer(address indexed setter, address indexed target, bool allowed);
  function setAllowTransfer(address _address, bool _allowed) public onlyOwner {
    allowTransfer[_address] = _allowed;
    emit AllowTransfer(_msgSender(), _address, _allowed);
  }

  // Only allow whitelisted address to prevent tax avoiding
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual override {
    require(from == address(0) || to == address(0) || allowTransfer[from] || allowTransfer[to] || allowTransfer[operator] || allowTransfer[address(0)], "Not whitelisted");
  }

  function burn(uint256 tokenId, uint256 amount) public {
    _burn(_msgSender(), tokenId, amount);
  }

  function _afterMint(uint256 _orderId, address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) internal virtual {}

  function mint(address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) public onlyMinter {
    _mint(_to, _tokenId, _amount, _data);
    _afterMint(0, _to, _tokenId, _amount, _data);
  }

  event MetaMint(uint256 indexed orderId, address indexed to, uint256 indexed tokenId, uint256 amount, bytes data);
  function metaMint(uint256 _orderId, address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) public onlyMinter {
    require(!orderMinted[_orderId], "Minted");
    orderMinted[_orderId] = true;
    _mint(_to, _tokenId, _amount, _data);
    _afterMint(_orderId, _to, _tokenId, _amount, _data);
    emit MetaMint(_orderId, _to, _tokenId, _amount, _data);
  }
}