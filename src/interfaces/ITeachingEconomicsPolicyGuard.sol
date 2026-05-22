// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

/// @notice Validation adapter for teaching economics quote modules.
/// @dev Callers pass a candidate policy address; the guard validates version and
/// quote invariants without owning registry or distributor state.
interface ITeachingEconomicsPolicyGuard {
    function validateEconomicsPolicy(address policy) external view returns (uint8 version);

    function quoteCourseType(
        address policy,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote);

    function quoteSession(
        address policy,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps,
        uint16 customerDiscountBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote);
}
