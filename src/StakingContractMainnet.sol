// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "lib/solmate/src/utils/SafeTransferLib.sol";
import "./libraries/PackedUint144.sol";
import "./test/Console.sol";

/* 
    Permissionless staking contract that allows any number of incentives to be running for any token (erc20).
    Incentives can be created by anyone, the total reward amount must be sent at creation.
    Incentives can be updated (change reward rate / duration).
    Users can deposit their assets into the contract and then subscribe to any of the available incentives, up to 6 per token.
 */

contract StakingContractMainnet {

    using SafeTransferLib for ERC20;
    using PackedUint144 for uint144;

    struct Incentive {
        address creator;            // 1st slot
        address token;              // 2nd slot
        address rewardToken;        // 3rd slot
        uint32 endTime;             // 3rd slot
        uint256 rewardPerLiquidity; // 4th slot
        uint32 lastRewardTime;      // 5th slot
        uint112 rewardRemaining;    // 5th slot
        uint112 liquidityStaked;    // 5th slot
    }

    uint256 public incentiveCount;

    // Starts with 1. Zero is an invalid incentive.
    mapping(uint256 => Incentive) public incentives;

    /// @dev rewardPerLiquidityLast[user][incentiveId]
    mapping(address => mapping(uint256 => uint256)) public rewardPerLiquidityLast;

    /// @dev userStakes[user][stakedToken]
    mapping(address => mapping(address => UserStake)) public userStakes;

    // Incentive count won't be greater than type(uint24).max on mainnet.
    // This means we can use uint24 vlaues to identify incentives.
    struct UserStake {
        uint112 liquidity;
        uint144 subscribedIncentiveIds; // Six packed uint24 values.
    }

    error InvalidTimeFrame();
    error IncentiveOverflow();
    error AlreadySubscribed();
    error AlreadyUnsubscribed();
    error NotSubscribed();
    error OnlyCreator();

    function createIncentive(
        address token,
        address rewardToken,
        uint112 rewardAmount,
        uint32 startTime,
        uint32 endTime
    ) external returns (uint256 incentiveId) {

        if (startTime < block.timestamp) startTime = uint32(block.timestamp);

        if (startTime >= endTime) revert InvalidTimeFrame();

        unchecked {
            incentiveId = ++incentiveCount;
            if (incentiveId > type(uint24).max) revert IncentiveOverflow();
        }

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
        int112 changeAmount,
        uint32 newStartTime,
        uint32 newEndTime
    ) external {

        Incentive storage incentive = incentives[incentiveId];

        if (msg.sender != incentive.creator) revert OnlyCreator();

        _accrueRewards(incentive);

        if (newStartTime != 0) {
            if (newStartTime < block.timestamp) newStartTime = uint32(block.timestamp);
            incentive.lastRewardTime = newStartTime;
        }

        if (newEndTime != 0) {
            if (newEndTime < block.timestamp) newEndTime = uint32(block.timestamp);
            incentive.endTime = newEndTime;
        }

        if (incentive.lastRewardTime > incentive.endTime) revert InvalidTimeFrame();

        if (changeAmount > 0) {
            
            incentive.rewardRemaining += uint112(changeAmount);
            ERC20(incentive.rewardToken).safeTransferFrom(msg.sender, address(this), uint112(changeAmount));

        } else if (changeAmount < 0) {

            uint112 transferOut = uint112(-changeAmount);
            if (transferOut > incentive.rewardRemaining) transferOut = incentive.rewardRemaining;
            unchecked { incentive.rewardRemaining -= transferOut; }
            ERC20(incentive.rewardToken).safeTransfer(msg.sender, transferOut);

        }

    }

    function stakeToken(address token, uint112 amount) public {

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        UserStake storage userStake = userStakes[msg.sender][token];
    
        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();

        for (uint256 i = 0; i < n; i = _increment(i)) { // Loop through already subscribed incentives.

            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);

            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            _claimReward(incentive, incentiveId, userStake.liquidity);

            incentive.liquidityStaked += amount;

        }

        userStake.liquidity += amount;

    }

    function stakeAndSubscribeToIncentives(address token, uint112 amount, uint256[] memory incentives) external {

        stakeToken(token, amount);

        uint256 n = incentives.length;
        for (uint256 i = 0; i < n; i = _increment(i)) {
            subscribeToIncentive(incentives[i]);
        }

    }

    function unstakeToken(address token, uint112 amount) external {

        UserStake storage userStake = userStakes[msg.sender][token];

        if (amount > userStake.liquidity) amount = userStake.liquidity;

        unchecked { userStake.liquidity -= amount; }

        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();

        for (uint256 i = 0; i < n; i = _increment(i)) {

            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);

            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            _claimReward(incentive, incentiveId, userStake.liquidity);

            unchecked { incentive.liquidityStaked -= amount; }

        }

        ERC20(token).safeTransfer(msg.sender, amount);

    }

    function subscribeToIncentive(uint256 incentiveId) public {

        if (rewardPerLiquidityLast[msg.sender][incentiveId] != 0) revert AlreadySubscribed();

        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;

        UserStake storage userStake = userStakes[msg.sender][incentive.token];

        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.pushUint24Value(uint24(incentiveId));

        incentive.liquidityStaked += userStake.liquidity;

    }

    /// @param incentiveIndex ∈ [0,5]
    function unsubscribeFromIncentive(address token, uint256 incentiveIndex, bool ignoreRewards) external {

        UserStake storage userStake = userStakes[msg.sender][token];

        uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(incentiveIndex);

        if (rewardPerLiquidityLast[msg.sender][incentiveId] == 0) revert AlreadyUnsubscribed();
        
        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        /// In case there is an issue with transfering rewards we can ignore them.
        if (!ignoreRewards) _claimReward(incentive, incentiveId, userStake.liquidity);

        rewardPerLiquidityLast[msg.sender][incentiveId] = 0;

        unchecked { incentive.liquidityStaked -= userStake.liquidity; }

        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.removeUint24ValueAt(incentiveIndex);

    }

    function claimRewards(uint256[] calldata incentiveIds) external {

        uint256 n = incentiveIds.length;

        for(uint256 i = 0; i < n; i = _increment(i)) {

            Incentive storage incentive = incentives[incentiveIds[i]];

            _accrueRewards(incentive);

            _claimReward(incentive, incentiveIds[i], userStakes[msg.sender][incentive.token].liquidity);

        }

    }

    function accrueRewards(uint256 incentiveId) external {
        _accrueRewards(incentives[incentiveId]);
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
                uint256 reward = uint256(incentive.rewardRemaining) * passedTime / totalTime;
                incentive.rewardPerLiquidity += reward * type(uint112).max / incentive.liquidityStaked;
                incentive.rewardRemaining -= uint112(reward);
                incentive.lastRewardTime = uint32(maxTime);
            }
        }
    }

    function _claimReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity) internal returns (uint256 reward) {

        if (rewardPerLiquidityLast[msg.sender][incentiveId] == 0) revert NotSubscribed();

        unchecked {
            uint256 rewardPerLiquidity = incentive.rewardPerLiquidity - rewardPerLiquidityLast[msg.sender][incentiveId];
            reward = rewardPerLiquidity * usersLiquidity / type(uint128).max; // use safe mulDiv that handles phantom overflow
        }

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;

        ERC20(incentive.rewardToken).safeTransfer(msg.sender, reward);

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
