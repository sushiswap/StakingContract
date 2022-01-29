// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.11;

import "ds-test/test.sol";
import "../StakingContract.sol";
import "./mock/Token.sol";

contract StakingContractTest is DSTest {

    StakingContract stakingContract = new StakingContract();
    Token tokenA = new Token();
    Token tokenB = new Token();
    Token tokenC = new Token();

    uint256 MAX_UINT256 = type(uint256).max;
    uint256 MAX_UINT48 = type(uint48).max;

    function setUp() public {
        tokenA.mint(MAX_UINT256 / 2); // forge test throws error without dividing by 2
        tokenB.mint(MAX_UINT256 / 2);
        tokenC.mint(MAX_UINT256 / 2);
        tokenA.approve(address(stakingContract), MAX_UINT256);
        tokenB.approve(address(stakingContract), MAX_UINT256);
        tokenC.approve(address(stakingContract), MAX_UINT256);
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }

    function testCreateIncentive(
        uint128 amount,
        uint48 startTime,
        uint48 endTime
    ) public {
        if (startTime < endTime && endTime > block.timestamp) {
            createIncentive(
                address(tokenA),
                address(tokenB),
                amount,
                startTime,
                endTime
            );
        }
    }

    function createIncentive(
        address token,
        address rewardToken,
        uint128 amount,
        uint48 startTime,
        uint48 endTime
    ) public {
        uint256 count = stakingContract.incentiveCount();
        uint256 thisBalance = tokenB.balanceOf(address(this));
        uint256 stakingContractBalance = tokenB.balanceOf(address(stakingContract));
    
        uint256 id = stakingContract.createIncentive(
            token,
            rewardToken,
            amount,
            startTime,
            endTime
        );

        StakingContract.Incentive memory incentive = getIncentive(id);

        assertEq(incentive.creator, address(this));
        assertEq(incentive.token, token);
        assertEq(incentive.rewardToken, rewardToken);
        assertEq(incentive.lastRewardTime, startTime < uint48(block.timestamp) ? uint48(block.timestamp) : startTime);
        assertEq(incentive.endTime, endTime);
        assertEq(incentive.rewardRemaining, amount);
        assertEq(incentive.liquidityStaked, 0);
        assertEq(incentive.rewardPerLiquidity, 1);
        assertEq(count, id);
        assertEq(stakingContract.incentiveCount(), id + 1);
        assertEq(thisBalance - amount, tokenB.balanceOf(address(this)));
        assertEq(stakingContractBalance + amount, tokenB.balanceOf(address(stakingContract)));

    }

    function getIncentive(uint256 id) public returns (StakingContract.Incentive memory incentive) {
        (
            address creator,
            address token,
            address rewardToken,
            uint48 lastRewardTime,
            uint48 endTime,
            uint128 rewardRemaining,
            uint128 liquidityStaked,
            uint256 rewardPerLiquidity
        ) = stakingContract.incentives(id);
        incentive = StakingContract.Incentive(
            creator,
            token,
            rewardToken,
            lastRewardTime,
            endTime,
            rewardRemaining,
            liquidityStaked,
            rewardPerLiquidity
        );
    }
}
