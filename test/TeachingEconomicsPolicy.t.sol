// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingEconomicsPolicyV1 } from "../src/TeachingEconomicsPolicyV1.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";

contract TeachingEconomicsPolicyTest {
    TeachingEconomicsPolicyV1 internal policy = new TeachingEconomicsPolicyV1();

    function testPolicyVersionIsV1() public view {
        assert(policy.TEACHING_ECONOMICS_POLICY_VERSION() == 1);
    }

    function testCourseTypeQuoteFreezesBaseEconomics() public view {
        SparkDaoTypes.TeachingEconomicsQuote memory quote =
            policy.quoteCourseType(1_000_000, 400_000, 1_000);

        assert(quote.lessonPriceUnits == 1_000_000);
        assert(quote.teacherSalaryUnits == 400_000);
        assert(quote.teacherBondUnits == 800_000);
        assert(quote.researchRewardUnits == 100_000);
        assert(quote.teacherFaultResearchRewardUnits == 200_000);
        assert(quote.serviceReserveUnits == 500_000);
    }

    function testSessionQuoteAppliesDiscountBeforeRewardSplit() public view {
        SparkDaoTypes.TeachingEconomicsQuote memory quote =
            policy.quoteSession(1_000_000, 400_000, 1_000, 8_000);

        assert(quote.lessonPriceUnits == 800_000);
        assert(quote.teacherSalaryUnits == 400_000);
        assert(quote.teacherBondUnits == 800_000);
        assert(quote.researchRewardUnits == 80_000);
        assert(quote.teacherFaultResearchRewardUnits == 160_000);
        assert(quote.serviceReserveUnits == 320_000);
    }

    function testOddUnitsUseFloorDivision() public view {
        SparkDaoTypes.TeachingEconomicsQuote memory quote =
            policy.quoteSession(999_999, 333_333, 333, 8_001);

        assert(quote.lessonPriceUnits == 800_099);
        assert(quote.researchRewardUnits == 26_643);
        assert(
            quote.teacherSalaryUnits + quote.researchRewardUnits + quote.serviceReserveUnits
                == quote.lessonPriceUnits
        );
    }
}
