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

        (uint16 seatPriceBps, uint16 teacherSalaryBps) = _powerLawBps(classSize);
        uint256 scaledSeatPriceUnits =
            (baseSeatPriceUnits * seatPriceBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        quote.seatPriceUnits =
            (scaledSeatPriceUnits * customerDiscountBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
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

    function _powerLawBps(uint16 classSize)
        internal
        pure
        returns (uint16 seatPriceBps, uint16 teacherSalaryBps)
    {
        teacherSalaryBps = _capacityMultiplierBps(classSize);
        // m(n) scales total salary while its reciprocal scales the per-seat price.
        // forge-lint: disable-next-line(unsafe-typecast)
        seatPriceBps = uint16(100_000_000 / teacherSalaryBps);
    }

    function _capacityMultiplierBps(uint16 classSize) internal pure returns (uint16) {
        if (classSize <= 2) return _interpolate(classSize, 1, 10_000, 2, 12_746);
        if (classSize <= 5) return _interpolate(classSize, 2, 12_746, 5, 17_565);
        if (classSize <= 10) return _interpolate(classSize, 5, 17_565, 10, 22_387);
        if (classSize <= 20) return _interpolate(classSize, 10, 22_387, 20, 28_534);
        if (classSize <= 35) return _interpolate(classSize, 20, 28_534, 35, 34_708);
        if (classSize <= 50) return _interpolate(classSize, 35, 34_708, 50, 39_322);
        return _interpolate(classSize, 50, 39_322, 100, 50_119);
    }

    function _interpolate(
        uint16 classSize,
        uint16 lowerClassSize,
        uint16 lowerMultiplierBps,
        uint16 upperClassSize,
        uint16 upperMultiplierBps
    ) internal pure returns (uint16) {
        uint256 offset = classSize - lowerClassSize;
        uint256 span = upperClassSize - lowerClassSize;
        uint256 delta = upperMultiplierBps - lowerMultiplierBps;
        // forge-lint: disable-next-line(unsafe-typecast)
        return uint16(uint256(lowerMultiplierBps) + (delta * offset) / span);
    }
}
