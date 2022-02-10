// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.11;

interface IStakingContractActions {
    /// @notice Creates incentive for the given token/rewardToken/rewardAmount/startTime/endTime
    /// @dev ...
    /// @param token The address for which the incentive will be created
    /// @param rewardToken The reward token address
    /// @param rewardAmount The reward amount
    /// @param startTime The time incentive starts
    /// @param endTime The time incentive ends
    /// @return incentiveId The created incentive id
    function createIncentive(
        address token,
        address rewardToken,
        uint128 rewardAmount,
        uint48 startTime,
        uint48 endTime
    ) external returns (uint256 incentiveId);
    /// @notice Updates incentive for the given incentiveId/transferIn/transferOut/newStartTime/newEndTime
    /// @dev ...
    /// @param incentiveId The incentive id for which will be updated
    /// @param transferIn The reward amount transfered in
    /// @param transferOut The reward amount transfered out
    /// @param newStartTime The start time
    /// @param newEndTime The end time
    function updateIncentive(
        uint256 incentiveId,
        uint128 transferIn,
        uint128 transferOut,
        uint48 newStartTime,
        uint48 newEndTime
    ) external;

    function stakeToken(address token, uint128 amount) external;

    function unstakeToken(address token, uint128 amount) external;

    function subscribeToIncentive(uint256 incentiveId) external;

    function unsubscribeFromIncentive(address token, uint256 incentiveIndex, bool ignoreRewards) external;

    function claimRewards(uint256[] calldata incentiveIds) external;
}