// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library SparkTeachingTypes {
    uint16 internal constant MAX_CLASS_SIZE = 100;

    struct TeachingCourseType {
        address pricingPolicy;
        address stableAsset;
        uint256 baseSeatPriceUnits;
        uint256 baseTeacherSalaryUnits;
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
        uint256 refundOwedUnits;
        bool paid;
        bool attendanceConfirmed;
        bool customerFault;
        bool refundClaimed;
    }

    struct TeachingSession {
        address pricingPolicy;
        address teacher;
        address stableAsset;
        uint256 seatPriceUnits;
        uint256 classTeacherSalaryUnits;
        uint256 seatTeacherSalaryUnits;
        uint256 teacherBondUnits;
        uint256 seatResearchRewardUnits;
        uint256 seatTeacherFaultResearchRewardUnits;
        uint256 seatServiceReserveUnits;
        uint256 teacherPayoutOwedUnits;
        uint256 remedialWageOwedUnits;
        uint256 refundOwedUnits;
        uint256 researchRewardUnits;
        uint256 serviceReserveUnits;
        uint256 settlementResearchActiveLayersPacked;
        uint64 teachingNftId;
        uint64 courseTypeId;
        uint64 scheduledAt;
        uint64 closedAt;
        uint64 teacherPayoutRedeemedAt;
        uint64 remedialWageSettledAt;
        uint16 classSize;
        uint16 researchShareBps;
        uint16 customerDiscountBps;
        uint8 status;
        uint8 settlementResearchLayerCount;
        bool exists;
        bool teacherBondLocked;
        bool teacherDeliveryConfirmed;
        bool teacherScheduleConfirmed;
        bool coordinatorScheduleConfirmed;
        uint80[] linkedResearchLinks;
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
}
