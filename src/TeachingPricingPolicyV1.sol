// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkTeachingTypes } from "./SparkTeachingTypes.sol";
import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";

contract TeachingPricingPolicyV1 {
    uint8 public constant TEACHING_PRICING_POLICY_VERSION = 1;

    function quoteTeachingSession(
        uint256 baseSeatPriceUnits,
        uint256 baseTeacherSalaryUnits,
        uint16 researchShareBps,
        uint16 classSize,
        uint16 customerDiscountBps
    ) external pure returns (SparkTeachingTypes.TeachingQuote memory quote) {
        if (
            classSize == 0 || classSize > SparkTeachingTypes.MAX_CLASS_SIZE
                || baseSeatPriceUnits == 0 || baseTeacherSalaryUnits == 0
        ) {
            revert SparkDaoErrors.InvalidAmount();
        }
        if (
            customerDiscountBps == 0 || customerDiscountBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        ) {
            revert SparkDaoErrors.InvalidDiscountBps();
        }
        if (researchShareBps > SparkDaoTypes.MAX_TEACHING_RESEARCH_SHARE_BPS) {
            revert SparkDaoErrors.InvalidResearchShareBps();
        }

        (uint16 seatPriceBps, uint16 teacherSalaryBps) = _tierBps(classSize);
        uint256 tierSeatPriceUnits =
            (baseSeatPriceUnits * seatPriceBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        quote.seatPriceUnits =
            (tierSeatPriceUnits * customerDiscountBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        quote.classTeacherSalaryUnits =
            (baseTeacherSalaryUnits * teacherSalaryBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        quote.seatTeacherSalaryUnits = quote.classTeacherSalaryUnits / classSize;
        if (quote.seatPriceUnits == 0 || quote.seatTeacherSalaryUnits == 0) {
            revert SparkDaoErrors.InvalidAmount();
        }

        quote.teacherBondUnits = quote.classTeacherSalaryUnits * 2;
        quote.seatResearchRewardUnits =
            (quote.seatPriceUnits * researchShareBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        quote.seatTeacherFaultResearchRewardUnits = quote.seatResearchRewardUnits * 2;
        if (quote.seatTeacherSalaryUnits + quote.seatResearchRewardUnits > quote.seatPriceUnits) {
            revert SparkDaoErrors.InvalidTeachingPricingPolicyQuote();
        }
        quote.seatServiceReserveUnits =
            quote.seatPriceUnits - quote.seatTeacherSalaryUnits - quote.seatResearchRewardUnits;

        uint256 teacherFaultChargeUnits = quote.seatPriceUnits / 2;
        uint256 remedialWageUnits = quote.seatTeacherSalaryUnits / 2;
        if (remedialWageUnits + quote.seatTeacherFaultResearchRewardUnits > teacherFaultChargeUnits)
        {
            revert SparkDaoErrors.FaultSettlementInsolvent();
        }
        quote.classSize = classSize;
    }

    function _tierBps(uint16 classSize)
        internal
        pure
        returns (uint16 seatPriceBps, uint16 teacherSalaryBps)
    {
        if (classSize == 1) return (10_000, 10_000);
        if (classSize == 2) return (8_000, 12_500);
        if (classSize <= 5) return (6_250, 16_000);
        if (classSize <= 10) return (4_444, 22_500);
        if (classSize <= 20) return (3_510, 28_500);
        if (classSize <= 35) return (2_860, 35_000);
        if (classSize <= 50) return (2_222, 45_000);
        return (2_000, 50_000);
    }
}
