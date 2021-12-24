// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.6;

contract Chef {

    event IncentiveAdded();
    event IncentiveUpdated();

    struct Incentive {
        address owner;
        address token;
        address rewardToken;
        uint256 rewardPerSecond;
        uint256 lastRewardDate;
        uint256 endDate;
        uint256 rewardPerLiquidityGrowth;
        uint256 liquidityStaked;
    }

    struct Stake {
        address user;
        uint256 incentive;
        uint256 liquidity;
        uint256 rewardPreLiquidityGrowthLast;
    }

    uint256 public incentivesCount;

    mapping(uint256 => Incentive) public incentives;

    uint256 public stakesCount;

    mapping(uint256 => Stake) public stakes;

    constructor() {}

    function addIncentive(
        address token,
        address rewardToken,
        uint256 endDate,
        uint256 amount
    ) external {

        require(endDate > block.timestamp, "Expired");
        
        // transfer token amount to address(this)

        incentives[incentivesCount++] = Incentive({
            owner: msg.sender,
            token: token,
            rewardToken: rewardToken,
            rewardPerSecond: amount / (endDate - block.timestamp),
            rewardPerLiquidityGrowth: 0,
            liquidityStaked: 0,
            lastRewardDate: block.timestamp,
            endDate: endDate
        });

        emit IncentiveAdded();

    }

    function updateIncentive(
        uint256 incentiveId,
        uint256 newEndDate,
        int256 transferAmount
    ) external {

        require(newEndDate > block.timestamp, "Expired");

        Incentive storage incentive = incentives[incentiveId];

        require(msg.sender == incentive.owner, "Only owner");

        _updateIncentive(incentive);

        uint256 amountLeft = (incentive.endDate - block.timestamp) * incentive.rewardPerSecond;

        int256 newAmount = int256(amountLeft) + transferAmount;

        if (newAmount < 0) {
            newAmount = 0;
            transferAmount = -int256(amountLeft);
        }

        if (transferAmount < 0) // transfer
        if (transferAmount > 0) // transfer

        emit IncentiveUpdated();
    }

    function _updateIncentive(Incentive storage incentive) internal {
        uint256 endTime = block.timestamp > incentive.endDate ? incentive.endDate : block.timestamp;
        incentive.rewardPerLiquidityGrowth += (endTime - incentive.lastRewardDate) * incentive.rewardPerSecond;
        incentive.lastRewardDate = endTime;
    }

}
