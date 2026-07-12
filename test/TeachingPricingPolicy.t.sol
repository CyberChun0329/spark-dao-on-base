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

    function testPowerLawAnchorsFreezeSeatPriceAndClassSalary() public view {
        _assertQuote(1, 1_000_000, 400_000, 400_000);
        _assertQuote(2, 784_500, 509_840, 254_920);
        _assertQuote(3, 696_700, 574_080, 191_360);
        _assertQuote(5, 569_300, 702_600, 140_520);
        _assertQuote(6, 539_600, 741_160, 123_526);
        _assertQuote(10, 446_600, 895_480, 89_548);
        _assertQuote(11, 434_700, 920_040, 83_640);
        _assertQuote(20, 350_400, 1_141_360, 57_068);
        _assertQuote(21, 345_400, 1_157_800, 55_133);
        _assertQuote(35, 288_100, 1_388_320, 39_666);
        _assertQuote(36, 285_500, 1_400_600, 38_905);
        _assertQuote(50, 254_300, 1_572_880, 31_457);
        _assertQuote(51, 252_900, 1_581_480, 31_009);
        _assertQuote(100, 199_500, 2_004_760, 20_047);
    }

    function testEachAddedStudentKeepsRevenueMonotonicAndSalaryGrowthBounded() public view {
        SparkTeachingTypes.TeachingQuote memory previous =
            policy.quoteTeachingSession(1_000_000, 400_000, 0, 1, 10_000);
        uint256 previousRevenueUnits = previous.seatPriceUnits;

        for (uint16 classSize = 2; classSize <= 100;) {
            SparkTeachingTypes.TeachingQuote memory current =
                policy.quoteTeachingSession(1_000_000, 400_000, 0, classSize, 10_000);
            uint256 currentRevenueUnits = current.seatPriceUnits * classSize;

            assert(currentRevenueUnits >= previousRevenueUnits);
            assert(
                current.classTeacherSalaryUnits * previousRevenueUnits
                    <= previous.classTeacherSalaryUnits * currentRevenueUnits
            );

            previous = current;
            previousRevenueUnits = currentRevenueUnits;
            unchecked {
                ++classSize;
            }
        }
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
