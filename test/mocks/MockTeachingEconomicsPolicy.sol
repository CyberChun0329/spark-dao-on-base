// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../../src/SparkDaoTypes.sol";
import { ITeachingEconomicsPolicy } from "../../src/interfaces/ITeachingEconomicsPolicy.sol";

contract MockTeachingEconomicsPolicy is ITeachingEconomicsPolicy {
    uint8 public immutable TEACHING_ECONOMICS_POLICY_VERSION;
    uint8 internal immutable MODE;

    constructor(uint8 version_, uint8 mode_) {
        TEACHING_ECONOMICS_POLICY_VERSION = version_;
        MODE = mode_;
    }

    function quoteCourseType(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory) {
        uint256 actualSalaryUnits = MODE == 3 ? teacherSalaryUnits / 2 : teacherSalaryUnits;
        return _quote(listPriceUnits, actualSalaryUnits, researchShareBps);
    }

    function quoteSession(
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps,
        uint16 customerDiscountBps
    ) external view returns (SparkDaoTypes.TeachingEconomicsQuote memory) {
        uint256 lessonPriceUnits =
            (listPriceUnits * customerDiscountBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        return _quote(lessonPriceUnits, teacherSalaryUnits, researchShareBps);
    }

    function _quote(uint256 lessonPriceUnits, uint256 teacherSalaryUnits, uint16 researchShareBps)
        internal
        view
        returns (SparkDaoTypes.TeachingEconomicsQuote memory quote)
    {
        uint256 baseResearchRewardUnits =
            (lessonPriceUnits * researchShareBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        uint256 researchRewardUnits = MODE == 5 ? 0 : baseResearchRewardUnits;
        uint256 serviceReserveUnits = lessonPriceUnits - teacherSalaryUnits - researchRewardUnits;
        if (MODE == 1) serviceReserveUnits += 1;

        quote = SparkDaoTypes.TeachingEconomicsQuote({
            lessonPriceUnits: lessonPriceUnits,
            teacherSalaryUnits: teacherSalaryUnits,
            teacherBondUnits: MODE == 4 ? 0 : teacherSalaryUnits * 2,
            researchRewardUnits: researchRewardUnits,
            teacherFaultResearchRewardUnits: baseResearchRewardUnits * 2,
            serviceReserveUnits: serviceReserveUnits
        });
    }
}
