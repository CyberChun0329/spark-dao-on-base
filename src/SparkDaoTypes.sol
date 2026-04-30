// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library SparkDaoTypes {
    uint16 internal constant BASIS_POINTS_DENOMINATOR = 10_000;
    uint256 internal constant MAX_TITLE_LEN = 64;
    uint256 internal constant MAX_URI_LEN = 200;
    uint256 internal constant MAX_COURSE_TYPE_NAME_LEN = 48;
    uint256 internal constant MAX_TEACHING_RESEARCH_LINKS = 8;
    uint16 internal constant MAX_TEACHING_RESEARCH_SHARE_BPS = 2_500;
    uint64 internal constant DAY_SECONDS = 86_400;
    uint64 internal constant YEAR_SECONDS = 365 * DAY_SECONDS;
    uint64 internal constant DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS = YEAR_SECONDS;
    uint16 internal constant DEFAULT_RESEARCH_DECAY_RATE_BPS = 5_000;
    uint64 internal constant TEACHING_SECOND_ROUND_TIMEOUT_SECONDS = 30 * DAY_SECONDS;
    uint64 internal constant TEACHING_REDEEM_DELAY_SECONDS = 30 * DAY_SECONDS;
    uint256 internal constant MAX_TEACHING_REWARD_BUCKETS = 128;

    struct DaoState {
        address authority;
        uint64 nextAssetId;
        uint64 rewardUnlockSeconds;
        address coordinator;
        uint64 buybackWaitSeconds;
        uint64 nextCourseTypeId;
        address stableAsset;
        uint64 nextTeachingNftId;
        uint256 vaultReservedUnits;
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
        bool exists;
        bool currentLayerSealed;
        bool preparedNextLayerSealed;
        string title;
        string metadataUri;
    }

    struct ResearchPosition {
        address beneficiary;
        address currentHolder;
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
        uint256 listPriceUnits;
        uint256 teacherSalaryUnits;
        uint64 courseTypeId;
        uint16 researchShareBps;
        bool exists;
        string name;
    }

    struct TeachingSession {
        address teacher;
        address customer;
        uint256 listPriceUnits;
        uint256 teacherSalaryUnits;
        uint256 faultCustomerChargeUnits;
        uint256 faultCustomerRefundUnits;
        uint256 faultTeacherPayoutUnits;
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
        uint16 customerDiscountBps;
        uint16 researchShareBps;
        uint8 status;
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

    struct TeachingRewardBucket {
        uint64 unlockAt;
        uint256 amount;
    }

    struct TeachingRewardLedger {
        uint256 unlockedUnits;
        TeachingRewardBucket[] pendingBuckets;
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
