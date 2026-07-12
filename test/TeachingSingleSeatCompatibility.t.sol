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

contract TeachingSingleSeatCompatibilityTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockERC20 internal stable;
    MockERC20 internal eurc;
    ResearchPositionToken internal researchToken;
    ResearchRegistry internal researchRegistry;
    TeachingPricingPolicyV1 internal pricingPolicy;
    TeachingRegistry internal teachingRegistry;
    TeachingRewardDistributor internal distributor;
    TeachingNftToken internal teachingToken;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal treasury = address(0xDA01);
    address internal teacher = address(0x7001);
    address internal student = address(0x7002);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);

    uint256 internal constant PRICE_UNITS = 1_000_000;
    uint256 internal constant TEACHER_SALARY_UNITS = 400_000;
    uint256 internal constant TEACHER_BOND_UNITS = 800_000;
    uint16 internal constant RESEARCH_SHARE_BPS = 1_000;

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        eurc = new MockERC20("Euro Coin", "EURC", 6);
        researchToken =
            new ResearchPositionToken(authority, "Spark Research Position", "SRP", "ipfs://rp/");
        teachingToken = new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://ct/");

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
        teachingRegistry = new TeachingRegistry(
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
        distributor =
            new TeachingRewardDistributor(address(teachingRegistry), address(researchRegistry));

        VM.prank(authority);
        researchToken.setMinter(address(researchRegistry));
        VM.prank(authority);
        teachingToken.setMinter(address(teachingRegistry));
        VM.prank(authority);
        researchRegistry.setTeachingRegistry(address(teachingRegistry));
        VM.prank(authority);
        teachingRegistry.setTeachingRewardDistributor(address(distributor));

        stable.mint(authority, 1_000_000_000);
        stable.mint(treasury, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(student, 1_000_000_000);
        stable.mint(contributorOne, 1_000_000_000);
        stable.mint(contributorTwo, 1_000_000_000);
        eurc.mint(teacher, 1_000_000_000);
        eurc.mint(student, 1_000_000_000);
    }

    function testClassSizeOneQuoteKeepsSingleSeatEconomics() public view {
        SparkTeachingTypes.TeachingQuote memory quote = pricingPolicy.quoteTeachingSession(
            PRICE_UNITS, TEACHER_SALARY_UNITS, RESEARCH_SHARE_BPS, 1, 10_000
        );

        assertEq(quote.classSize, 1);
        assertEq(quote.seatPriceUnits, PRICE_UNITS);
        assertEq(quote.classTeacherSalaryUnits, TEACHER_SALARY_UNITS);
        assertEq(quote.seatTeacherSalaryUnits, TEACHER_SALARY_UNITS);
        assertEq(quote.teacherBondUnits, TEACHER_BOND_UNITS);
        assertEq(quote.seatResearchRewardUnits, 100_000);
        assertEq(quote.seatTeacherFaultResearchRewardUnits, 200_000);
        assertEq(quote.seatServiceReserveUnits, 500_000);
    }

    function testClassSizeOneMintsTeachingNftToTeacher() public {
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());

        assertEq(teachingToken.ownerOf(teachingNftId), teacher);
        assertEq(teachingToken.balanceOf(teacher), 1);
    }

    function testClassSizeOneNormalCloseFinalBalancesAndIdleReserve() public {
        uint256 teacherBefore = stable.balanceOf(teacher);
        uint256 studentBefore = stable.balanceOf(student);
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());

        _completeTeachingAsValidAndRedeem(teachingNftId);

        assertEq(stable.balanceOf(teacher) - teacherBefore, TEACHER_SALARY_UNITS);
        assertEq(studentBefore - stable.balanceOf(student), PRICE_UNITS);
        assertEq(stable.balanceOf(address(teachingRegistry)), 600_000);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneDiscountedCloseKeepsFrozenSalaryAndDiscountedSeatPrice() public {
        uint256 teacherBefore = stable.balanceOf(teacher);
        uint256 studentBefore = stable.balanceOf(student);
        uint64 teachingNftId =
            _createTeachingSessionWithDiscount(8_000, 0, _emptyAssetIds(), _emptyWeights());

        _completeTeachingAsValidAndRedeem(teachingNftId);

        assertEq(stable.balanceOf(teacher) - teacherBefore, TEACHER_SALARY_UNITS);
        assertEq(studentBefore - stable.balanceOf(student), 800_000);
        assertEq(stable.balanceOf(address(teachingRegistry)), 400_000);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneTeacherUnmatchedWithdrawalRestoresTeacherBond() public {
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());
        uint256 teacherBefore = stable.balanceOf(teacher);

        _lockTeachingTeacherBond(teachingNftId);
        VM.prank(teacher);
        teachingRegistry.withdrawUnmatchedTeachingTeacherBond(teachingNftId);

        assertEq(stable.balanceOf(teacher), teacherBefore);
        assertEq(stable.balanceOf(address(teachingRegistry)), 0);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneStudentUnmatchedWithdrawalRestoresSeatPayment() public {
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());
        uint256 studentBefore = stable.balanceOf(student);

        _payTeachingSeat(teachingNftId);
        VM.prank(student);
        teachingRegistry.withdrawUnmatchedTeachingSeatPayment(teachingNftId, 0);

        assertEq(stable.balanceOf(student), studentBefore);
        assertEq(stable.balanceOf(address(teachingRegistry)), 0);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneCustomerFaultKeepsPerSeatRefundAndDelayedHalfWage() public {
        uint256 teacherBefore = stable.balanceOf(teacher);
        uint256 studentBefore = stable.balanceOf(student);
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());

        _payTeachingSeat(teachingNftId);
        _lockTeachingTeacherBond(teachingNftId);
        VM.prank(coordinator);
        teachingRegistry.markTeachingCustomerFault(teachingNftId, 0, 2);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        teachingRegistry.coordinatorCloseTeachingValid(teachingNftId, 3);

        (uint8 status,,,,,,,,,,,) = teachingRegistry.getTeachingSessionState(teachingNftId);
        (,,, bool customerFault, uint256 refundOwed, bool refundClaimed) =
            teachingRegistry.getTeachingSeat(teachingNftId, 0);
        assertEq(status, 1);
        assertTrue(customerFault);
        assertEq(refundOwed, 500_000);
        assertTrue(!refundClaimed);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 700_000);

        VM.prank(student);
        teachingRegistry.claimTeachingSeatRefund(teachingNftId, 0);
        VM.prank(teacher);
        teachingRegistry.redeemTeachingTeacherPayout(teachingNftId);

        assertEq(stable.balanceOf(teacher) - teacherBefore, 200_000);
        assertEq(studentBefore - stable.balanceOf(student), 500_000);
        assertEq(stable.balanceOf(address(teachingRegistry)), 300_000);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneTeacherFaultUsesRefundAndRemedialWage() public {
        uint256 teacherBefore = stable.balanceOf(teacher);
        uint256 studentBefore = stable.balanceOf(student);
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());

        _payTeachingSeat(teachingNftId);
        _lockTeachingTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        teachingRegistry.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);

        (uint8 status,,,,,,,, uint256 remedialWageOwed,,,) =
            teachingRegistry.getTeachingSessionState(teachingNftId);
        (,,,, uint256 refundOwed,) = teachingRegistry.getTeachingSeat(teachingNftId, 0);
        assertEq(status, 2);
        assertEq(refundOwed, 500_000);
        assertEq(remedialWageOwed, 200_000);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 700_000);

        VM.prank(student);
        teachingRegistry.claimTeachingSeatRefund(teachingNftId, 0);
        VM.prank(teacher);
        teachingRegistry.redeemTeachingTeacherPayout(teachingNftId);
        VM.prank(coordinator);
        teachingRegistry.coordinatorSettleTeachingRemedialWage(teachingNftId);

        assertEq(stable.balanceOf(teacher) - teacherBefore, 200_000);
        assertEq(studentBefore - stable.balanceOf(student), 500_000);
        assertEq(stable.balanceOf(address(teachingRegistry)), 300_000);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneFaultRefundRoundsOddSeatPriceTowardStudent() public {
        uint256 oddPriceUnits = 1_000_001;
        uint256 expectedRefund = 500_001;

        VM.prank(coordinator);
        uint64 courseTypeId = teachingRegistry.createTeachingCourseType(
            "Odd Price Teaching", oddPriceUnits, TEACHER_SALARY_UNITS, 0
        );

        uint64 customerFaultTeachingNftId = _createTeachingSessionFromCourseType(courseTypeId);
        _payTeachingSeat(customerFaultTeachingNftId);
        _lockTeachingTeacherBond(customerFaultTeachingNftId);
        VM.prank(coordinator);
        teachingRegistry.markTeachingCustomerFault(customerFaultTeachingNftId, 0, 2);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        teachingRegistry.coordinatorCloseTeachingValid(customerFaultTeachingNftId, 3);

        (,,,, uint256 customerFaultRefund,) =
            teachingRegistry.getTeachingSeat(customerFaultTeachingNftId, 0);
        assertEq(customerFaultRefund, expectedRefund);

        uint64 teacherFaultTeachingNftId = _createTeachingSessionFromCourseType(courseTypeId);
        _payTeachingSeat(teacherFaultTeachingNftId);
        _lockTeachingTeacherBond(teacherFaultTeachingNftId);
        VM.warp(block.timestamp + 46 days);
        VM.prank(coordinator);
        teachingRegistry.coordinatorCloseTeachingTeacherFault(teacherFaultTeachingNftId, 4);

        (,,,, uint256 teacherFaultRefund,) =
            teachingRegistry.getTeachingSeat(teacherFaultTeachingNftId, 0);
        assertEq(teacherFaultRefund, expectedRefund);
    }

    function testClassSizeOneCurrentHolderCanClaimResearchReward() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne);
        uint64 teachingNftId =
            _createTeachingSession(RESEARCH_SHARE_BPS, _singleAsset(assetId), _emptyWeights());
        _completeTeachingAsValid(teachingNftId);

        VM.prank(contributorOne);
        researchRegistry.transferResearchPosition(assetId, positionId, contributorTwo);
        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);

        uint256 beforeClaim = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);

        assertEq(stable.balanceOf(contributorTwo) - beforeClaim, 100_000);
        assertEq(
            researchRegistry.getResearchPosition(assetId, positionId).totalClaimedUnits, 100_000
        );
        assertEq(
            researchRegistry.getResearchPositionClaimedUnitsFor(
                assetId, positionId, address(stable)
            ),
            100_000
        );
    }

    function testClassSizeOneBoughtBackRewardRoutesToTreasury() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne);
        uint64 teachingNftId =
            _createTeachingSession(RESEARCH_SHARE_BPS, _singleAsset(assetId), _emptyWeights());
        _completeTeachingAsValid(teachingNftId);

        _fundResearchBuybackVault(250_000);
        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        researchRegistry.sellPositionBackToDao(assetId, positionId);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);

        uint256 treasuryBefore = stable.balanceOf(treasury);
        VM.prank(treasury);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);

        assertEq(stable.balanceOf(treasury) - treasuryBefore, 100_000);
    }

    function testClassSizeOneRepeatRewardClaimReverts() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne);
        uint64 teachingNftId =
            _createTeachingSession(RESEARCH_SHARE_BPS, _singleAsset(assetId), _emptyWeights());
        _completeTeachingAsValid(teachingNftId);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);
        VM.prank(contributorOne);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);

        VM.expectRevert(SparkDaoErrors.TeachingRewardAlreadyClaimed.selector);
        VM.prank(contributorOne);
        distributor.claimTeachingReward(teachingNftId, assetId, positionId);
    }

    function testClassSizeOneRewardBatchAtomicityPreservesFirstClaimOnLaterFailure() public {
        (uint64 assetId, uint64 positionId) = _createReadyResearchAsset(contributorOne);
        uint64 teachingNftId =
            _createTeachingSession(RESEARCH_SHARE_BPS, _singleAsset(assetId), _emptyWeights());
        _completeTeachingAsValid(teachingNftId);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);

        uint64[] memory teachingNftIds = new uint64[](2);
        uint64[] memory assetIds = new uint64[](2);
        uint64[] memory positionIds = new uint64[](2);
        teachingNftIds[0] = teachingNftId;
        teachingNftIds[1] = teachingNftId;
        assetIds[0] = assetId;
        assetIds[1] = 999;
        positionIds[0] = positionId;
        positionIds[1] = positionId;

        VM.expectRevert();
        VM.prank(contributorOne);
        distributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);

        (,, bool claimedAfterFailedBatch) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        assertTrue(!claimedAfterFailedBatch);
    }

    function testClassSizeOneRewardDustReleasesOnceAfterAllSharesClaim() public {
        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = contributorOne;
        beneficiaries[1] = contributorTwo;
        beneficiaries[2] = treasury;
        uint16[] memory shares = new uint16[](3);
        shares[0] = 3_333;
        shares[1] = 3_333;
        shares[2] = 3_334;

        (uint64 assetId, uint64[] memory positionIds) =
            _createReadyResearchAssetWithShares(beneficiaries, shares);
        uint64 teachingNftId = _createTeachingSession(1, _singleAsset(assetId), _emptyWeights());
        _completeTeachingAsValidAndRedeem(teachingNftId);

        (, uint64 unlockAt,) =
            distributor.getTeachingRewardClaimable(teachingNftId, assetId, positionIds[0]);
        VM.warp(unlockAt);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 100);

        uint256 claimedTotal;
        for (uint256 i = 0; i < 3;) {
            uint256 beforeClaim = stable.balanceOf(beneficiaries[i]);
            VM.prank(beneficiaries[i]);
            distributor.claimTeachingReward(teachingNftId, assetId, positionIds[i]);
            claimedTotal += stable.balanceOf(beneficiaries[i]) - beforeClaim;
            unchecked {
                ++i;
            }
        }

        assertEq(claimedTotal, 99);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
        assertEq(stable.balanceOf(address(teachingRegistry)), 599_901);
    }

    function testClassSizeOneReleasedIdleCanBeWithdrawn() public {
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());
        _completeTeachingAsValidAndRedeem(teachingNftId);
        uint256 idle = stable.balanceOf(address(teachingRegistry));
        assertEq(idle, 600_000);

        uint256 authorityBefore = stable.balanceOf(authority);
        VM.prank(authority);
        teachingRegistry.withdrawTeachingIdleFor(address(stable), idle);

        assertEq(stable.balanceOf(authority) - authorityBefore, idle);
        assertEq(stable.balanceOf(address(teachingRegistry)), 0);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), 0);
    }

    function testClassSizeOneUnauthorizedRewardCallbackReverts() public {
        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        teachingRegistry.settleTeachingRewardClaim(address(stable), contributorOne, 1, 1, 1, 0);
    }

    function testClassSizeOneStableAssetFreezeUsesCourseTypeStableAsset() public {
        VM.prank(coordinator);
        uint64 courseTypeId = teachingRegistry.createTeachingCourseType(
            "Frozen Teaching Stable", PRICE_UNITS, TEACHER_SALARY_UNITS, 0
        );
        VM.prank(authority);
        teachingRegistry.updateStableAsset(address(eurc));

        uint64 teachingNftId = _createTeachingSessionFromCourseType(courseTypeId);
        uint256 teacherStableBefore = stable.balanceOf(teacher);
        uint256 studentStableBefore = stable.balanceOf(student);
        uint256 teacherEurcBefore = eurc.balanceOf(teacher);
        uint256 studentEurcBefore = eurc.balanceOf(student);

        _completeTeachingAsValidAndRedeem(teachingNftId);

        assertEq(stable.balanceOf(teacher) - teacherStableBefore, TEACHER_SALARY_UNITS);
        assertEq(studentStableBefore - stable.balanceOf(student), PRICE_UNITS);
        assertEq(eurc.balanceOf(teacher), teacherEurcBefore);
        assertEq(eurc.balanceOf(student), studentEurcBefore);
    }

    function testClassSizeOneAttendanceAndDeliveryAutoCloseWithoutCoordinator() public {
        uint64 teachingNftId = _createTeachingSession(0, _emptyAssetIds(), _emptyWeights());
        _payTeachingSeat(teachingNftId);
        _lockTeachingTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(student);
        teachingRegistry.confirmTeachingAttendance(teachingNftId, 0);
        (uint8 beforeDeliveryStatus,,,,,,,,,,,) =
            teachingRegistry.getTeachingSessionState(teachingNftId);
        assertEq(beforeDeliveryStatus, 0);

        VM.prank(teacher);
        teachingRegistry.confirmTeachingDelivery(teachingNftId);

        (uint8 status,,,,,,,,,,,) = teachingRegistry.getTeachingSessionState(teachingNftId);
        assertEq(status, 1);
        assertEq(teachingRegistry.getVaultReservedUnits(address(stable)), TEACHER_SALARY_UNITS);
    }

    function _createTeachingSession(
        uint16 researchShareBps,
        uint64[] memory linkedAssetIds,
        uint16[] memory linkedWeights
    ) internal returns (uint64 teachingNftId) {
        VM.prank(coordinator);
        uint64 courseTypeId = teachingRegistry.createTeachingCourseType(
            "One Seat Teaching", PRICE_UNITS, TEACHER_SALARY_UNITS, researchShareBps
        );
        teachingNftId = _createTeachingSessionFromCourseType(
            courseTypeId, linkedAssetIds, linkedWeights, 10_000
        );
    }

    function _createTeachingSessionWithDiscount(
        uint16 customerDiscountBps,
        uint16 researchShareBps,
        uint64[] memory linkedAssetIds,
        uint16[] memory linkedWeights
    ) internal returns (uint64 teachingNftId) {
        VM.prank(coordinator);
        uint64 courseTypeId = teachingRegistry.createTeachingCourseType(
            "One Seat Teaching", PRICE_UNITS, TEACHER_SALARY_UNITS, researchShareBps
        );
        teachingNftId = _createTeachingSessionFromCourseType(
            courseTypeId, linkedAssetIds, linkedWeights, customerDiscountBps
        );
    }

    function _createTeachingSessionFromCourseType(uint64 courseTypeId)
        internal
        returns (uint64 teachingNftId)
    {
        teachingNftId = _createTeachingSessionFromCourseType(
            courseTypeId, _emptyAssetIds(), _emptyWeights(), 10_000
        );
    }

    function _createTeachingSessionFromCourseType(
        uint64 courseTypeId,
        uint64[] memory linkedAssetIds,
        uint16[] memory linkedWeights,
        uint16 customerDiscountBps
    ) internal returns (uint64 teachingNftId) {
        address[] memory students = new address[](1);
        students[0] = student;
        VM.prank(coordinator);
        teachingNftId = teachingRegistry.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: customerDiscountBps,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: linkedWeights
            })
        );
        _confirmTeachingSchedule(teachingNftId);
    }

    function _confirmTeachingSchedule(uint64 teachingNftId) internal {
        VM.prank(teacher);
        teachingRegistry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(coordinator);
        teachingRegistry.confirmTeachingSchedule(teachingNftId, false);
    }

    function _payTeachingSeat(uint64 teachingNftId) internal {
        VM.startPrank(student);
        stable.approve(address(teachingRegistry), type(uint256).max);
        teachingRegistry.payTeachingSeat(teachingNftId, 0);
        VM.stopPrank();
    }

    function _lockTeachingTeacherBond(uint64 teachingNftId) internal {
        VM.startPrank(teacher);
        stable.approve(address(teachingRegistry), type(uint256).max);
        teachingRegistry.lockTeachingTeacherBond(teachingNftId);
        VM.stopPrank();
    }

    function _completeTeachingAsValid(uint64 teachingNftId) internal {
        _payTeachingSeat(teachingNftId);
        _lockTeachingTeacherBond(teachingNftId);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        teachingRegistry.coordinatorCloseTeachingValid(teachingNftId, 1);
    }

    function _completeTeachingAsValidAndRedeem(uint64 teachingNftId) internal {
        _completeTeachingAsValid(teachingNftId);
        VM.prank(teacher);
        teachingRegistry.redeemTeachingTeacherPayout(teachingNftId);
    }

    function _createReadyResearchAsset(address beneficiary)
        internal
        returns (uint64 assetId, uint64 positionId)
    {
        VM.startPrank(coordinator);
        assetId = researchRegistry.createResearchAsset("One Seat Research", "ipfs://one-seat");
        positionId = researchRegistry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: beneficiary
            })
        );
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();
    }

    function _createReadyResearchAssetWithShares(
        address[] memory beneficiaries,
        uint16[] memory shares
    ) internal returns (uint64 assetId, uint64[] memory positionIds) {
        VM.startPrank(coordinator);
        assetId = researchRegistry.createResearchAsset("One Seat Research", "ipfs://one-seat");
        uint256 positionCount = beneficiaries.length;
        positionIds = new uint64[](positionCount);
        for (uint256 i = 0; i < positionCount;) {
            positionIds[i] = researchRegistry.createPatchPosition(
                SparkDaoTypes.CreatePatchPositionParams({
                    assetId: assetId,
                    layerIndex: 1,
                    layerShareBps: shares[i],
                    buybackFloor: 250_000,
                    decayWaitSeconds: 365 days,
                    decayPeriodSeconds: 365 days,
                    decayRateBps: 5_000,
                    beneficiary: beneficiaries[i]
                })
            );
            unchecked {
                ++i;
            }
        }
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();
    }

    function _fundResearchBuybackVault(uint256 amount) internal {
        VM.startPrank(authority);
        stable.approve(address(researchRegistry), amount);
        researchRegistry.fundDaoVault(amount);
        VM.stopPrank();
    }

    function _singleAsset(uint64 assetId) internal pure returns (uint64[] memory assetIds) {
        assetIds = new uint64[](1);
        assetIds[0] = assetId;
    }

    function _emptyAssetIds() internal pure returns (uint64[] memory values) {
        values = new uint64[](0);
    }

    function _emptyWeights() internal pure returns (uint16[] memory values) {
        values = new uint16[](0);
    }

    function assertEq(uint256 left, uint256 right) internal pure {
        if (left != right) revert("assert eq failed");
    }

    function assertEq(address left, address right) internal pure {
        if (left != right) revert("assert eq failed");
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }
}
