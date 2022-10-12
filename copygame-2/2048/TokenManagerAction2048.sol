// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../gameengine/ERC20MetaMintable.sol";
import "../gameengine/ERC1155MetaMintable.sol";
import "../gameengine/ITokenManagerAction.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/**
  This is for interacting with backend operation such as
  - Minting boards with random
  - Start game
  - Repair items (Required durability data from backend)
  - Breeding

  What it do is just burning token as backend requested 
  and the backend will do the following job after event is fired
*/
contract TokenManagerAction2048 is Ownable, ITokenManagerAction, ERC721Holder, ERC1155Holder {
  address public tokenManager;
  IERC20 public tokenShare;
  ERC20MetaMintable public immutable tokenCpc;
  ERC20MetaMintable public immutable token2048;
  ERC20MetaMintable public immutable tokenEnergy;
  ERC1155MetaMintable public immutable number2048;

  constructor(
    address _tokenManager,
    IERC20 _tokenShare,
    ERC20MetaMintable _tokenCpc,
    ERC20MetaMintable _token2048,
    ERC20MetaMintable _tokenEnergy,
    ERC1155MetaMintable _number2048
  ) {
    tokenManager = _tokenManager;
    tokenShare = _tokenShare;
    tokenCpc = _tokenCpc;
    token2048 = _token2048;
    tokenEnergy = _tokenEnergy;
    number2048 = _number2048;
  }

  event SetTokenShare(address indexed caller, address indexed newToken);
  function setTokenShare(IERC20 newToken) external onlyOwner {
    tokenShare = newToken;
    emit SetTokenShare(msg.sender, address(newToken));
  }

  function execute(address sender, uint256 actionId, bytes memory data) external returns(bytes memory) {
    // 9e17 = breeding
    if (actionId % 1e18 < 9e17) {
      (uint256 nShare, uint256 nCpc, uint256 n2048, uint256 nEnergy) = abi.decode(data, (uint256, uint256, uint256, uint256));
      
      if (nShare > 0) tokenShare.transferFrom(sender, tokenManager, nShare);
      if (nCpc > 0) tokenCpc.transferFrom(sender, tokenManager, nCpc);
      if (n2048 > 0) token2048.burnFrom(sender, n2048);
      if (nEnergy > 0) tokenEnergy.burnFrom(sender, nEnergy);
    } else {
      (uint256 nShare, uint256 nCpc, uint256 n2048, uint256 nEnergy, uint256 nNum) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
      
      if (nShare > 0) tokenShare.transferFrom(sender, tokenManager, nShare);
      if (nCpc > 0) tokenCpc.transferFrom(sender, tokenManager, nCpc);
      if (n2048 > 0) token2048.burnFrom(sender, n2048);
      if (nEnergy > 0) tokenEnergy.burnFrom(sender, nEnergy);

      uint256 tokenId = actionId % 1e17;
      number2048.safeTransferFrom(sender, address(this), tokenId, nNum, "");
      number2048.burn(tokenId, nNum);
    }
    return "";
  }
}