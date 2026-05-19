// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingRewardSource } from "./interfaces/ITeachingRewardSource.sol";

contract TeachingRewardDistributor {
    address public immutable TEACHING_REGISTRY;

    mapping(
        uint64 teachingNftId => mapping(uint64 assetId => SparkDaoTypes.TeachingRewardPool)
    ) internal teachingRewardPools;
    mapping(
        uint64 teachingNftId => mapping(uint64 assetId => mapping(uint64 positionId => bool))
    ) internal teachingRewardClaimed;

    event TeachingRewardPoolRecorded(
        uint64 indexed teachingNftId,
        uint64 indexed assetId,
        uint256 amount,
        uint64 unlockAt,
        uint16 totalEffectiveShareBps
    );
    event TeachingRewardClaimed(
        uint64 indexed teachingNftId,
        uint64 indexed assetId,
        uint64 indexed positionId,
        address holder,
        uint256 amount
    );

    modifier onlyTeachingRegistry() {
        _onlyTeachingRegistry();
        _;
    }

    constructor(address teachingRegistry_) {
        if (teachingRegistry_ == address(0)) revert SparkDaoErrors.ZeroAddress();
        TEACHING_REGISTRY = teachingRegistry_;
    }

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
    ) external onlyTeachingRegistry {
        SparkDaoTypes.TeachingRewardPool storage pool = teachingRewardPools[teachingNftId][assetId];
        if (pool.exists) revert SparkDaoErrors.InvalidTeachingRewardPool();

        pool.exists = true;
        pool.stableAsset = stableAsset;
        pool.assetPoolUnits = assetPoolUnits;
        pool.distributedUnits = distributedUnits;
        pool.snapshotAt = snapshotAt;
        pool.unlockAt = unlockAt;
        pool.snapshotActiveLayer = snapshotActiveLayer;
        pool.totalEffectiveShareBps = totalEffectiveShareBps;

        emit TeachingRewardPoolRecorded(
            teachingNftId, assetId, distributedUnits, unlockAt, totalEffectiveShareBps
        );
    }

    function getTeachingRewardClaimable(uint64 teachingNftId, uint64 assetId, uint64 positionId)
        external
        view
        returns (uint256 amount, uint64 unlockAt, bool claimed)
    {
        SparkDaoTypes.TeachingRewardPool storage pool =
            _requireTeachingRewardPool(teachingNftId, assetId);
        SparkDaoTypes.ResearchPosition memory position =
            ITeachingRewardSource(TEACHING_REGISTRY).getResearchPosition(assetId, positionId);
        uint16 effectiveShareBps = _effectiveClaimShareBps(pool, position);
        amount = _computeWeightedAmount(pool.assetPoolUnits, effectiveShareBps);
        claimed = teachingRewardClaimed[teachingNftId][assetId][positionId];
        unlockAt = pool.unlockAt;
    }

    function claimTeachingReward(uint64 teachingNftId, uint64 assetId, uint64 positionId) external {
        _claimTeachingReward(msg.sender, teachingNftId, assetId, positionId);
    }

    function claimTeachingRewardBatch(
        uint64[] calldata teachingNftIds,
        uint64[] calldata assetIds,
        uint64[] calldata positionIds
    ) external {
        _claimTeachingRewardBatch(msg.sender, teachingNftIds, assetIds, positionIds);
    }

    function _claimTeachingReward(
        address claimant,
        uint64 teachingNftId,
        uint64 assetId,
        uint64 positionId
    ) internal {
        SparkDaoTypes.ResearchPosition memory position = ITeachingRewardSource(TEACHING_REGISTRY)
            .getResearchPosition(assetId, positionId);
        if (position.currentHolder != claimant) revert SparkDaoErrors.UnauthorizedHolder();

        SparkDaoTypes.TeachingRewardPool storage pool =
            _requireTeachingRewardPool(teachingNftId, assetId);
        if (block.timestamp < pool.unlockAt) revert SparkDaoErrors.RevenueStillLocked();
        if (teachingRewardClaimed[teachingNftId][assetId][positionId]) {
            revert SparkDaoErrors.TeachingRewardAlreadyClaimed();
        }

        uint16 effectiveShareBps = _effectiveClaimShareBps(pool, position);
        if (effectiveShareBps == 0) revert SparkDaoErrors.InvalidTeachingRewardPool();

        uint256 claimAmount = _computeWeightedAmount(pool.assetPoolUnits, effectiveShareBps);
        uint256 remainingUnits = pool.distributedUnits - pool.claimedUnits;
        if (claimAmount > remainingUnits) claimAmount = remainingUnits;

        teachingRewardClaimed[teachingNftId][assetId][positionId] = true;
        pool.claimedShareBps += effectiveShareBps;
        if (claimAmount != 0) {
            pool.claimedUnits += claimAmount;
        }

        uint256 dustUnits = _releaseTeachingRewardDustIfComplete(pool);
        ITeachingRewardSource(TEACHING_REGISTRY)
            .settleTeachingRewardClaim(
                pool.stableAsset, claimant, assetId, positionId, claimAmount, dustUnits
            );

        emit TeachingRewardClaimed(teachingNftId, assetId, positionId, claimant, claimAmount);
    }

    function _claimTeachingRewardBatch(
        address claimant,
        uint64[] calldata teachingNftIds,
        uint64[] calldata assetIds,
        uint64[] calldata positionIds
    ) internal {
        uint256 claimCount = teachingNftIds.length;
        if (claimCount == 0 || claimCount != assetIds.length || claimCount != positionIds.length) {
            revert SparkDaoErrors.InvalidAmount();
        }

        for (uint256 i = 0; i < claimCount;) {
            _claimTeachingReward(claimant, teachingNftIds[i], assetIds[i], positionIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _onlyTeachingRegistry() internal view {
        if (msg.sender != TEACHING_REGISTRY) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
    }

    function _requireTeachingRewardPool(uint64 teachingNftId, uint64 assetId)
        internal
        view
        returns (SparkDaoTypes.TeachingRewardPool storage pool)
    {
        pool = teachingRewardPools[teachingNftId][assetId];
        if (!pool.exists) revert SparkDaoErrors.InvalidTeachingRewardPool();
    }

    function _releaseTeachingRewardDustIfComplete(SparkDaoTypes.TeachingRewardPool storage pool)
        internal
        returns (uint256 dustUnits)
    {
        if (
            pool.dustReleased || pool.claimedShareBps < pool.totalEffectiveShareBps
                || pool.claimedUnits >= pool.distributedUnits
        ) {
            return 0;
        }

        dustUnits = pool.distributedUnits - pool.claimedUnits;
        pool.claimedUnits = pool.distributedUnits;
        pool.dustReleased = true;
    }

    function _effectiveClaimShareBps(
        SparkDaoTypes.TeachingRewardPool storage pool,
        SparkDaoTypes.ResearchPosition memory position
    ) internal view returns (uint16) {
        return _computeEffectiveTeachingShareBps(
            pool.snapshotActiveLayer,
            pool.snapshotAt,
            position.activatedAt,
            position.layerIndex,
            position.rolloverReady,
            position.readyAt,
            position.layerShareBps,
            position.retainedShareBps
        );
    }

    function _computeEffectiveTeachingShareBps(
        uint16 snapshotActiveLayer,
        uint64 snapshotAt,
        uint64 activatedAt,
        uint16 layerIndex,
        bool rolloverReady,
        uint64 readyAt,
        uint16 layerShareBps,
        uint16 retainedShareBps
    ) internal pure returns (uint16) {
        if (
            snapshotActiveLayer == 0 || activatedAt == 0 || activatedAt > snapshotAt
                || layerIndex > snapshotActiveLayer
        ) {
            return 0;
        }
        if (rolloverReady && readyAt != 0 && readyAt <= snapshotAt) {
            return retainedShareBps;
        }
        return layerShareBps;
    }

    function _computeWeightedAmount(uint256 baseAmount, uint16 weightBps)
        internal
        pure
        returns (uint256)
    {
        return (baseAmount * weightBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
    }
}
