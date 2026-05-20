// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingFaultPolicyV1 } from "../src/TeachingFaultPolicyV1.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";

contract TeachingFaultPolicyTest {
    TeachingFaultPolicyV1 internal policy = new TeachingFaultPolicyV1();

    function testPolicyVersionIsV1() public view {
        assertTrue(policy.FAULT_POLICY_VERSION() == 1);
    }

    function testCustomerFaultPaysHalfWageImmediately() public view {
        SparkDaoTypes.TeachingFaultQuote memory quote = policy.quoteCustomerFault(800_000, 400_000);

        assertTrue(quote.customerChargeUnits == 400_000);
        assertTrue(quote.customerRefundUnits == 400_000);
        assertTrue(quote.teacherImmediatePayoutUnits == 200_000);
        assertTrue(quote.remedialTeacherPayoutUnits == 0);
        assertTrue(quote.researchRewardUnits == 0);
        assertTrue(quote.serviceReserveUnits == 200_000);
        assertTrue(quote.remedialLessonCount == 0);
    }

    function testTeacherFaultRecordsHalfWageRemedialObligation() public view {
        SparkDaoTypes.TeachingFaultQuote memory quote =
            policy.quoteTeacherFault(800_000, 400_000, 160_000);

        assertTrue(quote.customerChargeUnits == 400_000);
        assertTrue(quote.customerRefundUnits == 400_000);
        assertTrue(quote.teacherImmediatePayoutUnits == 0);
        assertTrue(quote.remedialTeacherPayoutUnits == 200_000);
        assertTrue(quote.researchRewardUnits == 160_000);
        assertTrue(quote.serviceReserveUnits == 40_000);
        assertTrue(quote.remedialLessonCount == 1);
    }

    function testTeacherFaultRejectsInsolventResearchReward() public view {
        try this.quoteTeacherFault(800_000, 400_000, 200_001) {
            revert("expected revert");
        } catch { }
    }

    function testOddUnitsUseFloorDivision() public view {
        SparkDaoTypes.TeachingFaultQuote memory customerQuote = policy.quoteCustomerFault(101, 41);
        SparkDaoTypes.TeachingFaultQuote memory teacherQuote = policy.quoteTeacherFault(101, 41, 7);

        assertTrue(customerQuote.customerChargeUnits == 50);
        assertTrue(customerQuote.customerRefundUnits == 51);
        assertTrue(customerQuote.teacherImmediatePayoutUnits == 20);
        assertTrue(customerQuote.serviceReserveUnits == 30);
        assertTrue(teacherQuote.customerChargeUnits == 50);
        assertTrue(teacherQuote.customerRefundUnits == 51);
        assertTrue(teacherQuote.remedialTeacherPayoutUnits == 20);
        assertTrue(teacherQuote.researchRewardUnits == 7);
        assertTrue(teacherQuote.serviceReserveUnits == 23);
    }

    function quoteTeacherFault(uint256 priceUnits, uint256 salaryUnits, uint256 researchRewardUnits)
        external
        view
        returns (SparkDaoTypes.TeachingFaultQuote memory)
    {
        return policy.quoteTeacherFault(priceUnits, salaryUnits, researchRewardUnits);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }
}
