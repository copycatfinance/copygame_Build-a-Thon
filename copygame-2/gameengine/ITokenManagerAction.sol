// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenManagerAction {
  function execute(address sender, uint256 actionId, bytes memory data) external returns(bytes memory);
}