// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.11;

/// @title Events emitted by the staking contract
/// @notice Contains all events emitted by the staking contract
interface IStakingContractEvents {
    /// @notice Emitted when incentive is created
    /// @param token The address of which token will be incentivsed
    /// @param rewardToken The reward token address
    /// @param rewardAmount The reward amount
    /// @param startTime The start time
    /// @param endTime The end time
    event Created(
        address token,
        address rewardToken,
        uint128 rewardAmount,
        uint48 startTime,
        uint48 endTime
    );

    /// @notice Emitted when incentive is updated
    /// @param incentiveId The id of which incentive will be updated
    /// @param transferIn The reward amount transfered in
    /// @param transferOut The reward amount transfered out
    /// @param newStartTime The start time
    /// @param newEndTime The end time
    event Updated(
        uint256 incentiveId,
        uint128 transferIn,
        uint128 transferOut,
        uint48 newStartTime,
        uint48 newEndTime
    );

    /// @notice Emitted when incentivised token is staked
    /// @param token The address of which token will be staked
    /// @param amount The amount of which token will be staked 
    event Staked(
        address token,
        uint128 amount
    );

    /// @notice Emitted when incentivised token is unstaked
    /// @param token The address of which token will be unstaked
    /// @param amount The amount of which token will be unstaked 
    event Unstaked(
        address token,
        uint128 amount
    );

    /// @notice Emitted when incentive is subscribed
    /// @param incentiveId The id of which incentive is subscribed
    event Subscribed(
        uint256 incentiveId
    );

    /// @notice Emitted when incentive is unsubscribed
    /// @param token The address of which token is unsubscribed
    /// @param incentiveIndex The index of which incentive is unsubscribed
    /// @param ignoreRewards The rewards were ignored
    event Unsubscribed(address token, uint256 incentiveIndex, bool ignoreRewards);

    /// @notice Emitted when incentives claimed
    /// @param incentiveIds The incentive ids of which incentives claimed
    event Claimed(uint256[] incentiveIds);
}