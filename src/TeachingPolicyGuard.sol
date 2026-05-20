// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingEconomicsPolicy } from "./interfaces/ITeachingEconomicsPolicy.sol";
import { ITeachingEconomicsPolicyGuard } from "./interfaces/ITeachingEconomicsPolicyGuard.sol";
import { ITeachingFaultPolicy } from "./interfaces/ITeachingFaultPolicy.sol";
import { ITeachingFaultPolicyGuard } from "./interfaces/ITeachingFaultPolicyGuard.sol";

contract TeachingPolicyGuard is ITeachingEconomicsPolicyGuard, ITeachingFaultPolicyGuard {
    function validatePolicy(address policy) public view returns (uint8 version) {
        if (policy.code.length == 0) revert SparkDaoErrors.InvalidTeachingFaultPolicy();
        version = ITeachingFaultPolicy(policy).FAULT_POLICY_VERSION();
        if (version == 0) revert SparkDaoErrors.InvalidTeachingFaultPolicy();
    }

    function validateEconomicsPolicy(address policy) public view returns (uint8 version) {
        if (policy.code.length == 0) revert SparkDaoErrors.InvalidTeachingEconomicsPolicy();
        version = ITeachingEconomicsPolicy(policy).TEACHING_ECONOMICS_POLICY_VERSION();
        if (version == 0) revert SparkDaoErrors.InvalidTeachingEconomicsPolicy();
    }

    function quoteCourseType(
        address policy,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote) {
        quote = ITeachingEconomicsPolicy(policy)
            .quoteCourseType(listPriceUnits, teacherSalaryUnits, researchShareBps);
        _validateEconomicsQuote(quote);
    }

    function quoteSession(
        address policy,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps,
        uint16 customerDiscountBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote) {
        quote = ITeachingEconomicsPolicy(policy)
            .quoteSession(listPriceUnits, teacherSalaryUnits, researchShareBps, customerDiscountBps);
        _validateEconomicsQuote(quote);
    }

    function quoteCustomerFault(
        address policy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        quote = ITeachingFaultPolicy(policy)
            .quoteCustomerFault(customerPaymentUnits, teacherSalaryUnits);
        _validateFaultQuote(customerPaymentUnits, 0, quote, false);
    }

    function quoteTeacherFault(
        address policy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits,
        uint256 requestedResearchRewardUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        quote = ITeachingFaultPolicy(policy)
            .quoteTeacherFault(
                customerPaymentUnits, teacherSalaryUnits, requestedResearchRewardUnits
            );
        _validateFaultQuote(customerPaymentUnits, requestedResearchRewardUnits, quote, true);
    }

    function _validateEconomicsQuote(SparkDaoTypes.TeachingEconomicsQuote memory quote)
        internal
        pure
    {
        if (
            quote.lessonPriceUnits == 0 || quote.teacherSalaryUnits == 0
                || quote.teacherBondUnits == 0
        ) {
            revert SparkDaoErrors.InvalidTeachingEconomicsPolicyQuote();
        }

        uint256 allocatedUnits = quote.teacherSalaryUnits + quote.researchRewardUnits;
        if (
            allocatedUnits > quote.lessonPriceUnits
                || quote.serviceReserveUnits != quote.lessonPriceUnits - allocatedUnits
        ) {
            revert SparkDaoErrors.InvalidTeachingEconomicsPolicyQuote();
        }
    }

    function _validateFaultQuote(
        uint256 customerPaymentUnits,
        uint256 requestedResearchRewardUnits,
        SparkDaoTypes.TeachingFaultQuote memory quote,
        bool teacherFault
    ) internal pure {
        if (
            quote.customerChargeUnits + quote.customerRefundUnits != customerPaymentUnits
                || quote.researchRewardUnits > requestedResearchRewardUnits
                || quote.remedialLessonCount > 1
                || quote.teacherImmediatePayoutUnits + quote.remedialTeacherPayoutUnits
                        + quote.researchRewardUnits + quote.serviceReserveUnits
                    != quote.customerChargeUnits
                || (!teacherFault && quote.remedialTeacherPayoutUnits != 0)
                || (!teacherFault && quote.remedialLessonCount != 0)
                || (teacherFault && quote.teacherImmediatePayoutUnits != 0)
        ) {
            revert SparkDaoErrors.InvalidTeachingFaultPolicyQuote();
        }
    }
}
