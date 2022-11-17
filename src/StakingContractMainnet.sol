// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "lib/solmate/src/utils/SafeTransferLib.sol";
import "lib/solmate/src/utils/ReentrancyGuard.sol";
import "./libraries/PackedUint144.sol";
import "./libraries/FullMath.sol";

/*
    Permissionless staking contract that allows any number of incentives to be running for any token (erc20).
    Incentives can be created by anyone, the total reward amount must be sent at creation.
    Incentives can be updated (change reward rate / duration).
    Users can deposit their assets into the contract and then subscribe to any of the available incentives, up to 6 per token.
 */

contract StakingContractMainnet is ReentrancyGuard {

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
    /// @dev Semantic overload: if value is zero user isn't subscribed to the incentive.
    mapping(address => mapping(uint256 => uint256)) public rewardPerLiquidityLast;

    /// @dev userStakes[user][stakedToken]
    mapping(address => mapping(address => UserStake)) public userStakes;

    // Incentive count won't be greater than type(uint24).max on mainnet.
    // This means we can use uint24 values to identify incentives.
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
    error NoToken();
    error InvalidInput();
    error BatchError(bytes innerError);
    error InsufficientStakedAmount();
    error NotStaked();
    error InvalidIndex();

    event IncentiveCreated(address indexed token, address indexed rewardToken, address indexed creator, uint256 id, uint256 amount, uint256 startTime, uint256 endTime);
    event IncentiveUpdated(uint256 indexed id, int256 changeAmount, uint256 newStartTime, uint256 newEndTime);
    event Stake(address indexed token, address indexed user, uint256 amount);
    event Unstake(address indexed token, address indexed user, uint256 amount);
    event Subscribe(uint256 indexed id, address indexed user);
    event Unsubscribe(uint256 indexed id, address indexed user);
    event Claim(uint256 indexed id, address indexed user, uint256 amount);

    function createIncentive(
        address token,
        address rewardToken,
        uint112 rewardAmount,
        uint32 startTime,
        uint32 endTime
    ) external nonReentrant returns (uint256 incentiveId) {

        if (rewardAmount <= 0) revert InvalidInput();

        if (startTime < block.timestamp) startTime = uint32(block.timestamp);

        if (startTime >= endTime) revert InvalidTimeFrame();

        unchecked { incentiveId = ++incentiveCount; }

        if (incentiveId > type(uint24).max) revert IncentiveOverflow();

        _saferTransferFrom(rewardToken, rewardAmount);

        incentives[incentiveId] = Incentive({
            creator: msg.sender,
            token: token,
            rewardToken: rewardToken,
            lastRewardTime: startTime,
            endTime: endTime,
            rewardRemaining: rewardAmount,
            liquidityStaked: 0,
            // Initial value of rewardPerLiquidity can be arbitrarily set to a non-zero value.
            rewardPerLiquidity: type(uint256).max / 2
        });

        emit IncentiveCreated(token, rewardToken, msg.sender, incentiveId, rewardAmount, startTime, endTime);

    }

    function updateIncentive(
        uint256 incentiveId,
        int112 changeAmount,
        uint32 newStartTime,
        uint32 newEndTime
    ) external nonReentrant {

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

        if (incentive.lastRewardTime >= incentive.endTime) revert InvalidTimeFrame();

        if (changeAmount > 0) {

            incentive.rewardRemaining += uint112(changeAmount);

            ERC20(incentive.rewardToken).safeTransferFrom(msg.sender, address(this), uint112(changeAmount));

        } else if (changeAmount < 0) {

            uint112 transferOut = uint112(-changeAmount);

            if (transferOut > incentive.rewardRemaining) transferOut = incentive.rewardRemaining;

            unchecked { incentive.rewardRemaining -= transferOut; }

            ERC20(incentive.rewardToken).safeTransfer(msg.sender, transferOut);

        }

        emit IncentiveUpdated(incentiveId, changeAmount, incentive.lastRewardTime, incentive.endTime);

    }

    function stakeAndSubscribeToIncentives(
        address token,
        uint112 amount,
        uint256[] memory incentiveIds,
        bool transferExistingRewards
    ) external {

        stakeToken(token, amount, transferExistingRewards);

        uint256 n = incentiveIds.length;

        for (uint256 i = 0; i < n; i = _increment(i)) {

            subscribeToIncentive(incentiveIds[i]);

        }

    }

    function stakeToken(address token, uint112 amount, bool transferExistingRewards) public nonReentrant {

        _saferTransferFrom(token, amount);

        UserStake storage userStake = userStakes[msg.sender][token];

        uint112 previousLiquidity = userStake.liquidity;

        userStake.liquidity += amount;

        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();

        for (uint256 i = 0; i < n; i = _increment(i)) { // Loop through already subscribed incentives.

            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);

            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            if (transferExistingRewards) {

                _claimReward(incentive, incentiveId, previousLiquidity);

            } else {

                _saveReward(incentive, incentiveId, previousLiquidity, userStake.liquidity);

            }

            incentive.liquidityStaked += amount;

        }

        emit Stake(token, msg.sender, amount);

    }

    function unstakeToken(address token, uint112 amount, bool transferExistingRewards) external nonReentrant {

        UserStake storage userStake = userStakes[msg.sender][token];

        uint112 previousLiquidity = userStake.liquidity;

        if (amount > previousLiquidity) revert InsufficientStakedAmount();

        userStake.liquidity -= amount;

        uint256 n = userStake.subscribedIncentiveIds.countStoredUint24Values();

        for (uint256 i = 0; i < n; i = _increment(i)) {

            uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(i);

            Incentive storage incentive = incentives[incentiveId];

            _accrueRewards(incentive);

            if (transferExistingRewards || userStake.liquidity == 0) {

                _claimReward(incentive, incentiveId, previousLiquidity);

            } else {

                _saveReward(incentive, incentiveId, previousLiquidity, userStake.liquidity);

            }

            incentive.liquidityStaked -= amount;

        }

        ERC20(token).safeTransfer(msg.sender, amount);

        emit Unstake(token, msg.sender, amount);

    }

    function subscribeToIncentive(uint256 incentiveId) public nonReentrant {

        if (incentiveId > incentiveCount || incentiveId <= 0) revert InvalidInput();

        if (rewardPerLiquidityLast[msg.sender][incentiveId] != 0) revert AlreadySubscribed();

        Incentive storage incentive = incentives[incentiveId];

        if (userStakes[msg.sender][incentive.token].liquidity <= 0) revert NotStaked();

        _accrueRewards(incentive);

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;

        UserStake storage userStake = userStakes[msg.sender][incentive.token];

        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.pushUint24Value(uint24(incentiveId));

        incentive.liquidityStaked += userStake.liquidity;

        emit Subscribe(incentiveId, msg.sender);

    }

    /// @param incentiveIndex ∈ [0,5]
    function unsubscribeFromIncentive(address token, uint256 incentiveIndex, bool ignoreRewards) external nonReentrant {

        UserStake storage userStake = userStakes[msg.sender][token];

        if (incentiveIndex >= userStake.subscribedIncentiveIds.countStoredUint24Values()) revert InvalidIndex();

        uint256 incentiveId = userStake.subscribedIncentiveIds.getUint24ValueAt(incentiveIndex);

        if (rewardPerLiquidityLast[msg.sender][incentiveId] == 0) revert AlreadyUnsubscribed();

        Incentive storage incentive = incentives[incentiveId];

        _accrueRewards(incentive);

        /// In case there is a token specific issue we can ignore rewards.
        if (!ignoreRewards) _claimReward(incentive, incentiveId, userStake.liquidity);

        rewardPerLiquidityLast[msg.sender][incentiveId] = 0;

        incentive.liquidityStaked -= userStake.liquidity;

        userStake.subscribedIncentiveIds = userStake.subscribedIncentiveIds.removeUint24ValueAt(incentiveIndex);

        emit Unsubscribe(incentiveId, msg.sender);

    }

    function accrueRewards(uint256 incentiveId) external nonReentrant {

        if (incentiveId > incentiveCount || incentiveId <= 0) revert InvalidInput();

        _accrueRewards(incentives[incentiveId]);

    }

    function claimRewards(uint256[] calldata incentiveIds) external nonReentrant returns (uint256[] memory rewards) {

        uint256 n = incentiveIds.length;

        rewards = new uint256[](n);

        for(uint256 i = 0; i < n; i = _increment(i)) {

            if (incentiveIds[i] > incentiveCount || incentiveIds[i] <= 0) revert InvalidInput();

            Incentive storage incentive = incentives[incentiveIds[i]];

            _accrueRewards(incentive);

            rewards[i] = _claimReward(incentive, incentiveIds[i], userStakes[msg.sender][incentive.token].liquidity);

        }

    }

    function _accrueRewards(Incentive storage incentive) internal {

        uint256 lastRewardTime = incentive.lastRewardTime;

        uint256 endTime = incentive.endTime;

        unchecked {

            uint256 maxTime = block.timestamp < endTime ? block.timestamp : endTime;

            if (incentive.liquidityStaked > 0 && lastRewardTime < maxTime) {

                uint256 totalTime = endTime - lastRewardTime;

                uint256 passedTime = maxTime - lastRewardTime;

                uint256 reward = uint256(incentive.rewardRemaining) * passedTime / totalTime;

                // Increments of less than type(uint224).max - overflow is unrealistic.
                incentive.rewardPerLiquidity += reward * type(uint112).max / incentive.liquidityStaked;

                incentive.rewardRemaining -= uint112(reward);

                incentive.lastRewardTime = uint32(maxTime);

            } else if (incentive.liquidityStaked == 0 && lastRewardTime < block.timestamp) {

                incentive.lastRewardTime = uint32(maxTime);

            }

        }

    }

    function _claimReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity) internal returns (uint256 reward) {

        reward = _calculateReward(incentive, incentiveId, usersLiquidity);

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity;

        ERC20(incentive.rewardToken).safeTransfer(msg.sender, reward);

        emit Claim(incentiveId, msg.sender, reward);

    }

    // We offset the rewardPerLiquidityLast snapshot so that the current reward is included next time we call _claimReward.
    function _saveReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity, uint112 newLiquidity) internal returns (uint256 reward) {

        reward = _calculateReward(incentive, incentiveId, usersLiquidity);

        uint256 rewardPerLiquidityDelta = reward * type(uint112).max / newLiquidity;

        rewardPerLiquidityLast[msg.sender][incentiveId] = incentive.rewardPerLiquidity - rewardPerLiquidityDelta;

    }

    function _calculateReward(Incentive storage incentive, uint256 incentiveId, uint112 usersLiquidity) internal view returns (uint256 reward) {

        uint256 userRewardPerLiquidtyLast = rewardPerLiquidityLast[msg.sender][incentiveId];

        if (userRewardPerLiquidtyLast == 0) revert NotSubscribed();

        uint256 rewardPerLiquidityDelta;

        unchecked { rewardPerLiquidityDelta = incentive.rewardPerLiquidity - userRewardPerLiquidtyLast; }

        reward = FullMath.mulDiv(rewardPerLiquidityDelta, usersLiquidity, type(uint112).max);

    }

    function _saferTransferFrom(address token, uint256 amount) internal {

        if (token.code.length == 0) revert NoToken();

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);

    }

    function _increment(uint256 i) internal pure returns (uint256) {

        unchecked { return i + 1; }

    }

    function batch(bytes[] calldata datas) external {

        uint256 n = datas.length;

        for (uint256 i = 0; i < n; i = _increment(i)) {

            (bool success, bytes memory result) = address(this).delegatecall(datas[i]);

            if (!success) {

                revert BatchError(result);

            }

        }

    }

}
