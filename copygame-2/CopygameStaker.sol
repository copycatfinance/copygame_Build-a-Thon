// SPDX-License-Identifier: BUSL-1.1-COPYCAT
pragma solidity ^0.8.0;

import "./lib/SafeERC20.sol";
import "./CopygameLeader.sol";
import "hardhat/console.sol";

contract CopygameStaker is ReentrancyGuard {
  using SafeERC20 for IERC20;

  CopygameLeader public shareToken;
  IERC20[] public tokens;

  function getTokens() public view returns(IERC20[] memory) {
    return tokens;
  }

  modifier onlyLeaderContract {
    require(msg.sender == address(shareToken), "Forbidden");
    _;
  }

  // Staking section (To earn play-to-earn reward)
  mapping(address => uint256) public staked;
  mapping(address => uint256) public distributedReward;
  mapping(address => mapping(address => uint256)) public rewardDept;
  mapping(address => uint256) public accRewardPerShare;
  uint256 public totalShare;

  function initialize(address payable _shareToken) public {
    shareToken = CopygameLeader(_shareToken);
  }

  function safeTransfer(IERC20 token, address to, uint256 amount) internal {
    if (token.balanceOf(address(this)) >= amount) {
      token.safeTransfer(to, amount);
    } else {
      token.safeTransfer(to, token.balanceOf(address(this)));
    }
  }

  function updatePool(address sender, uint256 newAmount) public onlyLeaderContract nonReentrant {
    totalShare -= staked[sender];

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 reward = (accRewardPerShare[address(tokens[i])] * staked[sender] / 1e18) - rewardDept[sender][address(tokens[i])];
      console.log(reward, accRewardPerShare[address(tokens[i])], staked[sender], rewardDept[sender][address(tokens[i])]);
      if (reward > 0) {
        // If not enough balance -> reject
        safeTransfer(tokens[i], sender, reward);
      }
      rewardDept[sender][address(tokens[i])] = accRewardPerShare[address(tokens[i])] * newAmount / 1e18;
    }

    staked[sender] = newAmount;
    totalShare += newAmount;
  }

  function distributeReward(address token, uint256 amount) public onlyLeaderContract nonReentrant {
    if (accRewardPerShare[token] == 0) {
      tokens.push(IERC20(token));
    }

    distributedReward[token] += amount;
    accRewardPerShare[token] += amount * 1e18 / totalShare;
  }

}