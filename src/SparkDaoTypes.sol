// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library SparkDaoTypes {
    uint16 internal constant BASIS_POINTS_DENOMINATOR = 10_000;
    uint256 internal constant MAX_TITLE_LEN = 64;
    uint256 internal constant MAX_URI_LEN = 200;
    uint256 internal constant MAX_COURSE_TYPE_NAME_LEN = 48;
    uint256 internal constant MAX_TEACHING_RESEARCH_LINKS = 2;
    /// @dev Absolute research-share cap. Teacher-fault solvency may impose a lower
    /// course-specific cap based on the frozen teacher salary to lesson price ratio.
    uint16 internal constant MAX_TEACHING_RESEARCH_SHARE_BPS = 2_500;
    uint64 internal constant DAY_SECONDS = 86_400;
    uint64 internal constant YEAR_SECONDS = 365 * DAY_SECONDS;
    uint64 internal constant DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS = YEAR_SECONDS;
    uint16 internal constant DEFAULT_RESEARCH_DECAY_RATE_BPS = 5_000;
    uint64 internal constant TEACHING_SECOND_ROUND_TIMEOUT_SECONDS = 30 * DAY_SECONDS;
    uint64 internal constant TEACHING_REDEEM_DELAY_SECONDS = 30 * DAY_SECONDS;
    uint64 internal constant MIN_DECAY_PERIOD_SECONDS = DAY_SECONDS;
    uint64 internal constant MAX_DECAY_STEPS = 64;

    struct DaoState {
        address authority;
        address treasury;
        uint64 nextAssetId;
        uint64 rewardUnlockSeconds;
        address coordinator;
        uint64 buybackWaitSeconds;
        address stableAsset;
    }

    struct ResearchAsset {
        uint64 assetId;
        uint64 nextPositionId;
        uint64 createdAt;
        address createdBy;
        uint16 currentActiveLayer;
        uint16 currentLayerCapacityBps;
        uint16 currentLayerPositionCount;
        uint16 currentLayerReadyCount;
        uint16 currentLayerShareBpsTotal;
        uint16 currentLayerPreparableCapacityBps;
        uint16 nextLayerCapacityBps;
        uint16 preparedNextLayerPositionCount;
        uint16 preparedNextLayerShareBpsTotal;
        uint16 preparedNextLayerPreparableCapacityBps;
        uint16 teachingEffectiveShareBps;
        bool exists;
        bool currentLayerSealed;
        bool preparedNextLayerSealed;
        string title;
        string metadataUri;
    }

    struct ResearchPosition {
        address beneficiary;
        address currentHolder;
        address stableAsset;
        uint128 buybackFloor;
        uint128 totalClaimedUnits;
        uint128 boughtBackPrice;
        uint64 positionId;
        uint64 buybackWaitSeconds;
        uint64 buybackUnlockAt;
        uint64 decayWaitSeconds;
        uint64 decayStartAt;
        uint64 decayPeriodSeconds;
        uint64 activatedAt;
        uint64 readyAt;
        uint64 createdAt;
        uint64 nextRevenueId;
        uint64 boughtBackAt;
        uint16 layerIndex;
        uint16 layerShareBps;
        uint16 decayRateBps;
        uint16 retainedShareBps;
        uint16 releasedShareBps;
        bool exists;
        bool rolloverReady;
        bool isActivated;
        bool boughtBack;
    }

    struct RevenueEscrow {
        address stableAsset;
        uint64 unlockAt;
        bool claimed;
        uint128 amount;
    }

    struct CreatePatchPositionParams {
        uint64 assetId;
        uint16 layerIndex;
        uint16 layerShareBps;
        uint256 buybackFloor;
        uint64 decayWaitSeconds;
        uint64 decayPeriodSeconds;
        uint16 decayRateBps;
        address beneficiary;
    }

    struct LayerCheckpoint {
        uint64 timestamp;
        uint16 activeLayer;
    }

    struct ShareCheckpoint {
        uint64 timestamp;
        uint16 effectiveShareBps;
    }
}
