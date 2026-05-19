// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ITeachingRewardDistributor {
    function TEACHING_REGISTRY() external view returns (address);

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

    function getTeachingRewardClaimable(uint64 teachingNftId, uint64 assetId, uint64 positionId)
        external
        view
        returns (uint256 amount, uint64 unlockAt, bool claimed);

    function claimTeachingReward(uint64 teachingNftId, uint64 assetId, uint64 positionId) external;

    function claimTeachingRewardBatch(
        uint64[] calldata teachingNftIds,
        uint64[] calldata assetIds,
        uint64[] calldata positionIds
    ) external;
}
