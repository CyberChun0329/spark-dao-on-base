// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

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
