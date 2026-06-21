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
        uint64 nextCourseTypeId;
        address stableAsset;
        uint64 nextTeachingNftId;
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
        uint256 buybackFloor;
        uint256 totalClaimedUnits;
        uint256 boughtBackPrice;
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
        uint256 amount;
        uint64 unlockAt;
        bool claimed;
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

    struct TeachingCourseType {
        address economicsPolicy;
        address faultPolicy;
        address stableAsset;
        uint256 listPriceUnits;
        uint256 teacherSalaryUnits;
        uint64 courseTypeId;
        uint16 researchShareBps;
        uint8 faultPolicyVersion;
        bool exists;
        string name;
    }

    struct TeachingSession {
        address faultPolicy;
        address teacher;
        address customer;
        address stableAsset;
        uint256 listPriceUnits;
        uint256 lessonPriceUnits;
        uint256 teacherSalaryUnits;
        uint256 teacherBondUnits;
        uint256 researchRewardUnits;
        uint256 teacherFaultResearchRewardUnits;
        uint256 serviceReserveUnits;
        uint256 faultCustomerChargeUnits;
        uint256 faultCustomerRefundUnits;
        uint256 faultTeacherPayoutUnits;
        uint256 faultRemedialTeacherPayoutUnits;
        uint256 faultResearchRewardUnits;
        uint256 faultServiceReserveUnits;
        uint256 settlementResearchActiveLayersPacked;
        uint64 teachingNftId;
        uint64 courseTypeId;
        uint64 scheduledAt;
        uint64 secondRoundDeadlineAt;
        uint64 redeemableAt;
        uint64 resolvedAt;
        uint64 teacherBondReleasedAt;
        uint64 redeemedAt;
        uint64 remedialWageSettledAt;
        uint16 customerDiscountBps;
        uint16 researchShareBps;
        uint8 status;
        uint8 faultPolicyVersion;
        uint8 remedialLessonCount;
        uint8 settlementResearchLayerCount;
        bool exists;
        bool teacherConfirmedSchedule;
        bool customerConfirmedSchedule;
        bool firstRoundFrozen;
        bool teacherBondLocked;
        bool customerPaymentLocked;
        bool collateralLocked;
        bool teacherConfirmedCompletion;
        bool customerConfirmedCompletion;
        uint80[] linkedResearchLinks;
    }

    struct TeachingFaultQuote {
        uint256 customerChargeUnits;
        uint256 customerRefundUnits;
        uint256 teacherImmediatePayoutUnits;
        uint256 remedialTeacherPayoutUnits;
        uint256 researchRewardUnits;
        uint256 serviceReserveUnits;
        uint8 remedialLessonCount;
    }

    struct FrozenTeachingFaultQuotes {
        TeachingFaultQuote customerFaultQuote;
        TeachingFaultQuote teacherFaultQuote;
    }

    struct TeachingEconomicsQuote {
        uint256 lessonPriceUnits;
        uint256 teacherSalaryUnits;
        uint256 teacherBondUnits;
        uint256 researchRewardUnits;
        uint256 teacherFaultResearchRewardUnits;
        uint256 serviceReserveUnits;
    }

    struct LayerCheckpoint {
        uint64 timestamp;
        uint16 activeLayer;
    }

    struct ShareCheckpoint {
        uint64 timestamp;
        uint16 effectiveShareBps;
    }

    struct TeachingRewardPool {
        address stableAsset;
        uint256 assetPoolUnits;
        uint256 distributedUnits;
        uint256 claimedUnits;
        uint64 snapshotAt;
        uint64 unlockAt;
        uint16 snapshotActiveLayer;
        uint16 totalEffectiveShareBps;
        uint16 claimedShareBps;
        bool exists;
        bool dustReleased;
    }

    struct CreateTeachingSessionParams {
        uint64 courseTypeId;
        address teacher;
        address customer;
        uint64 scheduledAt;
        uint16 customerDiscountBps;
        uint64[] linkedResearchAssetIds;
        uint16[] linkedResearchWeightBps;
    }
}
