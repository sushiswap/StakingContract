// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "ds-test/test.sol";
import "../StakingContractMainnet.sol";
import "./mock/Token.sol";
import "./Console.sol";

interface Vm {
    function prank(address) external;
    function warp(uint256) external;
    function expectRevert(bytes memory) external;
    function expectRevert(bytes4) external;
}

contract TestSetup is DSTest {

    Vm vm = Vm(HEVM_ADDRESS);

    address johnDoe = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address janeDoe = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    
    uint256 MAX_UINT256 = type(uint256).max;
    uint112 MAX_UINT112 = type(uint112).max;
    uint32 testIncentiveDuration = 2592000;
    uint112 testIncentiveAmount = 1e21;

    bytes4 invalidTimeFrame = bytes4(keccak256("InvalidTimeFrame()"));
    bytes4 panic = 0x4e487b71;
    bytes overflow = abi.encodePacked(panic, bytes32(uint256(0x11)));

    StakingContractMainnet stakingContract = new StakingContractMainnet();

    Token tokenA = new Token();
    Token tokenB = new Token();
    Token tokenC = new Token();

    uint256 pastIncentive;
    uint256 ongoingIncentive;
    uint256 futureIncentive;

    function setUp() public {
        tokenA.mint(MAX_UINT256);
        tokenB.mint(MAX_UINT256);
        tokenC.mint(MAX_UINT256);
        
        tokenA.approve(address(stakingContract), MAX_UINT256);
        tokenB.approve(address(stakingContract), MAX_UINT256);
        tokenC.approve(address(stakingContract), MAX_UINT256);

        tokenA.transfer(johnDoe, MAX_UINT112);
        tokenA.transfer(janeDoe, MAX_UINT112);

        vm.prank(johnDoe);
        tokenA.approve(address(stakingContract), MAX_UINT256);

        vm.prank(janeDoe);
        tokenA.approve(address(stakingContract), MAX_UINT256);

        uint112 amount = testIncentiveAmount;
        uint256 duration = testIncentiveDuration;

        pastIncentive = _createIncentive(address(tokenA), address(tokenB), amount, uint32(block.timestamp), uint32(block.timestamp + duration));
        vm.warp(block.timestamp + duration + 1);
        ongoingIncentive = _createIncentive(address(tokenA), address(tokenB), amount, uint32(block.timestamp), uint32(block.timestamp + duration));
        futureIncentive = _createIncentive(address(tokenA), address(tokenB), amount, uint32(block.timestamp + duration), uint32(block.timestamp + duration * 2));
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }

    function _createIncentive(
        address token,
        address rewardToken,
        uint112 amount,
        uint32 startTime,
        uint32 endTime
    ) public returns(uint256) {
        uint256 count = stakingContract.incentiveCount();
        uint256 thisBalance = Token(rewardToken).balanceOf(address(this));
        uint256 stakingContractBalance = Token(rewardToken).balanceOf(address(stakingContract));

        if (endTime <= startTime || endTime <= block.timestamp) {
            vm.expectRevert(invalidTimeFrame);
            return stakingContract.createIncentive(token, rewardToken, amount, startTime, endTime);
        }

        uint256 id = stakingContract.createIncentive(token, rewardToken, amount, startTime, endTime);

        StakingContractMainnet.Incentive memory incentive = _getIncentive(id);

        assertEq(incentive.creator, address(this));
        assertEq(incentive.token, token);
        assertEq(incentive.rewardToken, rewardToken);
        assertEq(incentive.lastRewardTime, startTime < block.timestamp ? uint32(block.timestamp) : startTime);
        assertEq(incentive.endTime, endTime);
        assertEq(incentive.rewardRemaining, amount);
        assertEq(incentive.liquidityStaked, 0);
        assertEq(incentive.rewardPerLiquidity, 1);
        assertEq(count + 1, id);
        assertEq(stakingContract.incentiveCount(), id);
        assertEq(thisBalance - amount, Token(rewardToken).balanceOf(address(this)));
        assertEq(stakingContractBalance + amount, Token(rewardToken).balanceOf(address(stakingContract)));
        return id;
    }

    function _updateIncentive(
        uint256 incentiveId,
        int112 changeAmount,
        uint32 startTime,
        uint32 endTime
    ) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 thisBalance = Token(incentive.rewardToken).balanceOf(address(this));
        uint256 stakingContractBalance = Token(incentive.rewardToken).balanceOf(address(stakingContract));

        uint32 newStartTime = startTime == 0 ? incentive.lastRewardTime : (startTime > uint32(block.timestamp) ? startTime : uint32(block.timestamp));
        uint32 newEndTime = endTime == 0 ? incentive.endTime : (endTime > uint32(block.timestamp) ? endTime : uint32(block.timestamp));
        if (newStartTime > newEndTime) {
            vm.expectRevert(invalidTimeFrame);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        if (changeAmount == type(int112).min) {
            vm.expectRevert(overflow);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        if (changeAmount > 0 && uint112(changeAmount) + uint256(incentive.rewardRemaining) > type(uint112).max) {
            vm.expectRevert(overflow);
            stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);
            return;
        }

        stakingContract.updateIncentive(incentiveId, changeAmount, startTime, endTime);

        if (changeAmount < 0 && uint112(-changeAmount) > incentive.rewardRemaining) {
            changeAmount = -int112(incentive.rewardRemaining);
        }

        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId);
        assertEq(updatedIncentive.lastRewardTime, startTime != 0 ? (startTime < block.timestamp ? block.timestamp : startTime) : incentive.lastRewardTime);
        assertEq(updatedIncentive.endTime, endTime != 0 ? (endTime < block.timestamp ? block.timestamp : endTime) : incentive.endTime);
        assertEq(updatedIncentive.rewardRemaining, changeAmount < 0 ? incentive.rewardRemaining - uint112(-changeAmount) : incentive.rewardRemaining + uint112(changeAmount));
        assertEq(updatedIncentive.creator, incentive.creator);
        assertEq(updatedIncentive.token, incentive.token);
        assertEq(updatedIncentive.rewardToken, incentive.rewardToken);
        assertEq(updatedIncentive.liquidityStaked, incentive.liquidityStaked);
    }

    function _stake(address token, uint112 amount, address from) public {
        // todo check if current incentives stakes got updates correctly
        uint256 userBalanceBefore = Token(token).balanceOf(from);
        uint256 stakingContractBalanceBefore = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityBefore = _getUsersLiquidityStaked(from, token);

        if (amount > userBalanceBefore) {
            vm.expectRevert(overflow);
            vm.prank(from);
            stakingContract.stakeToken(token, amount);
            return;
        }

        if (amount > type(uint112).max - userLiquidityBefore) {
            vm.expectRevert(overflow);
            vm.prank(from);
            stakingContract.stakeToken(token, amount);
            return;
        }

        vm.prank(from);
        stakingContract.stakeToken(token, amount);

        uint256 userBalanceAfter = Token(token).balanceOf(from);
        uint256 stakingContractBalanceAfter = Token(token).balanceOf(address(stakingContract));
        uint256 userLiquidityAfter = _getUsersLiquidityStaked(from, token);

        assertEq(userBalanceBefore - amount, userBalanceAfter);
        assertEq(userLiquidityBefore + amount, userLiquidityAfter);
        assertEq(stakingContractBalanceBefore + amount, stakingContractBalanceAfter);
    }

    function _subscribeToIncentive(uint256 incentiveId, address from) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint112 liquidity = _getUsersLiquidityStaked(from, incentive.token);
        
        vm.prank(from);
        stakingContract.subscribeToIncentive(incentiveId);
        
        StakingContractMainnet.Incentive memory incentiveAfter = _getIncentive(incentiveId);
        uint144 subscribedIncentives = _getUsersSubscribedIncentives(from, incentive.token);
        
        assertEq(incentive.liquidityStaked + liquidity, incentiveAfter.liquidityStaked);
        assertEq(uint24(subscribedIncentives), uint24(incentiveId));
        assertEq(stakingContract.rewardPerLiquidityLast(from, incentiveId), incentiveAfter.rewardPerLiquidity);
    }

    function _accrueRewards(uint256 incentiveId) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 rewardPerLiquidity;
        uint256 rewardRemaining;
        uint256 lastRewardTime;
        if (
            incentive.liquidityStaked > 0 &&
            incentive.lastRewardTime < block.timestamp &&
            incentive.lastRewardTime < incentive.endTime
        ) {
            (rewardPerLiquidity, rewardRemaining, lastRewardTime) = _calculateAccureChange(incentiveId); 
        } else {
            rewardPerLiquidity = incentive.rewardPerLiquidity;
            lastRewardTime = incentive.lastRewardTime;
            rewardRemaining = incentive.rewardRemaining;
        }
        stakingContract.accrueRewards(incentiveId);
        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId);
        assertEq(updatedIncentive.rewardPerLiquidity, rewardPerLiquidity);
        assertEq(updatedIncentive.lastRewardTime, lastRewardTime);
        assertEq(updatedIncentive.rewardRemaining, rewardRemaining);
    }

    function _calculateAccureChange(uint256 incentiveId) public returns (uint256 rewardPerLiquidity, uint256 rewardRemaining, uint256 lastRewardTime) {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);
        uint256 totalTime = incentive.endTime - incentive.lastRewardTime;
        uint256 maxTime = block.timestamp < incentive.endTime ? block.timestamp : incentive.endTime;
        uint256 passedTime = maxTime - incentive.lastRewardTime;
        uint256 reward = uint256(passedTime) * incentive.rewardRemaining / totalTime;
        uint256 rplChange = reward * type(uint112).max / incentive.liquidityStaked;
        uint256 timeLeft = incentive.endTime - maxTime;
        rewardPerLiquidity = incentive.rewardPerLiquidity + rplChange;
        rewardRemaining = incentive.rewardRemaining - reward;
        lastRewardTime = maxTime;
    }

    function _claimReward(uint256 incentiveId, address from) public {
        StakingContractMainnet.Incentive memory incentive = _getIncentive(incentiveId);

        /* uint256 balnceBefore = Token(incentive.rewardToken).balanceOf(from);
        uint256 usersLiquidity = _getUsersLiquidityStaked(from, incentive.token);
        uint256 rplLast = stakingContract.rewardPerLiquidityLast(from, incentiveId);
        uint256 rplCurrent = incentive.rewardPerLiquidity + incentive.rewardRemainin;

        if (rplCurrent == 0) {
            vm.expectRevert("aaaaaaa");
            vm.prank(from);
            uint256[] memory incentiveIds = new uint256[](1);
            incentiveIds[0] = incentiveId;
            stakingContract.claimRewards(incentiveIds);
        }



        vm.prank(from);
        uint256[] memory incentiveIds = new uint256[](1);
        incentiveIds[0] = incentiveId;
        stakingContract.claimRewards(incentiveIds);

        uint256 balnceAfter = Token(incentive.rewardToken).balanceOf(from);
        StakingContractMainnet.Incentive memory updatedIncentive = _getIncentive(incentiveId); */
    }

    function _getUsersLiquidityStaked(address user, address token) public returns (uint112) {
        (uint112 liquidity,) = stakingContract.userStakes(user, token);
        return liquidity;
    }

    function _getUsersSubscribedIncentives(address user, address token) public returns (uint144) {
        (, uint144 incentiveIds) = stakingContract.userStakes(user, token);
        return incentiveIds;
    }

    function _getIncentive(uint256 id) public returns (StakingContractMainnet.Incentive memory incentive) {
        (
            address creator,
            address token,
            address rewardToken,
            uint32 endTime,
            uint256 rewardPerLiquidity,
            uint32 lastRewardTime,
            uint112 rewardRemaining,
            uint112 liquidityStaked
        ) = stakingContract.incentives(id);
        incentive = StakingContractMainnet.Incentive(
            creator,
            token,
            rewardToken,
            endTime,
            rewardPerLiquidity,
            lastRewardTime,
            rewardRemaining,
            liquidityStaked
        );
    }
}