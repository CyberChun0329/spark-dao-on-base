// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingFaultPolicy } from "./interfaces/ITeachingFaultPolicy.sol";

/// @notice V1 stateless fault-settlement quote module.
/// @dev The registry stores the returned fault quotes; this module reads no registry
/// state and performs no reserve, claim, or treasury accounting.
contract TeachingFaultPolicyV1 is ITeachingFaultPolicy {
    uint8 public constant FAULT_POLICY_VERSION = 1;

    function quoteCustomerFault(uint256 lessonPriceUnits, uint256 teacherSalaryUnits)
        external
        pure
        returns (SparkDaoTypes.TeachingFaultQuote memory quote)
    {
        uint256 customerChargeUnits = lessonPriceUnits / 2;
        uint256 teacherImmediatePayoutUnits = teacherSalaryUnits / 2;
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
