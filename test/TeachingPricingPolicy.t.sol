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
        _assertQuote(2, 800_000, 500_000, 250_000);
        _assertQuote(3, 625_000, 640_000, 213_333);
        _assertQuote(5, 625_000, 640_000, 128_000);
        _assertQuote(6, 444_400, 900_000, 150_000);
        _assertQuote(10, 444_400, 900_000, 90_000);
        _assertQuote(11, 351_000, 1_140_000, 103_636);
        _assertQuote(20, 351_000, 1_140_000, 57_000);
        _assertQuote(21, 286_000, 1_400_000, 66_666);
        _assertQuote(35, 286_000, 1_400_000, 40_000);
        _assertQuote(36, 222_200, 1_800_000, 50_000);
        _assertQuote(50, 222_200, 1_800_000, 36_000);
        _assertQuote(51, 200_000, 2_000_000, 39_215);
        _assertQuote(100, 200_000, 2_000_000, 20_000);
    }

    function testTeacherSalaryGrowthDoesNotExceedGrossRevenueGrowth() public view {
        for (uint16 classSize = 1; classSize <= 100;) {
            SparkTeachingTypes.TeachingQuote memory quote =
                policy.quoteTeachingSession(1_000_000, 400_000, 0, classSize, 10_000);

            uint256 grossRevenueUnits = quote.seatPriceUnits * classSize;
            uint256 teacherSalaryGrowthBps = (quote.classTeacherSalaryUnits * 10_000) / 400_000;
            uint256 grossRevenueGrowthBps = (grossRevenueUnits * 10_000) / 1_000_000;
            assert(teacherSalaryGrowthBps <= grossRevenueGrowthBps);

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
