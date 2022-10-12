// SPDX-License-Identifier: BUSL-1.1-COPYCAT
pragma solidity ^0.8.0;

import "./lib/SafeERC20.sol";
import "./CopycatLeader.sol";
import "./interfaces/ICopygameStaker.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract CopygameLeader is CopycatLeader, ERC721Holder, ERC1155Holder {
  using SafeERC20 for IERC20;

  IERC20 public baseToken;
  ICopygameStaker public staker;
  uint256 public depositLimit = 0;

  // event InitializeGame(
  //   address indexed initializer, 
  //   address indexed _leaderAddr,
  //   address indexed _baseToken,
  //   uint256 _depositLimit
  // );
  function initializeGame(
    address _leaderAddr, 
    address _staker, 
    IERC20 _baseToken, 
    uint256 _depositLimit
  ) public {
    initialize(_leaderAddr);
    baseToken = _baseToken;
    staker = ICopygameStaker(_staker);
    depositLimit = _depositLimit;
    // emit InitializeGame(msg.sender, _leaderAddr, address(_baseToken), _depositLimit);
  }

  // Staking section (To earn play-to-earn reward)
  event Harvest(address indexed harvester);
  function harvest() public nonReentrant {
    staker.updatePool(msg.sender, staker.staked(msg.sender));
    emit Harvest(msg.sender);
  }

  event Stake(address indexed staker, uint256 amount);
  function stake(uint256 amount) public nonReentrant {
    staker.updatePool(msg.sender, staker.staked(msg.sender) + amount);
    _transfer(msg.sender, address(staker), amount);
    emit Stake(msg.sender, amount);
  }

  event Unstake(address indexed staker, uint256 amount);
  function unstake(uint256 amount) public nonReentrant {
    staker.updatePool(msg.sender, staker.staked(msg.sender) - amount);
    _transfer(address(staker), msg.sender, amount);
    emit Unstake(msg.sender, amount);
  }

  // Deposit / withdraw section
  function depositTo(address to, uint256 percentage, IERC20 refToken, uint256 maxRefAmount) payable public override nonReentrant onlyEOA returns(uint256 totalShare) {
    totalShare = totalSupply() * percentage / 1e18;
    require(depositLimit == 0 || totalSupply() + totalShare <= depositLimit, "Limit");

    if (baseToken == WETH && msg.value >= totalShare) {
      WETH.deposit{value: totalShare}();
      payable(msg.sender).transfer(msg.value - totalShare);
    } else {
      baseToken.safeTransferFrom(msg.sender, address(this), totalShare);
    }

    // Collect CPC fee
    uint256 depositCopycatFee = S.getLeaderDepositCopycatFee(address(this));
    if (depositCopycatFee > 0 && msg.sender != address(factory) && to != owner()) {
      S.collectLeaderFee(msg.sender, depositCopycatFee);
    }

    // Mint share
    totalShare = percentage * totalSupply() / 1e18;
    uint256 shareFee = totalShare * S.getLeaderDepositPercentageFee(address(this)) / 1e18;

    if (msg.sender == address(factory) || msg.sender == owner()) {
      shareFee = 0;
    }

    // Reduce gas for minting
    if (shareFee > 0) {
      totalShare -= shareFee;

      // Leader earn underlying token as fee
      baseToken.transfer(owner(), shareFee * 6 / 10);
      baseToken.transfer(S.feeAddress(), shareFee * 4 / 10);
    }

    if (to == msg.sender) {
      _mint(address(staker), totalShare);
      staker.updatePool(msg.sender, staker.staked(msg.sender) + totalShare);
    } else {
      _mint(to, totalShare);
    }

    emit Deposit(msg.sender, to, percentage, totalShare);
    S.emitDeposit(msg.sender, totalShare);
  }

  function withdrawTo(address to, uint256 shareAmount, IERC20 refToken, uint256 minRefAmount, bool asWeth) public override returns(uint256 percentage) {
    require(false, "W");
  }

  // Tokens managing system
  function _addToken(IERC20 _token, uint256 _type) override internal {
    if(address(_token) != address(this)) {
      if (tokensType[address(_token)] == 0) {
        tokens.push(_token);
        emit AddToken(msg.sender, address(_token), _type);
      }
      tokensType[address(_token)] = _type;
    }
  }

  function addToken(IERC20 token) nonReentrant onlyOwner override public {
    if (S.getTradingRouteEnabled(address(token))) {
      _addToken(token, 1);
    } else {
      _addToken(token, 999);
    }
  }

  event DistributeReward(address indexed caller, address indexed token, uint256 amount);
  function distributeReward(IERC20 token, uint256 amount) public onlyOwner nonReentrant {
    require(address(token) != address(this), "R");
    token.safeTransfer(address(staker), amount);
    staker.distributeReward(address(token), amount);
    emit DistributeReward(msg.sender, address(token), amount);
  }

  event Execute(address indexed caller, address indexed target, uint256 value, bytes functionSignature, bytes returnData);
  function execute(address target, uint256 value, bytes memory functionSignature) public onlyOwner nonReentrant returns (bytes memory) {
    require(S.copygameContract(target), "NA");
    if (value > 0) {
      WETH.withdraw(value);
    }
    (bool success, bytes memory returnData) = target.call{value: value}(functionSignature);
    require(success, "Function call not successful");
    emit Execute(msg.sender, target, value, functionSignature, returnData);
    return returnData;
  }

  function pluginRequestAllowance(IERC20 token, address spender, uint256 amount) external override nonReentrant onlyOwner {
    require(S.copygameContract(spender), "NA");
    token.safeApproveNew(spender, amount);
    emit ApproveToken(address(token), spender, amount);
  }

  // Disable event due to contract size limit
  // event SetDepositLimit(address indexed caller, uint256 newLimit);
  function setDepositLimit(uint256 newDepositLimit) external onlyOwner nonReentrant {
    depositLimit = newDepositLimit;
    // emit SetDepositLimit(msg.sender, newDepositLimit);
  }
}