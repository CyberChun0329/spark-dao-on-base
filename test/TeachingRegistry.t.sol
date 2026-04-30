// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert() external;
}

contract TeachingRegistryTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    TeachingRegistry internal registry;
    TeachingNftToken internal teachingToken;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal teacher = address(0x7001);
    address internal customer = address(0x7002);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);
    address internal contributorThree = address(0x1003);
    address internal contributorFour = address(0x1004);

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://teaching/");
        registry = new TeachingRegistry(
            authority,
            coordinator,
            address(stable),
            90 days,
            30 days,
            address(researchToken),
            address(teachingToken)
        );
        VM.prank(authority);
        researchToken.setMinter(address(registry));
        VM.prank(authority);
        teachingToken.setMinter(address(registry));

        stable.mint(authority, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(customer, 1_000_000_000);
    }

    function testCreateCourseTypeAndFreezeRoundOne() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Linear Algebra", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        (uint8 status, bool firstRoundFrozen,,,,) = registry.getTeachingSessionState(teachingNftId);
        assertTrue(firstRoundFrozen);
        assertTrue(status == 1);
        assertTrue(teachingToken.ownerOf(teachingNftId) == teacher);
        assertTrue(teachingToken.balanceOf(teacher) == 1);
    }

    function testTeachingResearchShareCannotExceedFaultSolvencyCap() public {
        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingCourseType("Overlinked Course", 1_000_000, 400_000, 2_501);
    }

    function testNoResearchTeachingLifecycleCompletesAndRedeems() public {
        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType("Geometry", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (uint8 resolvedStatus,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(resolvedStatus == 2);
        assertTrue(distributionRecorded);

        uint256 beforeRedeem = stable.balanceOf(teacher);
        VM.warp(block.timestamp + 31 days);
        VM.prank(teacher);
        registry.redeemTeachingPayout(teachingNftId);
        uint256 afterRedeem = stable.balanceOf(teacher);

        (uint8 redeemedStatus,,,,, uint64 redeemedAt) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(redeemedStatus == 7);
        assertTrue(redeemedAt != 0);
        assertTrue(afterRedeem == beforeRedeem + 400_000);
    }

    function testTeachingAcknowledgeThenCounterpartyConfirmSettles() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Ack Geometry", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.acknowledgeTeachingCompletion(teachingNftId, true);

        (uint8 ackStatus,, bool collateralLocked, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(ackStatus == 1);
        assertTrue(collateralLocked);
        assertTrue(!distributionRecorded);

        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (uint8 settledStatus,,, bool settledDistributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(settledStatus == 2);
        assertTrue(settledDistributionRecorded);
    }

    function testTeachingAcknowledgeRejectsAfterCounterpartyAlreadySigned() public {
        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType("Ack Reject", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);

        VM.expectRevert();
        VM.prank(customer);
        registry.acknowledgeTeachingCompletion(teachingNftId, false);

        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (uint8 status,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 2);
        assertTrue(distributionRecorded);
    }

    function testCustomerFirstAcknowledgeResearchBackedTeachingStillSnapshotsRewards() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Ack Research", "ipfs://ack-research");
        uint64 layerOnePositionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 layerOnePositionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetId, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Customer Ack Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        registry.markPositionReady(assetId, layerOnePositionA);
        registry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.prank(customer);
        registry.acknowledgeTeachingCompletion(teachingNftId, false);

        (uint8 ackStatus,, bool collateralLocked, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(ackStatus == 1);
        assertTrue(collateralLocked);
        assertTrue(!distributionRecorded);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);

        (uint8 status,,, bool settledDistributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 2);
        assertTrue(settledDistributionRecorded);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 1);
        assertTrue(settlementLayers[0] == 1);

        (, uint256[] memory amountsA) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionA);
        (, uint256[] memory amountsB) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionB);
        assertTrue(amountsA[0] == 120_000);
        assertTrue(amountsB[0] == 80_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, layerTwoPosition);
    }

    function testLinkedResearchWithZeroShareSkipsDistributionCleanly() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Zero Share Asset", "ipfs://zero-share-asset");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Zero Share Seminar", 1_000_000, 400_000, 0);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (uint8 status,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(status == 2);
        assertTrue(distributionRecorded);
        assertTrue(settlementLayers.length == 0);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, positionId);
    }

    function testImmediateTeachingRewardClaimWhenUnlockZero() public {
        VM.prank(authority);
        registry.updateRewardUnlockSeconds(0);

        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Immediate Reward", "ipfs://immediate-reward");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Immediate Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        (uint64[] memory unlocks, uint256[] memory amounts) =
            registry.getTeachingRewardLedgerBuckets(assetId, positionId);
        assertTrue(unlocks.length == 1);
        assertTrue(unlocks[0] == block.timestamp);
        assertTrue(amounts[0] == 200_000);

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, positionId);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 200_000);
    }

    function testCoordinatorTeacherFaultKeepsHalfPriceAndOwesRemedialLesson() public {
        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType("Calculus", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 2 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 33 days);

        uint256 beforeRefund = stable.balanceOf(customer);
        uint256 beforeTeacher = stable.balanceOf(teacher);
        VM.prank(coordinator);
        registry.coordinatorResolveTeacherFault(teachingNftId, 4);
        uint256 afterRefund = stable.balanceOf(customer);
        uint256 afterTeacher = stable.balanceOf(teacher);

        (uint8 status,,,, uint64 resolvedAt,) = registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 4);
        assertTrue(resolvedAt != 0);
        assertTrue(afterRefund == beforeRefund + 400_000);
        assertTrue(afterTeacher == beforeTeacher + 800_000);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 1);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 0);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 400_000);
    }

    function testCoordinatorCustomerFaultKeepsHalfPriceAndPaysTeacherTime() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Customer Fault", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 2 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 33 days);

        uint256 beforeRefund = stable.balanceOf(customer);
        uint256 beforeTeacher = stable.balanceOf(teacher);
        VM.prank(coordinator);
        registry.coordinatorResolveCustomerFault(teachingNftId, 2);
        uint256 afterRefund = stable.balanceOf(customer);
        uint256 afterTeacher = stable.balanceOf(teacher);

        (uint8 status,,,, uint64 resolvedAt,) = registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 5);
        assertTrue(resolvedAt != 0);
        assertTrue(afterRefund == beforeRefund + 400_000);
        assertTrue(afterTeacher == beforeTeacher + 1_200_000);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 0);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 400_000);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 0);
    }

    function testResearchBackedTeachingDistributesSnapshotRewards() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Research Core", "ipfs://research-core");
        uint64 layerOnePositionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 layerOnePositionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetId, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Research Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        registry.markPositionReady(assetId, layerOnePositionA);
        registry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (uint8 status,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 2);
        assertTrue(distributionRecorded);
        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 1);
        assertTrue(settlementLayers[0] == 1);

        (uint64[] memory unlocksA, uint256[] memory amountsA) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionA);
        (uint64[] memory unlocksB, uint256[] memory amountsB) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionB);
        assertTrue(unlocksA.length == 1);
        assertTrue(amountsA[0] == 120_000);
        assertTrue(unlocksB.length == 1);
        assertTrue(amountsB[0] == 80_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, layerTwoPosition);

        VM.warp(block.timestamp + 91 days);

        uint256 contributorOneBefore = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, layerOnePositionA);
        uint256 contributorOneAfter = stable.balanceOf(contributorOne);
        assertTrue(contributorOneAfter == contributorOneBefore + 120_000);

        uint256 contributorTwoBefore = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        registry.claimTeachingReward(assetId, layerOnePositionB);
        uint256 contributorTwoAfter = stable.balanceOf(contributorTwo);
        assertTrue(contributorTwoAfter == contributorTwoBefore + 80_000);
    }

    function testScheduledSnapshotIgnoresResearchUpdatesBeforeCompletion() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Layered Research", "ipfs://layered-research");
        uint64 layerOnePositionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 layerOnePositionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetId, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Snapshot Theory", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        registry.markPositionReady(assetId, layerOnePositionA);
        registry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers[0] == 1);

        (, uint256[] memory amounts) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionA);
        assertTrue(amounts[0] == 120_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, layerTwoPosition);
    }

    function testTransferredResearchPositionLetsNewHolderClaimTeachingReward() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            registry.createResearchAsset("Transferable Research", "ipfs://transferable");
        uint64 layerOnePosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Transfer Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        VM.prank(contributorOne);
        registry.transferResearchPosition(assetId, layerOnePosition, contributorTwo);
        assertTrue(
            researchToken.ownerOf(_researchTokenId(assetId, layerOnePosition)) == contributorTwo
        );

        VM.warp(block.timestamp + 91 days);

        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, layerOnePosition);

        uint256 beforeClaim = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        registry.claimTeachingReward(assetId, layerOnePosition);
        uint256 afterClaim = stable.balanceOf(contributorTwo);
        assertTrue(afterClaim == beforeClaim + 200_000);
    }

    function testBoughtBackResearchPositionLetsDaoClaimTeachingReward() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Dao Buyback Research", "ipfs://dao-buyback");
        uint64 layerOnePosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Buyback Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        VM.prank(authority);
        assertTrue(stable.transfer(address(registry), 500_000));

        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(assetId, layerOnePosition);
        assertTrue(researchToken.ownerOf(_researchTokenId(assetId, layerOnePosition)) == authority);

        VM.warp(block.timestamp + 91 days);

        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, layerOnePosition);

        uint256 beforeClaim = stable.balanceOf(authority);
        VM.prank(authority);
        registry.claimTeachingReward(assetId, layerOnePosition);
        uint256 afterClaim = stable.balanceOf(authority);
        assertTrue(afterClaim == beforeClaim + 200_000);
    }

    function testResearchForceValidStillDistributesSnapshotRewards() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Forced Research", "ipfs://forced-research");
        uint64 layerOnePositionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 layerOnePositionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Coordinator Rescue", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 3 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 34 days);
        VM.prank(coordinator);
        registry.coordinatorForceTeachingValid(teachingNftId, 3);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 1);
        assertTrue(settlementLayers[0] == 1);

        (, uint256[] memory amountsA) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionA);
        (, uint256[] memory amountsB) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionB);
        assertTrue(amountsA[0] == 120_000);
        assertTrue(amountsB[0] == 80_000);
    }

    function testWeightedMultiAssetTeachingDistribution() public {
        VM.startPrank(coordinator);
        uint64 assetOne = registry.createResearchAsset("Asset One", "ipfs://asset-one");
        uint64 positionOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetOne, 1);

        uint64 assetTwo = registry.createResearchAsset("Asset Two", "ipfs://asset-two");
        uint64 positionTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetTwo, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Weighted Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](2);
        linkedAssetIds[0] = assetOne;
        linkedAssetIds[1] = assetTwo;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 7_000;
        weights[1] = 3_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        (, uint256[] memory amountsOne) =
            registry.getTeachingRewardLedgerBuckets(assetOne, positionOne);
        (, uint256[] memory amountsTwo) =
            registry.getTeachingRewardLedgerBuckets(assetTwo, positionTwo);
        assertTrue(amountsOne.length == 1);
        assertTrue(amountsTwo.length == 1);
        assertTrue(amountsOne[0] == 140_000);
        assertTrue(amountsTwo[0] == 60_000);
    }

    function testBatchTeachingRewardClaim() public {
        VM.startPrank(coordinator);
        uint64 assetOne = registry.createResearchAsset("Batch One", "ipfs://batch-one");
        uint64 positionOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetOne, 1);

        uint64 assetTwo = registry.createResearchAsset("Batch Two", "ipfs://batch-two");
        uint64 positionTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetTwo, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Batch Claim Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](2);
        linkedAssetIds[0] = assetOne;
        linkedAssetIds[1] = assetTwo;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 6_000;
        weights[1] = 4_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);
        VM.warp(block.timestamp + 91 days);

        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetOne;
        assetIds[1] = assetTwo;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimTeachingRewardBatch(assetIds, positionIds);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 200_000);
    }

    function testDustTeachingRewardSkipsZeroAmountPositions() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Dust Asset", "ipfs://dust-asset");
        uint64 positionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 9_000,
                buybackFloor: 10,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 positionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 1_000,
                buybackFloor: 10,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType("Dust Seminar", 12, 1, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 10_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        (, uint256[] memory amountsA) = registry.getTeachingRewardLedgerBuckets(assetId, positionA);
        assertTrue(amountsA.length == 1);
        assertTrue(amountsA[0] == 2);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, positionB);
    }

    function testBatchTeachingRewardRejectsDuplicateEntries() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Duplicate Batch", "ipfs://duplicate-batch");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Duplicate Batch Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);
        VM.warp(block.timestamp + 91 days);

        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetId;
        assetIds[1] = assetId;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionId;
        positionIds[1] = positionId;

        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingRewardBatch(assetIds, positionIds);

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, positionId);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 200_000);
    }

    function testBatchTeachingRewardRejectsMixedHolders() public {
        VM.startPrank(coordinator);
        uint64 assetOne = registry.createResearchAsset("Mixed Batch One", "ipfs://mixed-batch-one");
        uint64 positionOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetOne, 1);

        uint64 assetTwo = registry.createResearchAsset("Mixed Batch Two", "ipfs://mixed-batch-two");
        uint64 positionTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetTwo, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Mixed Holder Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](2);
        linkedAssetIds[0] = assetOne;
        linkedAssetIds[1] = assetTwo;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 5_000;
        weights[1] = 5_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopPrank();

        _completeTeachingLifecycle(teachingNftId);

        VM.prank(contributorOne);
        registry.transferResearchPosition(assetTwo, positionTwo, contributorTwo);

        VM.warp(block.timestamp + 91 days);

        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetOne;
        assetIds[1] = assetTwo;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingRewardBatch(assetIds, positionIds);

        uint256 oneBefore = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetOne, positionOne);
        uint256 oneAfter = stable.balanceOf(contributorOne);
        assertTrue(oneAfter == oneBefore + 100_000);

        uint256 twoBefore = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        registry.claimTeachingReward(assetTwo, positionTwo);
        uint256 twoAfter = stable.balanceOf(contributorTwo);
        assertTrue(twoAfter == twoBefore + 100_000);
    }

    function testMultiAssetMultiLayerDistributionConservesTotalValue() public {
        VM.startPrank(coordinator);
        uint64 assetOne =
            registry.createResearchAsset("Conservation One", "ipfs://conservation-one");
        uint64 assetOneLayerOneA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 assetOneLayerOneB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetOne, 1);
        uint64 assetOneLayerTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetOne, 2);

        uint64 assetTwo =
            registry.createResearchAsset("Conservation Two", "ipfs://conservation-two");
        uint64 assetTwoLayerOneA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 7_500,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        uint64 assetTwoLayerOneB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 2_500,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorFour
            })
        );
        registry.sealLayer(assetTwo, 1);
        uint64 assetTwoLayerTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: customer
            })
        );
        registry.sealLayer(assetTwo, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Conservation Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](2);
        linkedAssetIds[0] = assetOne;
        linkedAssetIds[1] = assetTwo;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 7_000;
        weights[1] = 3_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        registry.markPositionReady(assetOne, assetOneLayerOneA);
        registry.markPositionReady(assetOne, assetOneLayerOneB);
        uint64[] memory assetOnePrepared = new uint64[](1);
        assetOnePrepared[0] = assetOneLayerTwo;
        registry.advanceLayer(assetOne, assetOnePrepared);

        registry.markPositionReady(assetTwo, assetTwoLayerOneA);
        registry.markPositionReady(assetTwo, assetTwoLayerOneB);
        uint64[] memory assetTwoPrepared = new uint64[](1);
        assetTwoPrepared[0] = assetTwoLayerTwo;
        registry.advanceLayer(assetTwo, assetTwoPrepared);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        (, uint256[] memory assetOneAmountsA) =
            registry.getTeachingRewardLedgerBuckets(assetOne, assetOneLayerOneA);
        (, uint256[] memory assetOneAmountsB) =
            registry.getTeachingRewardLedgerBuckets(assetOne, assetOneLayerOneB);
        (, uint256[] memory assetTwoAmountsA) =
            registry.getTeachingRewardLedgerBuckets(assetTwo, assetTwoLayerOneA);
        (, uint256[] memory assetTwoAmountsB) =
            registry.getTeachingRewardLedgerBuckets(assetTwo, assetTwoLayerOneB);

        uint256 totalDistributed =
            assetOneAmountsA[0] + assetOneAmountsB[0] + assetTwoAmountsA[0] + assetTwoAmountsB[0];
        assertTrue(assetOneAmountsA[0] == 84_000);
        assertTrue(assetOneAmountsB[0] == 56_000);
        assertTrue(assetTwoAmountsA[0] == 45_000);
        assertTrue(assetTwoAmountsB[0] == 15_000);
        assertTrue(totalDistributed == 200_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetOne, assetOneLayerTwo);
        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetTwo, assetTwoLayerTwo);
    }

    function testPastDeadlineResearchBackedTeachingNeedsCoordinatorAndKeepsSnapshot() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Timeout Research", "ipfs://timeout-research");
        uint64 layerOnePositionA = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 layerOnePositionB = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetId, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Timeout Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        registry.markPositionReady(assetId, layerOnePositionA);
        registry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.warp(block.timestamp + 31 days);

        VM.expectRevert();
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);

        VM.prank(coordinator);
        registry.coordinatorForceTeachingValid(teachingNftId, 3);

        (uint8 status,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 3);
        assertTrue(distributionRecorded);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 1);
        assertTrue(settlementLayers[0] == 1);

        (, uint256[] memory amountsA) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionA);
        (, uint256[] memory amountsB) =
            registry.getTeachingRewardLedgerBuckets(assetId, layerOnePositionB);
        assertTrue(amountsA[0] == 120_000);
        assertTrue(amountsB[0] == 80_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, layerTwoPosition);
    }

    function testTeacherFaultUsesHalfPriceToFundTwoResearchShares() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Fault Research", "ipfs://fault-research");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Fault Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 2 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 33 days);
        uint256 beforeRefund = stable.balanceOf(customer);
        uint256 beforeTeacher = stable.balanceOf(teacher);

        VM.prank(coordinator);
        registry.coordinatorResolveTeacherFault(teachingNftId, 4);

        uint256 afterRefund = stable.balanceOf(customer);
        uint256 afterTeacher = stable.balanceOf(teacher);
        (uint8 status,,, bool distributionRecorded,,) =
            registry.getTeachingSessionState(teachingNftId);
        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);

        assertTrue(status == 4);
        assertTrue(distributionRecorded);
        assertTrue(settlementLayers.length == 1);
        assertTrue(settlementLayers[0] == 1);
        assertTrue(afterRefund == beforeRefund + 400_000);
        assertTrue(afterTeacher == beforeTeacher + 800_000);

        (, uint256[] memory amounts) = registry.getTeachingRewardLedgerBuckets(assetId, positionId);
        assertTrue(amounts[0] == 400_000);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 1);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 0);
        assertTrue(researchRewardUnits == 400_000);
        assertTrue(serviceReserveUnits == 0);
    }

    function testForceValidPreservesWeightedHistoricalSnapshot() public {
        VM.startPrank(coordinator);
        uint64 assetOne = registry.createResearchAsset("Force Asset One", "ipfs://force-asset-one");
        uint64 assetOneLayerOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetOne, 1);
        uint64 assetOneLayerTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorThree
            })
        );
        registry.sealLayer(assetOne, 2);

        uint64 assetTwo = registry.createResearchAsset("Force Asset Two", "ipfs://force-asset-two");
        uint64 assetTwoLayerOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetTwo, 1);
        uint64 assetTwoLayerTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: contributorFour
            })
        );
        registry.sealLayer(assetTwo, 2);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Force Weighted Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](2);
        linkedAssetIds[0] = assetOne;
        linkedAssetIds[1] = assetTwo;
        uint16[] memory weights = new uint16[](2);
        weights[0] = 7_000;
        weights[1] = 3_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopPrank();

        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        uint64[] memory preparedOne = new uint64[](1);
        preparedOne[0] = assetOneLayerTwo;
        registry.markPositionReady(assetOne, assetOneLayerOne);
        registry.advanceLayer(assetOne, preparedOne);

        uint64[] memory preparedTwo = new uint64[](1);
        preparedTwo[0] = assetTwoLayerTwo;
        registry.markPositionReady(assetTwo, assetTwoLayerOne);
        registry.advanceLayer(assetTwo, preparedTwo);

        VM.warp(block.timestamp + 31 days);
        VM.prank(coordinator);
        registry.coordinatorForceTeachingValid(teachingNftId, 3);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 2);
        assertTrue(settlementLayers[0] == 1);
        assertTrue(settlementLayers[1] == 1);

        (, uint256[] memory assetOneAmounts) =
            registry.getTeachingRewardLedgerBuckets(assetOne, assetOneLayerOne);
        (, uint256[] memory assetTwoAmounts) =
            registry.getTeachingRewardLedgerBuckets(assetTwo, assetTwoLayerOne);
        assertTrue(assetOneAmounts[0] == 140_000);
        assertTrue(assetTwoAmounts[0] == 60_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetOne, assetOneLayerTwo);
        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetTwo, assetTwoLayerTwo);
    }

    function testTeachingRewardLedgerSupportsStagedClaims() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Bucket Research", "ipfs://bucket-research");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Bucket Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingOne = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        uint64 teachingTwo = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 9 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _prepareTeachingSession(teachingOne);
        _prepareTeachingSession(teachingTwo);

        VM.warp(block.timestamp + 8 days);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingOne, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingOne, false);

        VM.warp(block.timestamp + 2 days);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingTwo, false);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingTwo, true);

        (uint64[] memory unlocks, uint256[] memory amounts) =
            registry.getTeachingRewardLedgerBuckets(assetId, positionId);
        assertTrue(unlocks.length == 2);
        assertTrue(amounts[0] == 200_000);
        assertTrue(amounts[1] == 200_000);
        assertTrue(unlocks[1] > unlocks[0]);

        uint256 beforeFirstClaim = stable.balanceOf(contributorOne);
        VM.warp(unlocks[0]);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, positionId);
        uint256 afterFirstClaim = stable.balanceOf(contributorOne);
        assertTrue(afterFirstClaim == beforeFirstClaim + 200_000);

        (, uint256[] memory remainingAmounts) =
            registry.getTeachingRewardLedgerBuckets(assetId, positionId);
        assertTrue(remainingAmounts.length == 1);
        assertTrue(remainingAmounts[0] == 200_000);

        uint256 beforeSecondClaim = stable.balanceOf(contributorOne);
        VM.warp(unlocks[1]);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, positionId);
        uint256 afterSecondClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSecondClaim == beforeSecondClaim + 200_000);

        VM.expectRevert();
        registry.getTeachingRewardLedgerBuckets(assetId, positionId);
    }

    function testBatchTeachingRewardClaimRevertsWhenOneLedgerIsLocked() public {
        VM.startPrank(coordinator);
        uint64 assetOne = registry.createResearchAsset("Atomic One", "ipfs://atomic-one");
        uint64 positionOne = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetOne,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetOne, 1);

        uint64 assetTwo = registry.createResearchAsset("Atomic Two", "ipfs://atomic-two");
        uint64 positionTwo = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetTwo,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetTwo, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Atomic Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory oneAsset = new uint64[](1);
        oneAsset[0] = assetOne;
        uint64 teachingOne = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: oneAsset,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        uint64[] memory twoAsset = new uint64[](1);
        twoAsset[0] = assetTwo;
        uint64 teachingTwo = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 9 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: twoAsset,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _prepareTeachingSession(teachingOne);
        _prepareTeachingSession(teachingTwo);

        VM.warp(block.timestamp + 8 days);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingOne, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingOne, false);

        VM.warp(block.timestamp + 2 days);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingTwo, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingTwo, false);

        (uint64[] memory unlocksOne,) =
            registry.getTeachingRewardLedgerBuckets(assetOne, positionOne);
        (uint64[] memory unlocksTwo,) =
            registry.getTeachingRewardLedgerBuckets(assetTwo, positionTwo);
        assertTrue(unlocksTwo[0] > unlocksOne[0]);

        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetOne;
        assetIds[1] = assetTwo;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        uint256 beforeBatch = stable.balanceOf(contributorOne);
        VM.warp(unlocksOne[0]);
        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingRewardBatch(assetIds, positionIds);
        uint256 afterFailedBatch = stable.balanceOf(contributorOne);
        assertTrue(afterFailedBatch == beforeBatch);

        VM.prank(contributorOne);
        registry.claimTeachingReward(assetOne, positionOne);
        uint256 afterSingleClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSingleClaim == beforeBatch + 200_000);

        VM.expectRevert();
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetTwo, positionTwo);

        VM.warp(unlocksTwo[0]);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetTwo, positionTwo);
        uint256 afterSecondClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSecondClaim == beforeBatch + 400_000);
    }

    function testVaultReservedUnitsTrackTeachingSettlementFlow() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            registry.createResearchAsset("Reserved Research", "ipfs://reserved-research");
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Reserved Seminar", 1_000_000, 400_000, 2_500);
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        VM.stopPrank();

        _prepareTeachingSession(teachingNftId);

        SparkDaoTypes.DaoState memory daoAfterCollateral = registry.getDaoState();
        assertTrue(daoAfterCollateral.vaultReservedUnits == 1_600_000);
        assertTrue(stable.balanceOf(address(registry)) == 1_600_000);

        VM.warp(block.timestamp + 8 days);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        SparkDaoTypes.DaoState memory daoAfterSettlement = registry.getDaoState();
        assertTrue(daoAfterSettlement.vaultReservedUnits == 600_000);
        assertTrue(stable.balanceOf(address(registry)) == 800_000);
        assertTrue(
            stable.balanceOf(address(registry)) - daoAfterSettlement.vaultReservedUnits == 200_000
        );

        VM.warp(block.timestamp + 31 days);
        VM.prank(teacher);
        registry.redeemTeachingPayout(teachingNftId);

        SparkDaoTypes.DaoState memory daoAfterRedeem = registry.getDaoState();
        assertTrue(daoAfterRedeem.vaultReservedUnits == 200_000);
        assertTrue(stable.balanceOf(address(registry)) == 400_000);
        assertTrue(
            stable.balanceOf(address(registry)) - daoAfterRedeem.vaultReservedUnits == 200_000
        );

        (uint64[] memory unlocks,) = registry.getTeachingRewardLedgerBuckets(assetId, positionId);
        VM.warp(unlocks[0]);
        VM.prank(contributorOne);
        registry.claimTeachingReward(assetId, positionId);

        SparkDaoTypes.DaoState memory daoAfterRewardClaim = registry.getDaoState();
        assertTrue(daoAfterRewardClaim.vaultReservedUnits == 0);
        assertTrue(stable.balanceOf(address(registry)) == 200_000);
    }

    function _prepareTeachingSession(uint64 teachingNftId) internal {
        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function _completeTeachingLifecycle(uint64 teachingNftId) internal {
        _prepareTeachingSession(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }

    function _researchTokenId(uint64 assetId, uint64 positionId) internal pure returns (uint256) {
        return (uint256(assetId) << 64) | uint256(positionId);
    }
}
