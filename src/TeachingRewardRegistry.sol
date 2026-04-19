// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ResearchRegistry} from "./ResearchRegistry.sol";
import {SparkDaoErrors} from "./SparkDaoErrors.sol";
import {SparkDaoTypes} from "./SparkDaoTypes.sol";
import {IERC20} from "./interfaces/IERC20.sol";

abstract contract TeachingRewardRegistry is ResearchRegistry {
    struct TeachingRewardContext {
        uint64 teachingNftId;
        uint64 assetId;
        uint16 snapshotActiveLayer;
        uint64 snapshotAt;
        uint256 assetPoolUnits;
        uint64 exactUnlockAt;
    }

    mapping(uint64 assetId => mapping(uint64 positionId => SparkDaoTypes.TeachingRewardLedger))
        internal teachingRewardLedgers;

    event TeachingRewardAccrued(
        uint64 indexed teachingNftId,
        uint64 indexed assetId,
        uint64 indexed positionId,
        uint256 amount,
        uint64 unlockAt
    );
    event TeachingRewardClaimed(
        uint64 indexed assetId,
        uint64 indexed positionId,
        address indexed holder,
        uint256 amount
    );

    constructor(
        address authority_,
        address coordinator_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_,
        address researchPositionToken_
    )
        ResearchRegistry(
            authority_,
            coordinator_,
            stableAsset_,
            rewardUnlockSeconds_,
            buybackWaitSeconds_,
            researchPositionToken_
        )
    {}

    function getTeachingRewardLedgerBuckets(uint64 assetId, uint64 positionId)
        external
        view
        returns (uint64[] memory unlockAts, uint256[] memory amounts)
    {
        SparkDaoTypes.TeachingRewardLedger storage ledger = teachingRewardLedgers[assetId][positionId];
        if (ledger.unlockedUnits == 0 && ledger.pendingBuckets.length == 0) {
            revert SparkDaoErrors.InvalidTeachingRewardLedger();
        }

        uint256 bucketCount = ledger.pendingBuckets.length;
        unlockAts = new uint64[](bucketCount);
        amounts = new uint256[](bucketCount);
        for (uint256 i = 0; i < bucketCount;) {
            unlockAts[i] = ledger.pendingBuckets[i].unlockAt;
            amounts[i] = ledger.pendingBuckets[i].amount;
            unchecked {
                ++i;
            }
        }
    }

    function claimTeachingReward(uint64 assetId, uint64 positionId) public {
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);
        if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();

        SparkDaoTypes.TeachingRewardLedger storage ledger = _requireTeachingRewardLedger(assetId, positionId);
        _compactMaturedTeachingRewards(ledger, uint64(block.timestamp));

        uint256 claimAmount = ledger.unlockedUnits;
        if (claimAmount == 0) revert SparkDaoErrors.RevenueStillLocked();

        ledger.unlockedUnits = 0;
        position.totalClaimedUnits += claimAmount;
        daoState.vaultReservedUnits -= claimAmount;

        if (ledger.pendingBuckets.length == 0) {
            delete teachingRewardLedgers[assetId][positionId];
        }

        if (!IERC20(daoState.stableAsset).transfer(msg.sender, claimAmount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }

        emit TeachingRewardClaimed(assetId, positionId, msg.sender, claimAmount);
    }

    function claimTeachingRewardBatch(uint64[] calldata assetIds, uint64[] calldata positionIds)
        external
    {
        if (assetIds.length == 0 || assetIds.length != positionIds.length) {
            revert SparkDaoErrors.InvalidAmount();
        }

        uint256 totalAmount = 0;
        uint64 nowTs = uint64(block.timestamp);
        uint256 claimCount = assetIds.length;
        for (uint256 i = 0; i < claimCount;) {
            uint64 assetId = assetIds[i];
            uint64 positionId = positionIds[i];

            SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);
            if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();

            SparkDaoTypes.TeachingRewardLedger storage ledger =
                _requireTeachingRewardLedger(assetId, positionId);
            _compactMaturedTeachingRewards(ledger, nowTs);

            uint256 claimAmount = ledger.unlockedUnits;
            if (claimAmount == 0) revert SparkDaoErrors.RevenueStillLocked();

            ledger.unlockedUnits = 0;
            position.totalClaimedUnits += claimAmount;
            totalAmount += claimAmount;

            emit TeachingRewardClaimed(assetId, positionId, msg.sender, claimAmount);

            if (ledger.pendingBuckets.length == 0) {
                delete teachingRewardLedgers[assetId][positionId];
            }
            unchecked {
                ++i;
            }
        }

        daoState.vaultReservedUnits -= totalAmount;
        if (!IERC20(daoState.stableAsset).transfer(msg.sender, totalAmount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }
    }

    function _autoRecordTeachingRewardsForSettlement(SparkDaoTypes.TeachingSession storage session)
        internal
        returns (uint256 distributedUnits)
    {
        if (!_requiresResearchDistribution(session)) {
            _clearSettlementResearchLayers(session);
            return 0;
        }

        uint64 snapshotAt = session.scheduledAt;
        uint64 exactUnlockAt = uint64(block.timestamp) + daoState.rewardUnlockSeconds;
        uint256 researchPoolUnits = _researchPoolUnits(session);
        uint256 linkCount = session.linkedResearchLinks.length;

        _clearSettlementResearchLayers(session);
        for (uint256 assetIndex = 0; assetIndex < linkCount;) {
            (uint64 assetId, uint16 assetWeightBps) =
                _unpackResearchLink(session.linkedResearchLinks[assetIndex]);
            (uint16 snapshotActiveLayer, uint256 assetDistributedUnits) =
                _recordTeachingRewardsForAsset(
                    session,
                    assetId,
                    assetWeightBps,
                    researchPoolUnits,
                    snapshotAt,
                    exactUnlockAt
                );
            _pushSettlementResearchLayer(session, snapshotActiveLayer);
            distributedUnits += assetDistributedUnits;
            unchecked {
                ++assetIndex;
            }
        }
    }

    function _recordTeachingRewardsForAsset(
        SparkDaoTypes.TeachingSession storage session,
        uint64 assetId,
        uint16 assetWeightBps,
        uint256 researchPoolUnits,
        uint64 snapshotAt,
        uint64 exactUnlockAt
    ) internal returns (uint16 snapshotActiveLayer, uint256 distributedUnits) {
        _requireAsset(assetId);
        snapshotActiveLayer = _snapshotActiveLayer(assetId, snapshotAt);

        uint256 assetPoolUnits = _computeWeightedAmount(researchPoolUnits, assetWeightBps);
        if (assetPoolUnits == 0 || snapshotActiveLayer == 0) {
            return (snapshotActiveLayer, 0);
        }

        TeachingRewardContext memory rewardContext = TeachingRewardContext({
            teachingNftId: session.teachingNftId,
            assetId: assetId,
            snapshotActiveLayer: snapshotActiveLayer,
            snapshotAt: snapshotAt,
            assetPoolUnits: assetPoolUnits,
            exactUnlockAt: exactUnlockAt
        });

        uint64[] storage positionIds = researchAssetPositionIds[assetId];
        uint256 positionCount = positionIds.length;
        for (uint256 positionIndex = 0; positionIndex < positionCount;) {
            uint64 positionId = positionIds[positionIndex];
            SparkDaoTypes.ResearchPosition storage position = researchPositions[assetId][positionId];
            if (!position.exists) {
                unchecked {
                    ++positionIndex;
                }
                continue;
            }
            distributedUnits += _recordTeachingRewardForPosition(rewardContext, positionId, position);
            unchecked {
                ++positionIndex;
            }
        }
    }

    function _recordTeachingRewardForPosition(
        TeachingRewardContext memory rewardContext,
        uint64 positionId,
        SparkDaoTypes.ResearchPosition storage position
    ) internal returns (uint256 distributedUnits) {
        uint16 effectiveShareBps = _computeEffectiveTeachingShareBps(
            rewardContext.snapshotActiveLayer,
            rewardContext.snapshotAt,
            position.activatedAt,
            position.layerIndex,
            position.rolloverReady,
            position.readyAt,
            position.layerShareBps,
            position.retainedShareBps
        );

        if (effectiveShareBps == 0) {
            return 0;
        }

        uint256 amount = _computeWeightedAmount(rewardContext.assetPoolUnits, effectiveShareBps);
        if (amount == 0) {
            return 0;
        }

        _upsertTeachingRewardLedger(
            rewardContext.teachingNftId,
            rewardContext.assetId,
            positionId,
            rewardContext.exactUnlockAt,
            amount
        );
        return amount;
    }

    function _requireTeachingRewardLedger(uint64 assetId, uint64 positionId)
        internal
        view
        returns (SparkDaoTypes.TeachingRewardLedger storage ledger)
    {
        ledger = teachingRewardLedgers[assetId][positionId];
        if (ledger.unlockedUnits == 0 && ledger.pendingBuckets.length == 0) {
            revert SparkDaoErrors.InvalidTeachingRewardLedger();
        }
    }

    function _upsertTeachingRewardLedger(
        uint64 teachingNftId,
        uint64 assetId,
        uint64 positionId,
        uint64 exactUnlockAt,
        uint256 amount
    ) internal {
        SparkDaoTypes.TeachingRewardLedger storage ledger = teachingRewardLedgers[assetId][positionId];
        _compactMaturedTeachingRewards(ledger, uint64(block.timestamp));

        uint64 bucketUnlockAt =
            _normalizeTeachingUnlockBucket(exactUnlockAt, daoState.rewardUnlockSeconds);
        bool merged = false;
        uint256 pendingLength = ledger.pendingBuckets.length;
        for (uint256 i = 0; i < pendingLength;) {
            if (ledger.pendingBuckets[i].unlockAt == bucketUnlockAt) {
                ledger.pendingBuckets[i].amount += amount;
                merged = true;
                break;
            }
            unchecked {
                ++i;
            }
        }

        if (!merged) {
            if (pendingLength >= SparkDaoTypes.MAX_TEACHING_REWARD_BUCKETS) {
                revert SparkDaoErrors.TeachingRewardLedgerFull();
            }
            ledger.pendingBuckets.push(
                SparkDaoTypes.TeachingRewardBucket({unlockAt: bucketUnlockAt, amount: amount})
            );
        }

        emit TeachingRewardAccrued(teachingNftId, assetId, positionId, amount, bucketUnlockAt);
    }

    function _compactMaturedTeachingRewards(
        SparkDaoTypes.TeachingRewardLedger storage ledger,
        uint64 nowTs
    ) internal {
        uint256 pendingLength = ledger.pendingBuckets.length;
        if (pendingLength == 0) return;

        uint256 newlyUnlocked = 0;
        uint256 writeIndex = 0;
        for (uint256 i = 0; i < pendingLength;) {
            SparkDaoTypes.TeachingRewardBucket storage bucket = ledger.pendingBuckets[i];
            if (nowTs >= bucket.unlockAt) {
                newlyUnlocked += bucket.amount;
            } else {
                if (writeIndex != i) {
                    ledger.pendingBuckets[writeIndex] = bucket;
                }
                unchecked {
                    ++writeIndex;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (newlyUnlocked > 0) {
            ledger.unlockedUnits += newlyUnlocked;
        }
        if (writeIndex == pendingLength) return;
        while (ledger.pendingBuckets.length > writeIndex) {
            ledger.pendingBuckets.pop();
        }
    }

    function _unpackResearchLink(uint80 packedLink)
        internal
        pure
        returns (uint64 assetId, uint16 weightBps)
    {
        // forge-lint: disable-next-line(unsafe-typecast)
        assetId = uint64(packedLink);
        // forge-lint: disable-next-line(unsafe-typecast)
        weightBps = uint16(packedLink >> 64);
    }

    function _clearSettlementResearchLayers(SparkDaoTypes.TeachingSession storage session) internal {
        session.settlementResearchActiveLayersPacked = 0;
        session.settlementResearchLayerCount = 0;
    }

    function _pushSettlementResearchLayer(
        SparkDaoTypes.TeachingSession storage session,
        uint16 snapshotActiveLayer
    ) internal {
        uint256 index = session.settlementResearchLayerCount;
        session.settlementResearchActiveLayersPacked |= uint256(snapshotActiveLayer) << (index * 16);
        session.settlementResearchLayerCount += 1;
    }

    function _snapshotActiveLayer(uint64 assetId, uint64 snapshotAt) internal view returns (uint16) {
        uint64[] storage positionIds = researchAssetPositionIds[assetId];
        uint16 activeLayer = 0;
        uint256 positionCount = positionIds.length;
        for (uint256 i = 0; i < positionCount;) {
            SparkDaoTypes.ResearchPosition storage position = researchPositions[assetId][positionIds[i]];
            if (position.exists && position.isActivated && position.activatedAt <= snapshotAt) {
                if (position.layerIndex > activeLayer) {
                    activeLayer = position.layerIndex;
                }
            }
            unchecked {
                ++i;
            }
        }

        return activeLayer;
    }

    function _normalizeTeachingUnlockBucket(uint64 exactUnlockAt, uint64 rewardUnlockSeconds)
        internal
        pure
        returns (uint64)
    {
        if (rewardUnlockSeconds == 0) {
            return exactUnlockAt;
        }
        uint64 daySeconds = SparkDaoTypes.DAY_SECONDS;
        // Bucket unlock times by day so repeated rewards can share one claim slot.
        // forge-lint: disable-next-line(divide-before-multiply)
        return ((exactUnlockAt + daySeconds - 1) / daySeconds) * daySeconds;
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

    function _requiresResearchDistribution(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        virtual
        returns (bool);

    function _researchPoolUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        virtual
        returns (uint256);
}
