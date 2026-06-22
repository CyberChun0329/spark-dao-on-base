// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingPricingPolicyV1 } from "../src/TeachingPricingPolicyV1.sol";
import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { ResearchRegistry } from "../src/ResearchRegistry.sol";
import { SparkTeachingTypes } from "../src/SparkTeachingTypes.sol";
import { SparkDaoErrors } from "../src/SparkDaoErrors.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
}

contract TeachingRegistryTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TeachingRegistry internal teaching;
    TeachingRewardDistributor internal distributor;
    TeachingPricingPolicyV1 internal pricingPolicy;
    ResearchRegistry internal researchRegistry;
    ResearchPositionToken internal researchToken;
    TeachingNftToken internal teachingToken;
    MockERC20 internal stable;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal treasury = address(0xDA01);
    address internal teacher = address(0x7001);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);
    address internal contributorThree = address(0x1003);

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://teaching/");
        researchRegistry = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );
        pricingPolicy = new TeachingPricingPolicyV1();
        teaching = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchRegistry),
            address(pricingPolicy),
            address(teachingToken)
        );
        distributor = new TeachingRewardDistributor(address(teaching), address(researchRegistry));

        VM.prank(authority);
        researchToken.setMinter(address(researchRegistry));
        VM.prank(authority);
        teachingToken.setMinter(address(teaching));
        VM.prank(authority);
        researchRegistry.setTeachingRegistry(address(teaching));
        VM.prank(authority);
        teaching.setTeachingRewardDistributor(address(distributor));

        stable.mint(authority, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(treasury, 1_000_000_000);
        stable.mint(contributorOne, 1_000_000_000);
        stable.mint(contributorTwo, 1_000_000_000);
        stable.mint(contributorThree, 1_000_000_000);
    }

    function testOneStudentClassClosesValidAndTeacherRedeems() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();

        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        (
            uint8 status,,,
            uint16 classSize,
            uint256 seatPriceUnits,
            uint256 seatTeacherSalaryUnits,
            uint256 teacherBondUnits,
            uint256 teacherPayoutOwedUnits,
            uint256 remedialWageOwedUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits,
        ) = teaching.getTeachingSessionState(teachingNftId);

        assertTrue(status == 1);
        assertTrue(classSize == 1);
        assertTrue(seatPriceUnits == 1_000_000);
        assertTrue(seatTeacherSalaryUnits == 400_000);
        assertTrue(teacherBondUnits == 800_000);
        assertTrue(teacherPayoutOwedUnits == 400_000);
        assertTrue(remedialWageOwedUnits == 0);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 600_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 400_000);

        uint256 beforeTeacherBalance = stable.balanceOf(teacher);
        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);
        assertTrue(stable.balanceOf(teacher) == beforeTeacherBalance + 400_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);
    }

    function testCoordinatorCloseRequiresSecondRoundTimeoutButAutoCloseDoesNot() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 fallbackTeachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(fallbackTeachingNftId, students[0], 0);
        _lockTeacherBond(fallbackTeachingNftId);
        _warpPastTeachingSchedule();

        VM.expectRevert(SparkDaoErrors.TeachingCoordinatorTooEarly.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(fallbackTeachingNftId, 3);

        VM.expectRevert(SparkDaoErrors.TeachingCoordinatorTooEarly.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingTeacherFault(fallbackTeachingNftId, 4);

        VM.warp(block.timestamp + 30 days);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(fallbackTeachingNftId, 3);

        uint64 autoCloseTeachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(autoCloseTeachingNftId, students[0], 0);
        _lockTeacherBond(autoCloseTeachingNftId);
        _warpPastTeachingSchedule();
        VM.prank(teacher);
        teaching.confirmTeachingDelivery(autoCloseTeachingNftId);
        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(autoCloseTeachingNftId, 0);

        (uint8 status,,,,,,,,,,,) = teaching.getTeachingSessionState(autoCloseTeachingNftId);
        assertTrue(status == 1);
    }

    function testTeacherPayoutRedeemRequiresRedeemDelayAndKeepsBondAvailableAtClose() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingSchedule();
        VM.prank(teacher);
        teaching.confirmTeachingDelivery(teachingNftId);
        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(teachingNftId, 0);

        uint256 teacherBeforeRedeem = stable.balanceOf(teacher);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 400_000);

        VM.expectRevert(SparkDaoErrors.TeachingNotRedeemableYet.selector);
        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);

        VM.warp(block.timestamp + 30 days);
        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);

        assertTrue(stable.balanceOf(teacher) == teacherBeforeRedeem + 400_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);
    }

    function testTeachingScheduleRequiresTeacherAndCoordinatorConfirmation() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId = _createUnconfirmedClassAt(
            courseTypeId,
            students,
            uint64(block.timestamp + 1 days),
            _emptyAssetIds(),
            _emptyWeights()
        );

        stable.mint(students[0], 1_000_000_000);
        VM.startPrank(students[0]);
        stable.approve(address(teaching), type(uint256).max);
        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        teaching.payTeachingSeat(teachingNftId, 0);
        VM.stopPrank();

        VM.startPrank(teacher);
        stable.approve(address(teaching), type(uint256).max);
        teaching.confirmTeachingSchedule(teachingNftId, true);
        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        teaching.lockTeachingTeacherBond(teachingNftId);
        VM.stopPrank();

        VM.prank(coordinator);
        teaching.confirmTeachingSchedule(teachingNftId, false);

        (bool teacherConfirmed, bool coordinatorConfirmed, bool scheduleConfirmed) =
            teaching.getTeachingScheduleState(teachingNftId);
        assertTrue(teacherConfirmed);
        assertTrue(coordinatorConfirmed);
        assertTrue(scheduleConfirmed);

        VM.prank(students[0]);
        teaching.payTeachingSeat(teachingNftId, 0);
        VM.prank(teacher);
        teaching.lockTeachingTeacherBond(teachingNftId);
    }

    function testTeachingScheduleConfirmationRejectsWrongSignerAndDuplicates() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId = _createUnconfirmedClassAt(
            courseTypeId,
            students,
            uint64(block.timestamp + 1 days),
            _emptyAssetIds(),
            _emptyWeights()
        );

        VM.prank(students[0]);
        VM.expectRevert(SparkDaoErrors.UnauthorizedTeacher.selector);
        teaching.confirmTeachingSchedule(teachingNftId, true);

        VM.prank(students[0]);
        VM.expectRevert(SparkDaoErrors.UnauthorizedCoordinator.selector);
        teaching.confirmTeachingSchedule(teachingNftId, false);

        VM.prank(teacher);
        teaching.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(teacher);
        VM.expectRevert(SparkDaoErrors.TeachingAlreadySigned.selector);
        teaching.confirmTeachingSchedule(teachingNftId, true);

        VM.prank(coordinator);
        teaching.confirmTeachingSchedule(teachingNftId, false);
        VM.prank(coordinator);
        VM.expectRevert(SparkDaoErrors.TeachingAlreadySigned.selector);
        teaching.confirmTeachingSchedule(teachingNftId, false);
    }

    function testMajoritySecondRoundSignaturesAutoCloseValidWithoutCoordinator() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(3);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        for (uint16 i = 0; i < 3;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        teaching.confirmTeachingDelivery(teachingNftId);
        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(teachingNftId, 0);

        (uint8 openStatus,,,,,,,,,,,) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(openStatus == 0);

        VM.prank(students[1]);
        teaching.confirmTeachingAttendance(teachingNftId, 1);

        (
            uint8 closedStatus,,,,,,
            uint256 teacherBondUnits,
            uint256 teacherPayoutOwedUnits,
            uint256 remedialWageOwedUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits,
        ) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(closedStatus == 1);
        assertTrue(teacherBondUnits == 1_200_000);
        assertTrue(teacherPayoutOwedUnits == 600_000);
        assertTrue(remedialWageOwedUnits == 0);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 1_200_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 600_000);
    }

    function testExactlyHalfSecondRoundSignaturesDoNotAutoClose() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(4);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        for (uint16 i = 0; i < 4;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        teaching.confirmTeachingDelivery(teachingNftId);
        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(teachingNftId, 0);
        VM.prank(students[1]);
        teaching.confirmTeachingAttendance(teachingNftId, 1);

        (uint8 halfStatus,,,,,,,,,,,) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(halfStatus == 0);

        VM.prank(students[2]);
        teaching.confirmTeachingAttendance(teachingNftId, 2);

        (uint8 majorityStatus,,,,,,,,,,,) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(majorityStatus == 1);
    }

    function testTeacherDeliveryCanTriggerAutoCloseAfterStudentMajority() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(teachingNftId, 0);
        (uint8 beforeDeliveryStatus,,,,,,,,,,,) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(beforeDeliveryStatus == 0);

        VM.prank(teacher);
        teaching.confirmTeachingDelivery(teachingNftId);
        (uint8 afterDeliveryStatus,,,,,,,,,,,) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(afterDeliveryStatus == 1);
    }

    function testAttendanceRequiresPaidSeat() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        VM.expectRevert(SparkDaoErrors.TeachingSeatNotPaid.selector);
        VM.prank(students[0]);
        teaching.confirmTeachingAttendance(teachingNftId, 0);
    }

    function testCreateTeachingRejectsPastOrCurrentScheduledAt() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);

        VM.expectRevert(SparkDaoErrors.InvalidScheduledAt.selector);
        _createUnconfirmedClassAt(
            courseTypeId, students, uint64(block.timestamp), _emptyAssetIds(), _emptyWeights()
        );

        VM.expectRevert(SparkDaoErrors.InvalidScheduledAt.selector);
        _createUnconfirmedClassAt(
            courseTypeId, students, uint64(block.timestamp - 1), _emptyAssetIds(), _emptyWeights()
        );
    }

    function testCoordinatorCannotCloseTeachingBeforeScheduledAt() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);

        VM.expectRevert(SparkDaoErrors.TeachingCompletionTooEarly.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        VM.expectRevert(SparkDaoErrors.TeachingCompletionTooEarly.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);
    }

    function testTeachingResolutionCodesAreValidated() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(3);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 2 days);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingResolutionCode.selector);
        VM.prank(coordinator);
        teaching.markTeachingCustomerFault(teachingNftId, 0, 1);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingResolutionCode.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingTeacherFault(teachingNftId, 1);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingResolutionCode.selector);
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 2);
    }

    function testStudentCanWithdrawUnmatchedTeachingSeatPaymentBeforeTeacherLocks() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        _paySeat(teachingNftId, students[0], 0);
        uint256 fundedBalance = 1_000_000_000;
        assertTrue(stable.balanceOf(students[0]) == fundedBalance - 1_000_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 1_000_000);

        VM.prank(students[0]);
        teaching.withdrawUnmatchedTeachingSeatPayment(teachingNftId, 0);

        (,, bool paid,,, bool refundClaimed) = teaching.getTeachingSeat(teachingNftId, 0);
        assertTrue(!paid);
        assertTrue(!refundClaimed);
        assertTrue(stable.balanceOf(students[0]) == fundedBalance);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);
    }

    function testTeacherCanWithdrawUnmatchedTeachingBondBeforeAnySeatPays() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        uint256 beforeBalance = stable.balanceOf(teacher);
        _lockTeacherBond(teachingNftId);
        assertTrue(stable.balanceOf(teacher) == beforeBalance - 800_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 800_000);

        VM.prank(teacher);
        teaching.withdrawUnmatchedTeachingTeacherBond(teachingNftId);

        assertTrue(stable.balanceOf(teacher) == beforeBalance);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);

        _lockTeacherBond(teachingNftId);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 800_000);
    }

    function testTeachingUnmatchedWithdrawalsRejectMatchedFunds() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(1);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        VM.prank(students[0]);
        teaching.withdrawUnmatchedTeachingSeatPayment(teachingNftId, 0);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        VM.prank(teacher);
        teaching.withdrawUnmatchedTeachingTeacherBond(teachingNftId);
    }

    function testHundredStudentClassRecordsOnePoolPerAssetAndCurrentHolderClaims() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne, 10_000);
        uint64[] memory assetIds = new uint64[](1);
        assetIds[0] = assetId;
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 1_000);
        address[] memory students = _students(100);
        uint64 teachingNftId = _createClass(courseTypeId, students, assetIds, _emptyWeights());

        for (uint16 i = 0; i < 100;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();

        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        (uint256 amount, uint64 unlockAt, bool claimed) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        assertTrue(amount == 1_500_000);
        assertTrue(unlockAt != 0);
        assertTrue(!claimed);

        VM.prank(contributorOne);
        researchRegistry.transferResearchPosition(assetId, positionId, contributorTwo);

        VM.warp(unlockAt);
        uint256 beforeHolderBalance = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);
        assertTrue(stable.balanceOf(contributorTwo) == beforeHolderBalance + 1_500_000);

        SparkDaoTypes.ResearchPosition memory position =
            researchRegistry.getResearchPosition(assetId, positionId);
        assertTrue(position.totalClaimedUnits == 1_500_000);
    }

    function testMixedCustomerFaultSeatsKeepRefundsIndependent() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(3);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        for (uint16 i = 0; i < 3;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);

        VM.prank(coordinator);
        teaching.markTeachingCustomerFault(teachingNftId, 1, 2);
        _warpPastTeachingCoordinatorTimeout();
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 800_000);

        (,,,, uint256 refundOwedUnits, bool refundClaimed) =
            teaching.getTeachingSeat(teachingNftId, 1);
        assertTrue(refundOwedUnits == 300_000);
        assertTrue(!refundClaimed);

        uint256 beforeStudentBalance = stable.balanceOf(students[1]);
        VM.prank(students[1]);
        teaching.claimTeachingSeatRefund(teachingNftId, 1);
        assertTrue(stable.balanceOf(students[1]) == beforeStudentBalance + 300_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 500_000);

        uint256 beforeTeacherBalance = stable.balanceOf(teacher);
        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);
        assertTrue(stable.balanceOf(teacher) == beforeTeacherBalance + 500_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);
    }

    function testTeacherFaultIsClassLevelAndRemedialWageSettlesOnce() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(2);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        _paySeat(teachingNftId, students[0], 0);
        _paySeat(teachingNftId, students[1], 1);
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();

        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);

        (
            uint8 status,,,,,,,
            uint256 teacherPayoutOwedUnits,
            uint256 remedialWageOwedUnits,,
            uint256 serviceReserveUnits,
        ) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(status == 2);
        assertTrue(teacherPayoutOwedUnits == 0);
        assertTrue(remedialWageOwedUnits == 300_000);
        assertTrue(serviceReserveUnits == 300_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 900_000);

        VM.prank(students[0]);
        teaching.claimTeachingSeatRefund(teachingNftId, 0);
        VM.prank(students[1]);
        teaching.claimTeachingSeatRefund(teachingNftId, 1);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 300_000);

        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 300_000);

        VM.prank(coordinator);
        teaching.coordinatorSettleTeachingRemedialWage(teachingNftId);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);

        VM.expectRevert(SparkDaoErrors.TeachingRemedialWageAlreadySettled.selector);
        VM.prank(coordinator);
        teaching.coordinatorSettleTeachingRemedialWage(teachingNftId);
    }

    function testWrongDistributorCannotCallTeachingCallback() public {
        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        teaching.settleTeachingRewardClaim(address(stable), contributorOne, 0, 0, 1, 0);
    }

    function testDuplicateTeachingRewardPoolRejected() public {
        VM.prank(address(teaching));
        distributor.recordTeachingRewardPool(
            1,
            2,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        VM.expectRevert(SparkDaoErrors.InvalidTeachingRewardPool.selector);
        VM.prank(address(teaching));
        distributor.recordTeachingRewardPool(
            1,
            2,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );
    }

    function testTeachingRewardBatchClaimIsAtomic() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne, 10_000);
        uint64[] memory assetIds = new uint64[](1);
        assetIds[0] = assetId;
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 1_000);
        address[] memory students = _students(1);
        uint64 teachingNftId = _createClass(courseTypeId, students, assetIds, _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);

        uint64[] memory teachingNftIds = new uint64[](2);
        uint64[] memory batchAssetIds = new uint64[](2);
        uint64[] memory positionIds = new uint64[](2);
        teachingNftIds[0] = teachingNftId;
        teachingNftIds[1] = teachingNftId;
        batchAssetIds[0] = assetId;
        batchAssetIds[1] = 999;
        positionIds[0] = positionId;
        positionIds[1] = positionId;

        VM.expectRevert();
        VM.prank(contributorOne);
        distributor.claimTeachingRewardBatch(teachingNftIds, batchAssetIds, positionIds);

        (uint256 amount,, bool claimed) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        assertTrue(amount == 100_000);
        assertTrue(!claimed);

        VM.prank(contributorOne);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);
    }

    function testTeachingRewardDustReleasesOnceWhenPoolComplete() public {
        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset("Dust", "ipfs://dust");
        uint64 firstPositionId = _createPosition(assetId, 3_333, contributorOne);
        uint64 secondPositionId = _createPosition(assetId, 3_333, contributorTwo);
        uint64 thirdPositionId = _createPosition(assetId, 3_334, contributorThree);
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();

        MockTeachingRewardSource source = new MockTeachingRewardSource();
        TeachingRewardDistributor localDistributor =
            new TeachingRewardDistributor(address(source), address(researchRegistry));
        source.recordPool(
            localDistributor,
            9,
            assetId,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        VM.prank(contributorOne);
        localDistributor.claimTeachingReward(9, assetId, firstPositionId);
        VM.prank(contributorTwo);
        localDistributor.claimTeachingReward(9, assetId, secondPositionId);
        assertTrue(source.totalDustUnits() == 0);

        VM.prank(contributorThree);
        localDistributor.claimTeachingReward(9, assetId, thirdPositionId);
        assertTrue(source.totalClaimAmount() == 99);
        assertTrue(source.totalDustUnits() == 1);

        VM.expectRevert(SparkDaoErrors.TeachingRewardAlreadyClaimed.selector);
        VM.prank(contributorThree);
        localDistributor.claimTeachingReward(9, assetId, thirdPositionId);
        assertTrue(source.totalDustUnits() == 1);
    }

    function testBoughtBackTeachingRewardClaimRoutesToTreasury() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne, 10_000);
        uint64[] memory assetIds = new uint64[](1);
        assetIds[0] = assetId;
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 1_000);
        address[] memory students = _students(1);
        uint64 teachingNftId = _createClass(courseTypeId, students, assetIds, _emptyWeights());
        _paySeat(teachingNftId, students[0], 0);
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        VM.startPrank(authority);
        stable.approve(address(researchRegistry), 250_000);
        researchRegistry.fundDaoVault(250_000);
        VM.stopPrank();

        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        researchRegistry.sellPositionBackToDao(assetId, positionId);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);
        uint256 beforeTreasuryBalance = stable.balanceOf(treasury);
        VM.prank(treasury);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);
        assertTrue(stable.balanceOf(treasury) == beforeTreasuryBalance + 100_000);
    }

    function testIdleWithdrawalCannotTouchReservedSeatTeacherOrRewardUnits() public {
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(3);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        for (uint16 i = 0; i < 3;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);
        VM.prank(coordinator);
        teaching.markTeachingCustomerFault(teachingNftId, 1, 2);
        _warpPastTeachingCoordinatorTimeout();
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 800_000);
        VM.prank(authority);
        teaching.withdrawTeachingIdleFor(address(stable), 1_000_000);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 800_000);

        VM.expectRevert(SparkDaoErrors.VaultFundsReserved.selector);
        VM.prank(authority);
        teaching.withdrawTeachingIdleFor(address(stable), 1);
    }

    function testFuzzClassSizeReserveConservation(uint16 rawClassSize) public {
        uint16 classSize = uint16((rawClassSize % 100) + 1);
        uint64 courseTypeId = _createCourseType(1_000_000, 400_000, 0);
        address[] memory students = _students(classSize);
        uint64 teachingNftId =
            _createClass(courseTypeId, students, _emptyAssetIds(), _emptyWeights());

        for (uint16 i = 0; i < classSize;) {
            _paySeat(teachingNftId, students[i], i);
            unchecked {
                ++i;
            }
        }
        _lockTeacherBond(teachingNftId);
        _warpPastTeachingCoordinatorTimeout();
        VM.prank(coordinator);
        teaching.coordinatorCloseTeachingValid(teachingNftId, 1);

        (
            ,,,,,
            uint256 seatTeacherSalaryUnits,
            uint256 teacherBondUnits,
            uint256 teacherPayoutOwedUnits,,,,
        ) = teaching.getTeachingSessionState(teachingNftId);
        assertTrue(teacherPayoutOwedUnits == seatTeacherSalaryUnits * classSize);
        assertTrue(teacherBondUnits != 0);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == teacherPayoutOwedUnits);

        VM.prank(teacher);
        teaching.redeemTeachingTeacherPayout(teachingNftId);
        assertTrue(teaching.getVaultReservedUnits(address(stable)) == 0);
    }

    function _createCourseType(
        uint256 baseSeatPriceUnits,
        uint256 baseTeacherSalaryUnits,
        uint16 researchShareBps
    ) internal returns (uint64 courseTypeId) {
        VM.prank(coordinator);
        courseTypeId = teaching.createTeachingCourseType(
            "Demo Teaching", baseSeatPriceUnits, baseTeacherSalaryUnits, researchShareBps
        );
    }

    function _createClass(
        uint64 courseTypeId,
        address[] memory students,
        uint64[] memory assetIds,
        uint16[] memory weights
    ) internal returns (uint64 teachingNftId) {
        teachingNftId = _createClassAt(
            courseTypeId, students, uint64(block.timestamp + 1 days), assetIds, weights
        );
    }

    function _createClassAt(uint64 courseTypeId, address[] memory students, uint64 scheduledAt)
        internal
        returns (uint64 teachingNftId)
    {
        teachingNftId =
            _createClassAt(courseTypeId, students, scheduledAt, _emptyAssetIds(), _emptyWeights());
    }

    function _createClassAt(
        uint64 courseTypeId,
        address[] memory students,
        uint64 scheduledAt,
        uint64[] memory assetIds,
        uint16[] memory weights
    ) internal returns (uint64 teachingNftId) {
        teachingNftId = _createUnconfirmedClassAt(
            courseTypeId, students, scheduledAt, assetIds, weights
        );
        _confirmTeachingSchedule(teachingNftId);
    }

    function _createUnconfirmedClassAt(
        uint64 courseTypeId,
        address[] memory students,
        uint64 scheduledAt,
        uint64[] memory assetIds,
        uint16[] memory weights
    ) internal returns (uint64 teachingNftId) {
        VM.prank(coordinator);
        teachingNftId = teaching.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: scheduledAt,
                customerDiscountBps: 10_000,
                linkedResearchAssetIds: assetIds,
                linkedResearchWeightBps: weights
            })
        );
    }

    function _confirmTeachingSchedule(uint64 teachingNftId) internal {
        VM.prank(teacher);
        teaching.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(coordinator);
        teaching.confirmTeachingSchedule(teachingNftId, false);
    }

    function _paySeat(uint64 teachingNftId, address student, uint16 seatIndex) internal {
        stable.mint(student, 1_000_000_000);
        VM.startPrank(student);
        stable.approve(address(teaching), type(uint256).max);
        teaching.payTeachingSeat(teachingNftId, seatIndex);
        VM.stopPrank();
    }

    function _lockTeacherBond(uint64 teachingNftId) internal {
        VM.startPrank(teacher);
        stable.approve(address(teaching), type(uint256).max);
        teaching.lockTeachingTeacherBond(teachingNftId);
        VM.stopPrank();
    }

    function _warpPastTeachingSchedule() internal {
        VM.warp(block.timestamp + 2 days);
    }

    function _warpPastTeachingCoordinatorTimeout() internal {
        VM.warp(block.timestamp + SparkDaoTypes.TEACHING_SECOND_ROUND_TIMEOUT_SECONDS + 2 days);
    }

    function _createReadyResearchAsset(address beneficiary, uint16 shareBps)
        internal
        returns (uint64 assetId, uint64 positionId)
    {
        VM.startPrank(coordinator);
        assetId = researchRegistry.createResearchAsset("Teaching Research", "ipfs://teaching");
        positionId = _createPosition(assetId, shareBps, beneficiary);
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();
    }

    function _createPosition(uint64 assetId, uint16 shareBps, address beneficiary)
        internal
        returns (uint64 positionId)
    {
        positionId = researchRegistry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: shareBps,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: beneficiary
            })
        );
    }

    function _students(uint16 count) internal pure returns (address[] memory students) {
        students = new address[](count);
        for (uint16 i = 0; i < count;) {
            students[i] = address(uint160(0x5000 + i));
            unchecked {
                ++i;
            }
        }
    }

    function _emptyAssetIds() internal pure returns (uint64[] memory values) {
        values = new uint64[](0);
    }

    function _emptyWeights() internal pure returns (uint16[] memory values) {
        values = new uint16[](0);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }
}

contract MockTeachingRewardSource {
    uint256 public totalClaimAmount;
    uint256 public totalDustUnits;

    function recordPool(
        TeachingRewardDistributor distributor,
        uint64 teachingNftId,
        uint64 assetId,
        address stableAsset,
        uint256 assetPoolUnits,
        uint256 distributedUnits,
        uint64 snapshotAt,
        uint64 unlockAt,
        uint16 snapshotActiveLayer,
        uint16 totalEffectiveShareBps
    ) external {
        distributor.recordTeachingRewardPool(
            teachingNftId,
            assetId,
            stableAsset,
            assetPoolUnits,
            distributedUnits,
            snapshotAt,
            unlockAt,
            snapshotActiveLayer,
            totalEffectiveShareBps
        );
    }

    function settleTeachingRewardClaim(
        address,
        address,
        uint64,
        uint64,
        uint256 claimAmount,
        uint256 dustUnits
    ) external {
        totalClaimAmount += claimAmount;
        totalDustUnits += dustUnits;
    }
}
