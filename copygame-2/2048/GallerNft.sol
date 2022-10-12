// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../gameengine/ERC721MetaMintable.sol";
import "../gameengine/ERC20MetaMintable.sol";
import "./ILaunchpadNFT.sol";

contract GallerNft is ERC721MetaMintable, ILaunchpadNFT {
  using Strings for uint256;

  mapping(address => uint256) launchpadMinted;
  mapping(address => uint256) launchpadMinterStart;
  mapping(address => uint256) launchpadMinterSupply;
  address public gallerLaunchpad;

  string public baseURI = "https://api.2048.finance/nftmetadata/";

  constructor(
    string memory _name, 
    string memory _symbol
  ) ERC721MetaMintable(_name, _symbol) {}

  function setLaunchpadMinter(address launchpad, uint256 start, uint256 supply) public onlyOwner {
    launchpadMinted[launchpad] = 0;
    launchpadMinterStart[launchpad] = start;
    launchpadMinterSupply[launchpad] = supply;
  }

  function setBaseURI(string memory uri) public onlyOwner {
    baseURI = uri;
  }

  modifier onlyLaunchpad() {
    require(launchpadMinterStart[msg.sender] != 0, "must call by launchpad");
    _;
  }

  function getMaxLaunchpadSupply() view public returns (uint256) {
    return launchpadMinterSupply[msg.sender];
  }

  function getLaunchpadSupply() view public returns (uint256) {
    return launchpadMinted[msg.sender];
  }

  function mintTo(address to, uint size) external onlyLaunchpad {
    require(to != address(0), "can't mint to empty address");
    require(size > 0, "size must greater than zero");
    require(getLaunchpadSupply() + size <= getMaxLaunchpadSupply(), "max supply reached");

    for (uint256 i=1; i <= size; i++) {
      uint256 tokenId = launchpadMinterStart[msg.sender] + launchpadMinted[msg.sender];
      _safeMint(to, tokenId, "");
      _afterMint(0, to, tokenId, "");
      launchpadMinted[msg.sender]++;
    }
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token.");
    return string(abi.encodePacked(baseURI, symbol(), "/", tokenId.toString()));
  }

  function withdrawETH() public onlyOwner {
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    require(os);
  }

  function withdrawERC20(IERC20 token) public onlyOwner {
    token.transfer(owner(), token.balanceOf(address(this)));
  }
}