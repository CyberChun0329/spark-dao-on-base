// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

interface ITeachingFaultPolicyGuard {
    function validatePolicy(address policy) external view returns (uint8 version);

    function quoteCustomerFault(
        address policy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote);

    function quoteTeacherFault(
        address policy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits,
        uint256 requestedResearchRewardUnits
    ) external view returns (SparkDaoTypes.TeachingFaultQuote memory quote);
}
