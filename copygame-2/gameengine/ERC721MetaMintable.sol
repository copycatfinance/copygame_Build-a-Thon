// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./meta-transactions/NativeMetaTransaction.sol";
import "./meta-transactions/ContextMixin.sol";

abstract contract ERC721MetaMintable is ERC721Enumerable, Ownable, NativeMetaTransaction, ContextMixin {
  address[] public minters;
  mapping(address => bool) public allowMinting;
  mapping(address => bool) public allowTransfer;
  mapping(uint256 => bool) public orderMinted;
  uint256 public totalBurn = 0;

  modifier onlyMinter {
    require(allowMinting[_msgSender()], "NM");
    _;
  }

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    _initializeEIP712(name);
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
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, tokenId);
    require(from == address(0) || to == address(0) || allowTransfer[from] || allowTransfer[to] || allowTransfer[address(0)], "Not whitelisted");
  }

  function burn(uint256 tokenId) public {
    require(_isApprovedOrOwner(_msgSender(), tokenId));
    _burn(tokenId);
  }

  function _afterMint(uint256 _orderId, address _to, uint256 _tokenId, bytes memory _data) internal virtual {}

  function mint(address _to, uint256 _tokenId, bytes memory _data) public onlyMinter {
    _safeMint(_to, _tokenId, _data);
    _afterMint(0, _to, _tokenId, _data);
  }

  event MetaMint(uint256 indexed orderId, address indexed to, uint256 indexed tokenId, bytes data);
  function metaMint(uint256 _orderId, address _to, uint256 _tokenId, bytes memory _data) public onlyMinter {
    require(!orderMinted[_orderId], "Minted");
    orderMinted[_orderId] = true;
    _safeMint(_to, _tokenId, _data);
    _afterMint(_orderId, _to, _tokenId, _data);
    emit MetaMint(_orderId, _to, _tokenId, _data);
  }
}