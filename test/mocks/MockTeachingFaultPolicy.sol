// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "../../src/SparkDaoErrors.sol";
import { SparkDaoTypes } from "../../src/SparkDaoTypes.sol";
import { ITeachingFaultPolicy } from "../../src/interfaces/ITeachingFaultPolicy.sol";

contract MockTeachingFaultPolicy is ITeachingFaultPolicy {
    uint8 public immutable FAULT_POLICY_VERSION;
    uint8 internal immutable MODE;

    constructor(uint8 version_, uint8 mode_) {
        FAULT_POLICY_VERSION = version_;
        MODE = mode_;
    }

    function quoteCustomerFault(uint256 lessonPriceUnits, uint256)
        external
        view
        returns (SparkDaoTypes.TeachingFaultQuote memory quote)
    {
        if (MODE == 4) revert SparkDaoErrors.FaultSettlementInsolvent();

        uint256 customerChargeUnits = lessonPriceUnits / 2;
        uint256 customerRefundUnits = lessonPriceUnits - customerChargeUnits;
        uint256 serviceReserveUnits = customerChargeUnits;
        if (MODE == 1) serviceReserveUnits += 1;

        quote = SparkDaoTypes.TeachingFaultQuote({
            customerChargeUnits: customerChargeUnits,
            customerRefundUnits: customerRefundUnits,
            teacherImmediatePayoutUnits: 0,
            remedialTeacherPayoutUnits: 0,
            researchRewardUnits: 0,
            serviceReserveUnits: serviceReserveUnits,
            remedialLessonCount: 0
        });
    }

    function quoteTeacherFault(
        uint256 lessonPriceUnits,
        uint256,
        uint256 requestedResearchRewardUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        if (MODE == 4) revert SparkDaoErrors.FaultSettlementInsolvent();

        uint256 customerChargeUnits = lessonPriceUnits / 2;
        uint256 researchRewardUnits = requestedResearchRewardUnits;
        uint8 remedialLessonCount = MODE == 3 ? 2 : 1;
        if (MODE == 2) researchRewardUnits = requestedResearchRewardUnits + 1;
        uint256 serviceReserveUnits = customerChargeUnits > researchRewardUnits
            ? customerChargeUnits - researchRewardUnits
            : 0;
        if (MODE == 1) serviceReserveUnits += 1;

        quote = SparkDaoTypes.TeachingFaultQuote({
            customerChargeUnits: customerChargeUnits,
            customerRefundUnits: lessonPriceUnits - customerChargeUnits,
            teacherImmediatePayoutUnits: 0,
            remedialTeacherPayoutUnits: 0,
            researchRewardUnits: researchRewardUnits,
            serviceReserveUnits: serviceReserveUnits,
            remedialLessonCount: remedialLessonCount
        });
    }
}

contract MutableTeachingFaultPolicy is ITeachingFaultPolicy {
    uint8 public constant FAULT_POLICY_VERSION = 2;

    uint256 public customerFaultTeacherPayoutDivisor = 2;

    function setCustomerFaultTeacherPayoutDivisor(uint256 divisor) external {
        customerFaultTeacherPayoutDivisor = divisor;
    }

    function quoteCustomerFault(uint256 lessonPriceUnits, uint256 teacherSalaryUnits)
        external
        view
        returns (SparkDaoTypes.TeachingFaultQuote memory quote)
    {
        uint256 customerChargeUnits = lessonPriceUnits / 2;
        uint256 teacherImmediatePayoutUnits = teacherSalaryUnits / customerFaultTeacherPayoutDivisor;
        if (teacherImmediatePayoutUnits > customerChargeUnits) {
            revert SparkDaoErrors.FaultSettlementInsolvent();
        }

        quote = SparkDaoTypes.TeachingFaultQuote({
            customerChargeUnits: customerChargeUnits,
            customerRefundUnits: lessonPriceUnits - customerChargeUnits,
            teacherImmediatePayoutUnits: teacherImmediatePayoutUnits,
            remedialTeacherPayoutUnits: 0,
            researchRewardUnits: 0,
            serviceReserveUnits: customerChargeUnits - teacherImmediatePayoutUnits,
            remedialLessonCount: 0
        });
    }

    function quoteTeacherFault(
        uint256 lessonPriceUnits,
        uint256 teacherSalaryUnits,
        uint256 requestedResearchRewardUnits
    ) external pure returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        uint256 customerChargeUnits = lessonPriceUnits / 2;
        uint256 remedialTeacherPayoutUnits = teacherSalaryUnits / 2;
        uint256 allocatedUnits = remedialTeacherPayoutUnits + requestedResearchRewardUnits;
        if (allocatedUnits > customerChargeUnits) {
            revert SparkDaoErrors.FaultSettlementInsolvent();
        }

        quote = SparkDaoTypes.TeachingFaultQuote({
            customerChargeUnits: customerChargeUnits,
            customerRefundUnits: lessonPriceUnits - customerChargeUnits,
            teacherImmediatePayoutUnits: 0,
            remedialTeacherPayoutUnits: remedialTeacherPayoutUnits,
            researchRewardUnits: requestedResearchRewardUnits,
            serviceReserveUnits: customerChargeUnits - allocatedUnits,
            remedialLessonCount: 1
        });
    }
}
