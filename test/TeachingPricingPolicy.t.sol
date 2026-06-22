// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingPricingPolicyV1 } from "../src/TeachingPricingPolicyV1.sol";
import { SparkTeachingTypes } from "../src/SparkTeachingTypes.sol";
import { SparkDaoErrors } from "../src/SparkDaoErrors.sol";

interface Vm {
    function expectRevert(bytes4) external;
}

contract TeachingPricingPolicyTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TeachingPricingPolicyV1 internal policy = new TeachingPricingPolicyV1();

    function testPolicyVersionIsV1() public view {
        assert(policy.TEACHING_PRICING_POLICY_VERSION() == 1);
    }

    function testTierBoundariesFreezeSeatPriceAndClassSalary() public view {
        _assertQuote(1, 1_000_000, 400_000, 400_000);
        _assertQuote(2, 600_000, 600_000, 300_000);
        _assertQuote(5, 600_000, 600_000, 120_000);
        _assertQuote(6, 350_000, 800_000, 133_333);
        _assertQuote(20, 350_000, 800_000, 40_000);
        _assertQuote(21, 220_000, 1_000_000, 47_619);
        _assertQuote(50, 220_000, 1_000_000, 20_000);
        _assertQuote(51, 150_000, 1_200_000, 23_529);
        _assertQuote(100, 150_000, 1_200_000, 12_000);
    }

    function testRejectsClassSizeOutsideOneToOneHundred() public {
        VM.expectRevert(SparkDaoErrors.InvalidAmount.selector);
        policy.quoteTeachingSession(1_000_000, 400_000, 1_000, 0, 10_000);

        VM.expectRevert(SparkDaoErrors.InvalidAmount.selector);
        policy.quoteTeachingSession(1_000_000, 400_000, 1_000, 101, 10_000);
    }

    function testOneStudentQuoteMatchesSingleLessonEconomicsShape() public view {
        SparkTeachingTypes.TeachingQuote memory quote =
            policy.quoteTeachingSession(1_000_000, 400_000, 1_000, 1, 10_000);

        assert(quote.seatPriceUnits == 1_000_000);
        assert(quote.classTeacherSalaryUnits == 400_000);
        assert(quote.seatTeacherSalaryUnits == 400_000);
        assert(quote.teacherBondUnits == 800_000);
        assert(quote.seatResearchRewardUnits == 100_000);
        assert(quote.seatTeacherFaultResearchRewardUnits == 200_000);
        assert(quote.seatServiceReserveUnits == 500_000);
    }

    function testOneStudentDiscountMatchesSingleLessonEconomicsShape() public view {
        SparkTeachingTypes.TeachingQuote memory quote =
            policy.quoteTeachingSession(1_000_000, 400_000, 1_000, 1, 8_000);

        assert(quote.seatPriceUnits == 800_000);
        assert(quote.classTeacherSalaryUnits == 400_000);
        assert(quote.seatTeacherSalaryUnits == 400_000);
        assert(quote.teacherBondUnits == 800_000);
        assert(quote.seatResearchRewardUnits == 80_000);
        assert(quote.seatTeacherFaultResearchRewardUnits == 160_000);
        assert(quote.seatServiceReserveUnits == 320_000);
    }

    function _assertQuote(
        uint16 classSize,
        uint256 expectedSeatPriceUnits,
        uint256 expectedClassTeacherSalaryUnits,
        uint256 expectedSeatTeacherSalaryUnits
    ) internal view {
        SparkTeachingTypes.TeachingQuote memory quote =
            policy.quoteTeachingSession(1_000_000, 400_000, 1_000, classSize, 10_000);

        assert(quote.classSize == classSize);
        assert(quote.seatPriceUnits == expectedSeatPriceUnits);
        assert(quote.classTeacherSalaryUnits == expectedClassTeacherSalaryUnits);
        assert(quote.seatTeacherSalaryUnits == expectedSeatTeacherSalaryUnits);
        assert(quote.teacherBondUnits == expectedClassTeacherSalaryUnits * 2);
        assert(quote.seatResearchRewardUnits == expectedSeatPriceUnits / 10);
    }
}
