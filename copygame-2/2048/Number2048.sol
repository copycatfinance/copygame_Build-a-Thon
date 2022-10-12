// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../gameengine/ERC1155MetaMintable.sol";

contract Number2048 is ERC1155MetaMintable("https://api.2048.finance/nftmetadata/2048NUMBER/{id}") {}