// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library SparkTeachingTypes {
    uint16 internal constant MAX_CLASS_SIZE = 100;
    /// @dev One uint16 active-layer snapshot is packed per linked research asset.
    uint16 internal constant PACKED_SETTLEMENT_RESEARCH_LAYER_CAPACITY = 2;

    struct TeachingCourseType {
        address pricingPolicy;
        address stableAsset;
        uint128 baseSeatPriceUnits;
        uint128 baseTeacherSalaryUnits;
        uint64 courseTypeId;
        uint16 researchShareBps;
        bool exists;
        string name;
    }

    struct TeachingQuote {
        uint256 seatPriceUnits;
        uint256 classTeacherSalaryUnits;
        uint256 seatTeacherSalaryUnits;
        uint256 teacherBondUnits;
        uint256 seatResearchRewardUnits;
        uint256 seatTeacherFaultResearchRewardUnits;
        uint256 seatServiceReserveUnits;
        uint16 classSize;
    }

    struct TeachingSeat {
        address student;
        bool paid;
        bool attendanceConfirmed;
        bool customerFault;
        bool refundClaimed;
        // Retained for storage-layout compatibility; settled refunds are derived lazily.
        uint128 refundOwedUnits;
    }

    struct TeachingSession {
        address pricingPolicy;
        address teacher;
        address stableAsset;
        uint128 seatPriceUnits;
        uint128 classTeacherSalaryUnits;
        uint128 seatTeacherSalaryUnits;
        uint128 teacherBondUnits;
        uint128 seatResearchRewardUnits;
        uint128 seatTeacherFaultResearchRewardUnits;
        uint128 seatServiceReserveUnits;
        uint128 teacherPayoutOwedUnits;
        uint128 remedialWageOwedUnits;
        uint128 refundOwedUnits;
        uint128 researchRewardUnits;
        uint128 serviceReserveUnits;
        uint64 teachingNftId;
        uint64 courseTypeId;
        uint64 scheduledAt;
        uint64 closedAt;
        uint64 teacherPayoutRedeemedAt;
        uint64 remedialWageSettledAt;
        uint16 classSize;
        uint16 researchShareBps;
        uint16 customerDiscountBps;
        uint16 paidSeatCount;
        uint16 paidAttendanceCount;
        uint8 status;
        uint8 settlementResearchLayerCount;
        uint32 settlementResearchActiveLayersPacked;
        bool exists;
        bool teacherBondLocked;
        bool teacherDeliveryConfirmed;
        bool teacherScheduleConfirmed;
        bool coordinatorScheduleConfirmed;
        uint80[] linkedResearchLinks;
        uint16[] customerFaultSeatIndexes;
        TeachingSeat[] seats;
    }

    struct CreateTeachingSessionParams {
        uint64 courseTypeId;
        address teacher;
        address[] students;
        uint64 scheduledAt;
        uint16 customerDiscountBps;
        uint64[] linkedResearchAssetIds;
        uint16[] linkedResearchWeightBps;
    }

    struct TeachingRewardPool {
        address stableAsset;
        uint64 snapshotAt;
        uint16 snapshotActiveLayer;
        bool exists;
        bool dustReleased;
        uint128 assetPoolUnits;
        uint64 unlockAt;
        uint16 totalEffectiveShareBps;
        uint16 claimedShareBps;
        uint128 distributedUnits;
        uint128 claimedUnits;
    }
}
