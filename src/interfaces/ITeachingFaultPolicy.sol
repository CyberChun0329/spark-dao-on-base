// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

/// @notice Stateless quote module for coordinator fault settlement branches.
/// @dev The registry freezes returned fault quotes when a teaching session is
/// created; policy modules do not own reserve or claim accounting.
interface ITeachingFaultPolicy {
    function FAULT_POLICY_VERSION() external view returns (uint8);

    function quoteCustomerFault(uint256 lessonPriceUnits, uint256 teacherSalaryUnits)
        external
        view
        returns (SparkDaoTypes.TeachingFaultQuote memory quote);

    function quoteTeacherFault(
        uint256 lessonPriceUnits,
        uint256 teacherSalaryUnits,
        uint256 requestedResearchRewardUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote);
}
