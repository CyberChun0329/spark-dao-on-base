// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkTeachingTypes } from "../SparkTeachingTypes.sol";

interface ITeachingPricingPolicy {
    function quoteTeachingSession(
        uint256 baseSeatPriceUnits,
        uint256 baseTeacherSalaryUnits,
        uint16 researchShareBps,
        uint16 classSize,
        uint16 customerDiscountBps
    ) external view returns (SparkTeachingTypes.TeachingQuote memory);
}
