// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "./TestSetup.sol";

contract CreateIncentiveTest is TestSetup {

    function testCreateIncentive(
        uint112 amount,
        uint32 startTime,
        uint32 endTime
    ) public {
        if (endTime <= startTime || endTime <= block.timestamp) return;
        _createIncentive(address(tokenA), address(tokenB), amount, startTime, endTime);
    }

    function testUpdateIncentive(
        int112 changeAmount,
        uint32 startTime,
        uint32 endTime
    ) public {
        if (changeAmount == type(int112).min) return; // since uint112(type(int112).min) throws an error

        StakingContractMainnet.Incentive memory incentive = _getIncentive(futureIncentive);
        if (changeAmount > 0 && uint112(changeAmount) + uint256(incentive.rewardRemaining) > type(uint112).max) return;

        startTime = startTime > uint32(block.timestamp) ? startTime : uint32(block.timestamp);
        endTime = endTime > uint32(block.timestamp) ? endTime : uint32(block.timestamp);
        uint32 newStartTime = startTime == 0 ? incentive.lastRewardTime : startTime;
        uint32 newEndTime = endTime == 0 ? incentive.endTime : endTime;
        if (newStartTime > newEndTime) return;

        _updateIncentive(futureIncentive, changeAmount, startTime, endTime);
    }

    function testStake(uint112 amount0, uint112 amount1) public {
        if (amount0 > type(uint112).max - amount1) return;
        _stake(address(tokenA), amount0, janeDoe);
        _stake(address(tokenA), amount1, johnDoe);
    }

    function testSubscribe() public {
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    function testStakeAndSubscribe(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe);
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    // todo test stakeInvalidToken
    // todo test subscribe twice
    // todo test subscribe to invalidIncentive
    // todo check reward rate stays the same after accruing rewards

}
