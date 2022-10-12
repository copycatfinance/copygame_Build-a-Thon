// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../gameengine/ERC721MetaMintable.sol";
import "../gameengine/ERC20MetaMintable.sol";

abstract contract ERC721RarityDurability is ERC721MetaMintable {
  struct TokenInfo {
    uint256 rarity;
    uint256 durability;
  }
  mapping(uint256 => TokenInfo) public tokenInfo;
  mapping(uint256 => uint256) public rarityDurability;
  // uint256 token2048perDu = 1 ether;

  ERC20MetaMintable public immutable tokenCpc;
  ERC20MetaMintable public immutable token2048;
  ERC20MetaMintable public immutable tokenEnergy;

  constructor(
    string memory _name, 
    string memory _symbol,
    ERC20MetaMintable _tokenCpc,
    ERC20MetaMintable _token2048,
    ERC20MetaMintable _tokenEnergy
  ) ERC721MetaMintable(_name, _symbol) {
    tokenCpc = _tokenCpc;
    token2048 = _token2048;
    tokenEnergy = _tokenEnergy;
  }

  event SetRarityDurability(address indexed caller, uint256 indexed rarity, uint256 durability);
  function setRarityDurability(uint256 rarity, uint256 durability) public onlyOwner {
    rarityDurability[rarity] = durability;
    emit SetRarityDurability(msg.sender, rarity, durability);
  }

  // event SetToken2048perDu(address indexed caller, uint256 amount);
  // function setToken2048perDu(uint256 amount) public onlyOwner {
  //   token2048perDu = amount;
  //   emit SetToken2048perDu(msg.sender, amount);
  // }

  // event BoardMinted(address indexed to, uint256 indexed tokenId, uint256 indexed rarity);
  // function _afterMint(uint256 _orderId, address _to, uint256 _tokenId, bytes memory _data) internal override {
  //   uint256 rarity = abi.decode(_data, (uint256));
  //   tokenInfo[_tokenId] = TokenInfo({
  //     rarity: rarity,
  //     durability: rarityDurability[rarity]
  //   });
  //   emit BoardMinted(_to, _tokenId, rarity);
  // }

  event SetDurability(address indexed setter, uint256 indexed tokenId, uint256 durability);
  function setDurability(uint256 tokenId, uint256 durability) public onlyMinter {
    tokenInfo[tokenId].durability = durability;
    emit SetDurability(msg.sender, tokenId, durability);
  }
}