// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkTeachingTypes } from "./SparkTeachingTypes.sol";
import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingRewardSource } from "./interfaces/ITeachingRewardSource.sol";
import { IResearchRegistryForTeaching } from "./interfaces/IResearchRegistryForTeaching.sol";

contract TeachingRewardDistributor {
    address public immutable TEACHING_REGISTRY;
    address public immutable RESEARCH_REGISTRY;

    struct TeachingRewardPosition {
        address currentHolder;
        uint64 activatedAt;
        uint64 readyAt;
        uint16 layerIndex;
        uint16 layerShareBps;
        uint16 retainedShareBps;
        bool rolloverReady;
    }

    mapping(
        uint64 teachingNftId => mapping(uint64 assetId => SparkTeachingTypes.TeachingRewardPool)
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

    constructor(address teachingRegistry_, address researchRegistry_) {
        if (teachingRegistry_ == address(0) || researchRegistry_ == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }
        TEACHING_REGISTRY = teachingRegistry_;
        RESEARCH_REGISTRY = researchRegistry_;
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
        SparkTeachingTypes.TeachingRewardPool storage pool =
            teachingRewardPools[teachingNftId][assetId];
        if (pool.exists) revert SparkDaoErrors.InvalidTeachingRewardPool();

        pool.exists = true;
        pool.stableAsset = stableAsset;
        pool.assetPoolUnits = _toUint128(assetPoolUnits);
        pool.distributedUnits = _toUint128(distributedUnits);
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
        SparkTeachingTypes.TeachingRewardPool storage pool =
            _requireTeachingRewardPool(teachingNftId, assetId);
        TeachingRewardPosition memory position = _loadTeachingRewardPosition(assetId, positionId);
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
        uint256 claimCount = teachingNftIds.length;
        if (claimCount == 0 || claimCount != assetIds.length || claimCount != positionIds.length) {
            revert SparkDaoErrors.InvalidAmount();
        }

        for (uint256 i = 0; i < claimCount;) {
            _claimTeachingReward(msg.sender, teachingNftIds[i], assetIds[i], positionIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _claimTeachingReward(
        address claimant,
        uint64 teachingNftId,
        uint64 assetId,
        uint64 positionId
    ) internal {
        TeachingRewardPosition memory position = _loadTeachingRewardPosition(assetId, positionId);
        if (position.currentHolder != claimant) revert SparkDaoErrors.UnauthorizedHolder();

        SparkTeachingTypes.TeachingRewardPool storage pool =
            _requireTeachingRewardPool(teachingNftId, assetId);
        if (block.timestamp < pool.unlockAt) revert SparkDaoErrors.RevenueStillLocked();
        mapping(uint64 => bool) storage claimedByPosition =
            teachingRewardClaimed[teachingNftId][assetId];
        if (claimedByPosition[positionId]) {
            revert SparkDaoErrors.TeachingRewardAlreadyClaimed();
        }

        uint16 effectiveShareBps = _effectiveClaimShareBps(pool, position);
        if (effectiveShareBps == 0) revert SparkDaoErrors.InvalidTeachingRewardPool();

        uint256 claimAmount = _computeWeightedAmount(pool.assetPoolUnits, effectiveShareBps);
        uint256 remainingUnits = uint256(pool.distributedUnits) - pool.claimedUnits;
        if (claimAmount > remainingUnits) claimAmount = remainingUnits;

        claimedByPosition[positionId] = true;
        pool.claimedShareBps += effectiveShareBps;
        if (claimAmount != 0) {
            pool.claimedUnits = _toUint128(uint256(pool.claimedUnits) + claimAmount);
        }

        uint256 dustUnits = _releaseTeachingRewardDustIfComplete(pool);
        ITeachingRewardSource(TEACHING_REGISTRY)
            .settleTeachingRewardClaim(
                pool.stableAsset, claimant, assetId, positionId, claimAmount, dustUnits
            );

        emit TeachingRewardClaimed(teachingNftId, assetId, positionId, claimant, claimAmount);
    }

    function _loadTeachingRewardPosition(uint64 assetId, uint64 positionId)
        internal
        view
        returns (TeachingRewardPosition memory position)
    {
        (
            position.currentHolder,
            position.activatedAt,
            position.readyAt,
            position.layerIndex,
            position.layerShareBps,
            position.retainedShareBps,
            position.rolloverReady
        ) =
            IResearchRegistryForTeaching(RESEARCH_REGISTRY)
                .getTeachingRewardPosition(assetId, positionId);
    }

    function _onlyTeachingRegistry() internal view {
        if (msg.sender != TEACHING_REGISTRY) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
    }

    function _requireTeachingRewardPool(uint64 teachingNftId, uint64 assetId)
        internal
        view
        returns (SparkTeachingTypes.TeachingRewardPool storage pool)
    {
        pool = teachingRewardPools[teachingNftId][assetId];
        if (!pool.exists) revert SparkDaoErrors.InvalidTeachingRewardPool();
    }

    function _releaseTeachingRewardDustIfComplete(
        SparkTeachingTypes.TeachingRewardPool storage pool
    ) internal returns (uint256 dustUnits) {
        if (pool.dustReleased) return 0;
        if (pool.claimedShareBps < pool.totalEffectiveShareBps) return 0;

        uint256 claimedUnits = pool.claimedUnits;
        uint256 distributedUnits = pool.distributedUnits;
        if (claimedUnits >= distributedUnits) return 0;

        dustUnits = distributedUnits - claimedUnits;
        pool.claimedUnits = _toUint128(distributedUnits);
        pool.dustReleased = true;
    }

    function _effectiveClaimShareBps(
        SparkTeachingTypes.TeachingRewardPool storage pool,
        TeachingRewardPosition memory position
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

    function _toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) revert SparkDaoErrors.InvalidAmount();
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint128(value);
    }
}
