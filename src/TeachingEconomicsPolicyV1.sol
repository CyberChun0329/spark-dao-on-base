// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingEconomicsPolicy } from "./interfaces/ITeachingEconomicsPolicy.sol";

contract TeachingEconomicsPolicyV1 is ITeachingEconomicsPolicy {
    uint8 public constant TEACHING_ECONOMICS_POLICY_VERSION = 1;

    function quoteCourseType(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external pure returns (SparkDaoTypes.TeachingEconomicsQuote memory) {
        return _quote(listPriceUnits, teacherSalaryUnits, researchShareBps);
    }

    function quoteSession(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps,
        uint16 customerDiscountBps
    ) external pure returns (SparkDaoTypes.TeachingEconomicsQuote memory) {
        if (
            customerDiscountBps == 0 || customerDiscountBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        ) {
            revert SparkDaoErrors.InvalidDiscountBps();
        }

        uint256 lessonPriceUnits =
            (listPriceUnits * customerDiscountBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        return _quote(lessonPriceUnits, teacherSalaryUnits, researchShareBps);
    }

    function _quote(uint256 lessonPriceUnits, uint256 teacherSalaryUnits, uint16 researchShareBps)
        internal
        pure
        returns (SparkDaoTypes.TeachingEconomicsQuote memory quote)
    {
        if (lessonPriceUnits == 0 || teacherSalaryUnits == 0) {
            revert SparkDaoErrors.InvalidAmount();
        }
        if (researchShareBps > SparkDaoTypes.MAX_TEACHING_RESEARCH_SHARE_BPS) {
            revert SparkDaoErrors.InvalidResearchShareBps();
        }

        uint256 researchRewardUnits =
            (lessonPriceUnits * researchShareBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        uint256 allocatedUnits = teacherSalaryUnits + researchRewardUnits;
        if (allocatedUnits > lessonPriceUnits) {
            revert SparkDaoErrors.InvalidAmount();
        }

        quote = SparkDaoTypes.TeachingEconomicsQuote({
            lessonPriceUnits: lessonPriceUnits,
            teacherSalaryUnits: teacherSalaryUnits,
            teacherBondUnits: teacherSalaryUnits * 2,
            researchRewardUnits: researchRewardUnits,
            teacherFaultResearchRewardUnits: researchRewardUnits * 2,
            serviceReserveUnits: lessonPriceUnits - allocatedUnits
        });
    }
}
