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

    function testFailCreateIncentiveInvalidRewardToken(uint32 startTime, uint32 endTime) public {
        _createIncentive(address(tokenA), zeroAddress, 1, startTime, endTime);
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
        _stake(address(tokenA), amount0, janeDoe, true);
        _stake(address(tokenA), amount0, janeDoe, true);
        _stake(address(tokenA), amount1, janeDoe, true);
        _stake(address(tokenA), amount1, johnDoe, true);
    }

    function testSubscribe() public {
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    function testStakeAndSubscribeSeparate(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe, true);
        _subscribeToIncentive(pastIncentive, johnDoe);
        _subscribeToIncentive(futureIncentive, johnDoe);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
    }

    function testStakeAndSubscribe(uint112 amount) public {
      uint256[] memory idsToSubscribe = new uint256[](2);
      idsToSubscribe[0] = pastIncentive;
      idsToSubscribe[1] = ongoingIncentive;
      _stakeAndSubscribeToIncentives(address(tokenA), amount, idsToSubscribe, johnDoe, true);
    }

    function testAccrue(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe, true);
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
        _accrueRewards(0);
        _accrueRewards(stakingContract.incentiveCount() + 1);
    }

    function testClaimRewards0() public {
        _claimReward(pastIncentive, johnDoe);
        _claimReward(pastIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(futureIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
        _claimReward(ongoingIncentive, johnDoe);
        _stake(address(tokenA), 1, johnDoe, true);
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
        _stake(address(tokenA), amount, johnDoe, true);
        StakingContractMainnet.Incentive memory incentive = _getIncentive(ongoingIncentive);
        uint256 totalReward = incentive.rewardRemaining;
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        vm.warp(incentive.endTime);
        uint256 reward = _claimReward(ongoingIncentive, johnDoe);
        assertEqInexact(reward, totalReward, 1);
        incentive = _getIncentive(ongoingIncentive);
        assertEq(incentive.rewardRemaining, 0);
    }

    function testClaimRewards2(uint96 amount0, uint96 amount1) public {
        if (amount0 == 0 || amount1 == 0) return;
        uint256 maxRatio = 1000000;
        if (amount0 / amount1 > 1000000) return; // to avoid rounding innacuracies for easier testing
        if (amount1 / amount0 > 1000000) return;

        StakingContractMainnet.Incentive memory incentive = _getIncentive(ongoingIncentive);
        uint256 totalReward = incentive.rewardRemaining;
        _stake(address(tokenA), amount0, johnDoe, true);
        _stake(address(tokenA), amount1, janeDoe, true);
        _subscribeToIncentive(ongoingIncentive, johnDoe);

        vm.warp((incentive.lastRewardTime + incentive.endTime) / 2);
        uint256 soloReward = _claimReward(ongoingIncentive, johnDoe);

        _subscribeToIncentive(ongoingIncentive, janeDoe);
        vm.warp(incentive.endTime);

        uint256 reward0 = _claimReward(ongoingIncentive, johnDoe);
        uint256 reward1 = _claimReward(ongoingIncentive, janeDoe);

        incentive = _getIncentive(ongoingIncentive);
        uint256 ratio;
        if (amount0 / amount1 > 0) {
            ratio = maxRatio * amount0 / amount1;
            assertEqInexact(maxRatio * reward0 / reward1, ratio, 10);
        }
        if (amount1 / amount0 > 0) {
            ratio = maxRatio * amount1 / amount0;
            assertEqInexact(maxRatio * reward1 / reward0, ratio, 10);
        }
        assertEqInexact(reward0 + reward1 + soloReward, totalReward, 10);
    }

    function testUnstakeSaveRewards() public {
        _stake(address(tokenA), 1, johnDoe, true);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        StakingContractMainnet.Incentive memory incentive = _getIncentive(ongoingIncentive);
        uint256 rewardRemaining = incentive.rewardRemaining;
        vm.warp((incentive.lastRewardTime + incentive.endTime) / 2);
        _stake(address(tokenA), 1, johnDoe, false);
        vm.warp((incentive.lastRewardTime + incentive.endTime) / 2 + 100);
        _stake(address(tokenA), 1, johnDoe, false);
        vm.warp(incentive.endTime);
        _unstake(address(tokenA), 1, johnDoe, false);
        uint256 reward = _claimReward(ongoingIncentive, johnDoe);
        assertEq(reward, rewardRemaining);
        reward = _claimReward(ongoingIncentive, johnDoe);
        assertEq(reward, 0);
    }

    function testFalseStakeAndSubscribe(uint112 amount) public {
        _stake(address(tokenA), amount, johnDoe, true);
        _subscribeToIncentive(0, johnDoe);
        _subscribeToIncentive(stakingContract.incentiveCount() + 1, johnDoe);
    }

    function testStakeInvalidToken() public {
        vm.prank(johnDoe);
        vm.expectRevert(noToken);
        stakingContract.stakeToken(janeDoe, 1, true);
    }

    function testRewardRate() public {
        _stake(address(tokenA), 1, johnDoe, true);
        _subscribeToIncentive(ongoingIncentive, johnDoe);
        uint256 oldRate = _rewardRate(ongoingIncentive);
        vm.warp(block.timestamp + testIncentiveDuration / 2);
        stakingContract.accrueRewards(ongoingIncentive);
        uint256 newRate = _rewardRate(ongoingIncentive);
        assertEq(oldRate, newRate);
    }

    function testBatch() public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(stakingContract.stakeToken, (address(tokenA), 1, true));
        data[1] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        vm.prank(johnDoe);
        stakingContract.batch(data);
        (uint112 liquidity, uint144 subscriptions) = stakingContract.userStakes(johnDoe, address(tokenA));
        assertEq(liquidity, 1);
        assertEq(subscriptions, ongoingIncentive);
    }

    function testBatch2() public {
      bytes[] memory data = new bytes[](3);
      uint256[] memory idsToSubscribe = new uint256[](3);
      idsToSubscribe[0] = pastIncentive;
      idsToSubscribe[1] = ongoingIncentive;
      idsToSubscribe[2] = futureIncentive;

      data[0] = abi.encodeCall(stakingContract.stakeAndSubscribeToIncentives, (address(tokenA), 1, idsToSubscribe, true));
      data[1] = abi.encodeCall(stakingContract.unsubscribeFromIncentive, (address(tokenA), 1, false));
      data[2] = abi.encodeCall(stakingContract.unsubscribeFromIncentive, (address(tokenA), 0, false));

      vm.prank(johnDoe);
      stakingContract.batch(data);
      (uint112 liquidity, uint144 subscriptions) = stakingContract.userStakes(johnDoe, address(tokenA));

      assertEq(liquidity, 1);
      assertEq(subscriptions, pastIncentive);
    }

    function testFailedBatchRaisesProperError() public {
        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeCall(stakingContract.stakeToken, (address(tokenA), 1, true));
        data[1] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        data[2] = abi.encodeCall(stakingContract.subscribeToIncentive, (ongoingIncentive));
        vm.prank(johnDoe);
        vm.expectRevert(alreadySubscribed);
        stakingContract.batch(data);
    }

}
