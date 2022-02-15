// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "./TestSetup.sol";

contract CreateIncentiveTest is TestSetup {

    function testCreateIncentive(
        uint112 amount,
        uint32 startTime,
        uint32 endTime
    ) public {
        _createIncentive(address(tokenA), address(tokenB), amount, startTime, endTime);
    }

    function testUpdateIncentive(
        int112 changeAmount0,
        int112 changeAmount1,
        uint32 startTime0,
        uint32 startTime1,
        uint32 endTime0,
        uint32 endTime1
    ) public {
        _updateIncentive(ongoingIncentive, changeAmount0, startTime0, endTime0);
        _updateIncentive(ongoingIncentive, changeAmount0, startTime0, endTime0);
        _updateIncentive(ongoingIncentive, changeAmount1, startTime1, endTime1);
    }

    function testStake(uint112 amount0, uint112 amount1) public {
        _stake(address(tokenA), amount0, janeDoe);
        _stake(address(tokenA), amount0, janeDoe);
        _stake(address(tokenA), amount1, janeDoe);
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

    function testClaimRewards() public {
        _claimReward(pastIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
    }

    // todo test stakeInvalidToken
    // todo test subscribe twice
    // todo test subscribe to invalidIncentive
    // todo check reward rate stays the same after accruing rewards

}
