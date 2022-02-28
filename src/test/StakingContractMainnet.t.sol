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
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    function testStakeAndSubscribe(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe);
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    function testAccrue(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe);
        _accrueRewards(pastIncentive);
        _accrueRewards(ongoingIncentive);
        _accrueRewards(futureIncentive);
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        _accrueRewards(pastIncentive);
        _accrueRewards(ongoingIncentive);
        _accrueRewards(futureIncentive);
        uint256 step = testIncentiveDuration / 2;
        vm.warp(block.timestamp + step);
        _accrueRewards(pastIncentive);
        _accrueRewards(ongoingIncentive);
        _accrueRewards(futureIncentive);
        vm.warp(block.timestamp + step);
        _accrueRewards(ongoingIncentive);
        _accrueRewards(futureIncentive);
        vm.warp(block.timestamp + step);
        _accrueRewards(futureIncentive);
        vm.warp(block.timestamp + step);
        _accrueRewards(futureIncentive);
        vm.warp(block.timestamp + step);
        _accrueRewards(futureIncentive);
    }

    function testClaimRewards0() public {
        _claimReward(pastIncentive, johnDoe);
        _claimReward(pastIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
        _stake(address(tokenA), 1, johnDoe);
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _claimReward(pastIncentive, johnDoe);
        _claimReward(pastIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
    }

    function testClaimRewards1(uint112 amount) public {
        if (amount == 0) return;
        _stake(address(tokenA), amount, johnDoe);
        StakingContractMainnet.Incentive memory incentive = _getIncentive(ongoingIncentive);
        uint256 totalReward = incentive.rewardRemaining;
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        vm.warp(incentive.endTime);
        uint256 reward = _claimReward(ongoingIncentive, johnDoe);
        assertEqInexact(reward, totalReward, 1);
        incentive = _getIncentive(ongoingIncentive);
        assertEq(incentive.rewardRemaining, 0);
    }

    function testFailStakeAndSubscribe(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe);
        _subscribeToIncentive(0, johnDoe);
    }

    function testStakeInvalidToken() public {
        vm.prank(johnDoe);
        vm.expectRevert(noToken);
        stakingContract.stakeToken(janeDoe, 1);
    }

    function testRewardRate() public {
        _stake(address(tokenA), 1, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        uint256 oldRate = _rewardRate(ongoingIncentive);
        vm.warp(block.timestamp + testIncentiveDuration / 2);
        stakingContract.accrueRewards(ongoingIncentive);
        uint256 newRate = _rewardRate(ongoingIncentive);
        assertEq(oldRate, newRate);
    }

    function testBatch() public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(stakingContract.stakeToken, (address(tokenA), 1));
        data[1] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        vm.prank(johnDoe);
        stakingContract.batch(data);
        (uint112 liquidity, uint144 subscriptions) = stakingContract.userStakes(johnDoe, address(tokenA));
        assertEq(liquidity, 1);
        assertEq(subscriptions, ongoingIncentive);
    }

    function testFailBatch() public {
        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(stakingContract.stakeToken, (address(tokenA), 1));
        data[1] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        data[2] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        vm.prank(johnDoe);
        stakingContract.batch(data);
    }

}
