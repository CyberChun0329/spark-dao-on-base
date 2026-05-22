// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Claim-pull reward pool seam for settled teaching sessions.
/// @dev The distributor owns pool storage, previews, single/batch claims, and dust
/// release. Registry reserve accounting and token transfer stay behind the callback
/// in `ITeachingRewardSource`.
interface ITeachingRewardDistributor {
    function TEACHING_REGISTRY() external view returns (address);

    function RESEARCH_REGISTRY() external view returns (address);

    /// @notice Record one reward pool for one teaching NFT and research asset.
    /// @dev Must only be callable by the configured teaching registry; duplicate
    /// pools are rejected by the distributor implementation.
    function recordTeachingRewardPool(
        uint64 teachingNftId,
        uint64 assetId,
        address stableAsset,
        uint256 assetPoolUnits,
        uint256 distributedUnits,
        uint64 snapshotAt,
        uint64 unlockAt,
        uint16 snapshotActiveLayer,
        uint16 totalEffectiveShareBps
    ) external;

    /// @notice Preview the current holder's claimable amount for a reward pool.
    /// @dev Claim rights follow the current research position holder at claim time.
    function getTeachingRewardClaimable(uint64 teachingNftId, uint64 assetId, uint64 positionId)
        external
        view
        returns (uint256 amount, uint64 unlockAt, bool claimed);

    /// @notice Claim one teaching reward pool through the distributor.
    function claimTeachingReward(uint64 teachingNftId, uint64 assetId, uint64 positionId) external;

    /// @notice Atomically claim multiple teaching reward pools for the caller.
    function claimTeachingRewardBatch(
        uint64[] calldata teachingNftIds,
        uint64[] calldata assetIds,
        uint64[] calldata positionIds
    ) external;
}
