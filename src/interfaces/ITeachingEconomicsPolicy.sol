// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

interface ITeachingEconomicsPolicy {
    function TEACHING_ECONOMICS_POLICY_VERSION() external view returns (uint8);

    function quoteCourseType(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory);

    function quoteSession(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps,
        uint16 customerDiscountBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory);
}
