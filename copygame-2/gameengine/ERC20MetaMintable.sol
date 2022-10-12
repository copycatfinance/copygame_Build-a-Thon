// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./ERC20Mintable.sol";
import "./meta-transactions/NativeMetaTransaction.sol";
import "./meta-transactions/ContextMixin.sol";

abstract contract ERC20MetaMintable is ERC20Burnable, ERC20Mintable, NativeMetaTransaction, ContextMixin {
  mapping(uint256 => bool) public orderMinted;
  uint256 public totalBurn = 0;
  uint256 public maxSupply = 0;

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    _initializeEIP712(name);
  }

  function _msgSender() internal view override virtual returns (address) {
    return msgSender();
  }

  function _mint(address _to, uint256 _amount) internal virtual override {
    super._mint(_to, _amount);
    require(maxSupply == 0 || totalSupply() <= maxSupply, "Max supply exceeded");
  }

  function burn(uint256 amount) public override {
    ERC20Burnable.burn(amount);
    totalBurn += amount;
  }

  function burnFrom(address account, uint256 amount) public override {
    ERC20Burnable.burnFrom(account, amount);
    totalBurn += amount;
  }

  event MetaMint(uint256 indexed orderId, address indexed to, uint256 amount);
  function metaMint(uint256 _orderId, address _to, uint256 _amount) public onlyMinter {
    require(!orderMinted[_orderId], "Minted");
    orderMinted[_orderId] = true;
    mint(_to, _amount);
    emit MetaMint(_orderId, _to, _amount);
  }

  event SetMaxSupply(address indexed setter, uint256 newMaxSupply);
  function setMaxSupply(uint256 newMaxSupply) public onlyOwner {
    maxSupply = newMaxSupply;
    emit SetMaxSupply(_msgSender(), newMaxSupply);
  }
}