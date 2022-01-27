// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "../lib/solmate/src/utils/SafeTransferLib.sol";

/* 
    Permissionless staking contract that allows any number of incentives to be running for any token (erc20).
    Incentives can be created by anyone, the total reward amount must be sent at creation.
    Incentives can be updated (change reward rate / duration).
    Users can deposit their assets into the contract and then subscribe to any of the available incentives.
 */

contract StakingContract {

    using SafeTransferLib for ERC20;

    struct Incentive {
        address creator;
        address token;
        address rewardToken;
        uint48 lastRewardTime;
        uint48 endTime;
        uint128 rewardRemaining;
        uint128 liquidityStaked;
        uint256 rewardPerLiquidity; // Accumulator value
    }

    uint256 public incentiveCount;

    mapping(uint256 => Incentive) public incentives;

    /// @dev rewardPerLiquidityLast[user][incentiveId]
    mapping(address => mapping(uint256 => uint256)) public rewardPerLiquidityLast;

    /// @dev userStakes[user][stakedToken]
    mapping(address => mapping(address => UserStake)) public userStakes;

    struct UserStake {
        uint128 liquidity;
        uint256[] incentiveIds;
    }

    function createIncentive(
        address token,
        address rewardToken,
        uint128 rewardAmount,
        uint48 startTime,
        uint48 endTime
    ) external returns (uint256 incentiveId) {

        if (startTime < block.timestamp) startTime = uint48(block.timestamp);

        require(startTime < endTime);
        
        unchecked { incentiveId = incentiveCount++; }

        ERC20(rewardToken).safeTransferFrom(msg.sender, address(this), rewardAmount); // check token existance ?
        
        incentives[incentiveId] = Incentive({
            creator: msg.sender,
            token: token,
            rewardToken: rewardToken,
            lastRewardTime: startTime,
            endTime: endTime,
            rewardRemaining: rewardAmount,
            liquidityStaked: 0,
            rewardPerLiquidity: 1
        });

    }

    function updateIncentive(
        uint256 incentiveId,
        uint128 transferIn,
        uint128 transferOut,
        uint48 newStartTime,
        uint48 newEndTime
    ) external {

        Incentive storage incentive = incentives[incentiveId];

        require(msg.sender == incentive.creator);

        _accrueRewards(incentive);

        if (newStartTime != 0) {
            if (newStartTime < block.timestamp) newStartTime = uint48(block.timestamp);
            incentive.lastRewardTime = newStartTime;
        }

        if (newEndTime != 0) {
            if (newEndTime < block.timestamp) newEndTime = uint48(block.timestamp);
            incentive.endTime = newEndTime;
        }

        require(incentive.lastRewardTime <= incentive.endTime);

        if (transferIn > 0) {
            incentive.rewardRemaining += transferIn;
            ERC20(incentive.rewardToken).safeTransferFrom(msg.sender, address(this), transferIn);
        }

        if (transferOut > 0) {
            if (transferOut > incentive.rewardRemaining) transferOut = incentive.rewardRemaining;
            unchecked { incentive.rewardRemaining -= transferOut; }
            ERC20(incentive.rewardToken).safeTransfer(msg.sender, transferOut);
        }

    }

    function stakeToken(address token, uint128 amount) external {

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        UserStake storage userStake = userStakes[msg.sender][token];
    
        uint256 n = userStake.incentiveIds.length;

        for (uint256 i = 0; i < n; i = _increment(i)) { // Loop through already subscribed incentives.

            Incentive storage incentive = incentives[userStake.incentiveIds[i]];

            _accrueRewards(incentive);

            _claimReward(incentive, userStake.incentiveIds[i], msg.sender, userStake.liquidity);

            incentive.liquidityStaked += amount;

        }

        userStake.liquidity += amount;

    }

    function unstakeToken(address token, uint128 amount) external {

        UserStake storage userStake = userStakes[msg.sender][token];

        uint256 n = userStake.incentiveIds.length;

        for (uint256 i = 0; i < n; i = _increment(i)) {

            Incentive storage incentive = incentives[userStake.incentiveIds[i]];

            _accrueRewards(incentive);

            _claimReward(incentive, userStake.incentiveIds[i], msg.sender, userStake.liquidity);

            unchecked { incentive.liquidityStaked -= amount; }

        }
        
        userStake.liquidity -= amount;

        ERC20(token).safeTransfer(msg.sender, amount);

    }

    function subscribeToIncentive(uint256 incentiveId) external {

        require(rewardPerLiquidityLast[msg.sender][incentiveId] == 0, "Already subscribed");

        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;

        UserStake storage userStake = userStakes[msg.sender][incentive.token];

        userStake.incentiveIds.push(incentiveId);

        incentive.liquidityStaked += userStake.liquidity;

    }

    /// @dev Since we have to delete the incentive from an array, pass its index instead of its id to avoid an array search.
    function unsubscribeFromIncentive(address token, uint256 incentiveIndex) external {

        UserStake storage userStake = userStakes[msg.sender][token];

        uint256 incentiveId = userStake.incentiveIds[incentiveIndex];
        
        require(rewardPerLiquidityLast[msg.sender][incentiveId] != 0, "Already unsubscribed");
        
        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        _claimReward(incentive, incentiveId, msg.sender, userStake.liquidity);

        unchecked { incentive.liquidityStaked -= uint128(userStake.liquidity); }

        userStake.incentiveIds[incentiveIndex] = userStake.incentiveIds[userStake.incentiveIds.length - 1];

        userStake.incentiveIds.pop();

    }

    function claimRewards(uint256[] calldata incentiveIds) external {

        uint256 n = incentiveIds.length;

        for(uint256 i = 0; i < n; i = _increment(i)) {

            Incentive storage incentive = incentives[incentiveIds[i]];

            _accrueRewards(incentive);

            UserStake memory userStake = userStakes[msg.sender][incentive.token];

            _claimReward(incentive, incentiveIds[i], msg.sender, userStake.liquidity);

        }

    }

    function _accrueRewards(Incentive storage incentive) internal {
        unchecked {
            if (
                incentive.liquidityStaked > 0 &&
                incentive.lastRewardTime < block.timestamp &&
                incentive.lastRewardTime < incentive.endTime
            ) {
                uint256 totalTime = incentive.endTime - incentive.lastRewardTime;
                uint256 maxTime = block.timestamp < incentive.endTime ? block.timestamp : incentive.endTime;
                uint256 passedTime = maxTime - incentive.lastRewardTime;
                uint256 reward = incentive.rewardRemaining * passedTime / totalTime;
                incentive.rewardPerLiquidity += reward * type(uint128).max / incentive.liquidityStaked;
                incentive.rewardRemaining -= uint128(reward);
                incentive.lastRewardTime = uint48(maxTime);
            }
        }
    }

    function _claimReward(Incentive storage incentive, uint256 incentiveId, address user, uint256 usersLiquidity) internal returns (uint256 reward) {
        
        unchecked {
            uint256 rewardPerLiquidity = incentive.rewardPerLiquidity - rewardPerLiquidityLast[user][incentiveId];
            reward = rewardPerLiquidity * usersLiquidity / type(uint128).max; // use safe mulDiv that handles phantom overflow ?
        }

        rewardPerLiquidityLast[user][incentiveId] = incentive.rewardPerLiquidity;

        ERC20(incentive.rewardToken).safeTransfer(user, reward);

    }

    function _increment(uint256 i) internal pure returns(uint256) {
        unchecked {
            return i + 1;
        }
    }

    function batch(bytes[] calldata datas) external {
        uint256 n = datas.length;
        for (uint256 i = 0; i < n; i = _increment(i)) {
            (bool success,) = address(this).delegatecall(datas[i]);
            require(success); // todo, parse revert msg
        }
    }

}
