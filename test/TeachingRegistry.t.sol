// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { ResearchRegistry } from "../src/ResearchRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";
import { TeachingEconomicsPolicyV1 } from "../src/TeachingEconomicsPolicyV1.sol";
import { TeachingFaultPolicyV1 } from "../src/TeachingFaultPolicyV1.sol";
import { TeachingPolicyGuard } from "../src/TeachingPolicyGuard.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkDaoErrors } from "../src/SparkDaoErrors.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockTeachingEconomicsPolicy } from "./mocks/MockTeachingEconomicsPolicy.sol";
import {
    MockTeachingFaultPolicy,
    MutableTeachingFaultPolicy
} from "./mocks/MockTeachingFaultPolicy.sol";

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

    TeachingRegistry internal registry;
    ResearchRegistry internal researchRegistry;
    ResearchRegistry internal auxResearchRegistry;
    TeachingRewardDistributor internal rewardDistributor;
    TeachingEconomicsPolicyV1 internal economicsPolicy;
    TeachingFaultPolicyV1 internal faultPolicy;
    TeachingPolicyGuard internal policyGuard;
    TeachingNftToken internal teachingToken;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;
    MockERC20 internal eurc;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal treasury = address(0xDA01);
    address internal teacher = address(0x7001);
    address internal customer = address(0x7002);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);
    address internal contributorThree = address(0x1003);
    address internal contributorFour = address(0x1004);
    uint16 internal constant SAFE_RESEARCH_SHARE_BPS = 1_000;

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        eurc = new MockERC20("Euro Coin", "EURC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://teaching/");
        economicsPolicy = new TeachingEconomicsPolicyV1();
        faultPolicy = new TeachingFaultPolicyV1();
        policyGuard = new TeachingPolicyGuard();
        researchRegistry = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );
        registry = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchRegistry),
            address(teachingToken),
            address(policyGuard),
            address(economicsPolicy),
            address(faultPolicy)
        );
        rewardDistributor =
            new TeachingRewardDistributor(address(registry), address(researchRegistry));
        VM.prank(authority);
        researchRegistry.setTeachingRegistry(address(registry));
        VM.prank(authority);
        registry.setTeachingRewardDistributor(address(rewardDistributor));
        VM.prank(authority);
        researchToken.setMinter(address(researchRegistry));
        VM.prank(authority);
        teachingToken.setMinter(address(registry));

        stable.mint(authority, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(customer, 1_000_000_000);
        eurc.mint(authority, 1_000_000_000);
        eurc.mint(teacher, 1_000_000_000);
        eurc.mint(customer, 1_000_000_000);
    }

    function testSetTeachingRewardDistributorRequiresAuthorityNonZeroAndOneTime() public {
        TeachingRegistry unwired = _deployUnwiredRegistry();
        TeachingRewardDistributor matchingDistributor =
            new TeachingRewardDistributor(address(unwired), address(auxResearchRegistry));

        VM.expectRevert(SparkDaoErrors.UnauthorizedAuthority.selector);
        VM.prank(coordinator);
        unwired.setTeachingRewardDistributor(address(matchingDistributor));

        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        VM.prank(authority);
        unwired.setTeachingRewardDistributor(address(0));

        VM.prank(authority);
        unwired.setTeachingRewardDistributor(address(matchingDistributor));

        TeachingRewardDistributor secondMatchingDistributor =
            new TeachingRewardDistributor(address(unwired), address(auxResearchRegistry));
        VM.expectRevert(SparkDaoErrors.TeachingRewardDistributorAlreadySet.selector);
        VM.prank(authority);
        unwired.setTeachingRewardDistributor(address(secondMatchingDistributor));
    }

    function testSetTeachingRewardDistributorRejectsMismatchedOrNonContractDistributor() public {
        TeachingRegistry unwired = _deployUnwiredRegistry();
        TeachingRewardDistributor wrongDistributor =
            new TeachingRewardDistributor(address(registry), address(researchRegistry));

        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        VM.prank(authority);
        unwired.setTeachingRewardDistributor(address(wrongDistributor));

        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        VM.prank(authority);
        unwired.setTeachingRewardDistributor(address(0xBEEF));
    }

    function testSetTeachingRegistryRequiresAuthorityValidHandshakeAndOneTime() public {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();
        TeachingRegistry matchingRegistry =
            _deployRegistryWithPolicyOnly(address(faultPolicy), linkedResearch);

        VM.expectRevert(SparkDaoErrors.UnauthorizedAuthority.selector);
        VM.prank(coordinator);
        linkedResearch.setTeachingRegistry(address(matchingRegistry));

        VM.expectRevert(SparkDaoErrors.InvalidResearchRegistry.selector);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(0));

        VM.expectRevert(SparkDaoErrors.InvalidResearchRegistry.selector);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(0xBEEF));

        ResearchRegistry otherResearch = _deployAuxResearchRegistry();
        TeachingRegistry mismatchedRegistry =
            _deployRegistryWithPolicyOnly(address(faultPolicy), otherResearch);
        VM.expectRevert(SparkDaoErrors.InvalidResearchRegistry.selector);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(mismatchedRegistry));

        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(matchingRegistry));

        VM.expectRevert(SparkDaoErrors.TeachingRegistryAlreadySet.selector);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(matchingRegistry));
    }

    function testTeachingModuleStateExposesWiringAndPolicies() public view {
        (
            address researchRegistryAddress,
            address teachingTokenAddress,
            address policyGuardAddress,
            address economicsPolicyAddress,
            address faultPolicyAddress,
            uint8 faultPolicyVersion,
            address rewardDistributorAddress
        ) = registry.getTeachingModuleState();

        assertTrue(researchRegistryAddress == address(researchRegistry));
        assertTrue(teachingTokenAddress == address(teachingToken));
        assertTrue(policyGuardAddress == address(policyGuard));
        assertTrue(economicsPolicyAddress == address(economicsPolicy));
        assertTrue(faultPolicyAddress == address(faultPolicy));
        assertTrue(faultPolicyVersion == faultPolicy.FAULT_POLICY_VERSION());
        assertTrue(rewardDistributorAddress == address(rewardDistributor));
    }

    function testResearchClaimAccountingIsTeachingRegistryOnly() public {
        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset("Claim Source", "ipfs://claim-source");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        VM.stopPrank();

        VM.expectRevert();
        researchRegistry.recordTeachingRewardClaim(assetId, positionId, 123);

        VM.prank(address(registry));
        researchRegistry.recordTeachingRewardClaim(assetId, positionId, 123);

        SparkDaoTypes.ResearchPosition memory position =
            researchRegistry.getResearchPosition(assetId, positionId);
        assertTrue(position.totalClaimedUnits == 123);
    }

    function testResearchAndTeachingRegistryInitialAdminStateMatches() public view {
        SparkDaoTypes.DaoState memory researchState = researchRegistry.getDaoState();
        SparkDaoTypes.DaoState memory teachingState = registry.getDaoState();

        assertTrue(researchState.authority == teachingState.authority);
        assertTrue(researchState.treasury == teachingState.treasury);
        assertTrue(researchState.coordinator == teachingState.coordinator);
        assertTrue(researchState.stableAsset == teachingState.stableAsset);
        assertTrue(researchState.rewardUnlockSeconds == teachingState.rewardUnlockSeconds);
        assertTrue(researchState.buybackWaitSeconds == teachingState.buybackWaitSeconds);
    }

    function testTeachingRegistryRejectsInvalidFaultPolicyAtDeployment() public {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithPolicyOnly(address(0), linkedResearch);

        linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithPolicyOnly(address(0xBEEF), linkedResearch);

        VM.expectRevert();
        new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchRegistry),
            address(teachingToken),
            address(0),
            address(economicsPolicy),
            address(faultPolicy)
        );

        MockTeachingFaultPolicy zeroVersionPolicy = new MockTeachingFaultPolicy(0, 0);
        linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithPolicyOnly(address(zeroVersionPolicy), linkedResearch);
    }

    function testTeachingRegistryRejectsNonContractStableTokenOrPolicyGuardAtDeployment() public {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(0xBEEF),
            90 days,
            30 days,
            address(linkedResearch),
            address(teachingToken),
            address(policyGuard),
            address(economicsPolicy),
            address(faultPolicy)
        );

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(linkedResearch),
            address(0xBEEF),
            address(policyGuard),
            address(economicsPolicy),
            address(faultPolicy)
        );

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(linkedResearch),
            address(teachingToken),
            address(0xBEEF),
            address(economicsPolicy),
            address(faultPolicy)
        );
    }

    function testTeachingRegistryRejectsInvalidEconomicsPolicyAtDeploymentAndUse() public {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithEconomicsPolicyOnly(address(0), linkedResearch);

        linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithEconomicsPolicyOnly(address(0xBEEF), linkedResearch);

        MockTeachingEconomicsPolicy zeroVersionPolicy = new MockTeachingEconomicsPolicy(0, 0);
        linkedResearch = _deployAuxResearchRegistry();
        VM.expectRevert();
        _deployRegistryWithEconomicsPolicyOnly(address(zeroVersionPolicy), linkedResearch);

        _assertCourseCreationRejectedByEconomicsPolicy(new MockTeachingEconomicsPolicy(2, 1));
        _assertCourseCreationRejectedByEconomicsPolicy(new MockTeachingEconomicsPolicy(2, 4));
    }

    function testDefaultTeachingEconomicsPolicyUpdateIsAuthorityOnlyAndFutureOnly() public {
        uint64 oldCourseTypeId;
        VM.prank(coordinator);
        oldCourseTypeId =
            registry.createTeachingCourseType("Original Economics Course", 1_000_000, 400_000, 0);

        MockTeachingEconomicsPolicy alternatePolicy = new MockTeachingEconomicsPolicy(2, 3);

        VM.expectRevert();
        VM.prank(coordinator);
        registry.updateDefaultTeachingEconomicsPolicy(address(alternatePolicy));

        VM.prank(authority);
        registry.updateDefaultTeachingEconomicsPolicy(address(alternatePolicy));

        uint64 newCourseTypeId;
        VM.prank(coordinator);
        newCourseTypeId =
            registry.createTeachingCourseType("Updated Economics Course", 1_000_000, 400_000, 0);

        uint64 oldTeachingNftId = _createNoResearchTeachingSession(oldCourseTypeId);
        uint64 newTeachingNftId = _createNoResearchTeachingSession(newCourseTypeId);

        _confirmSchedule(oldTeachingNftId);
        uint256 beforeOldBond = stable.balanceOf(teacher);
        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(oldTeachingNftId, true);
        VM.stopPrank();
        assert(beforeOldBond - stable.balanceOf(teacher) == 800_000);

        _confirmSchedule(newTeachingNftId);
        uint256 beforeNewBond = stable.balanceOf(teacher);
        VM.startPrank(teacher);
        stable.approve(address(registry), 400_000);
        registry.lockTeachingCollateral(newTeachingNftId, true);
        VM.stopPrank();
        assert(beforeNewBond - stable.balanceOf(teacher) == 400_000);
    }

    function testDefaultTeachingFaultPolicyUpdateIsAuthorityOnlyAndFutureOnly() public {
        MockTeachingFaultPolicy alternatePolicy = new MockTeachingFaultPolicy(2, 0);

        VM.expectRevert();
        VM.prank(coordinator);
        registry.updateDefaultTeachingFaultPolicy(address(alternatePolicy));

        VM.expectRevert();
        VM.prank(authority);
        registry.updateDefaultTeachingFaultPolicy(address(0xBEEF));

        VM.prank(coordinator);
        uint64 oldCourseTypeId =
            registry.createTeachingCourseType("Frozen Policy Course", 1_000_000, 400_000, 0);

        VM.prank(authority);
        registry.updateDefaultTeachingFaultPolicy(address(alternatePolicy));

        VM.prank(coordinator);
        uint64 newCourseTypeId =
            registry.createTeachingCourseType("Updated Policy Course", 1_000_000, 400_000, 0);

        VM.prank(coordinator);
        registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: oldCourseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(coordinator);
        registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: newCourseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );
    }

    function testExistingSessionUsesFrozenFaultPolicyAfterDefaultPolicyUpdate() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Frozen Session", 1_000_000, 400_000, 0);
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

        MockTeachingFaultPolicy alternatePolicy = new MockTeachingFaultPolicy(2, 0);
        VM.prank(authority);
        registry.updateDefaultTeachingFaultPolicy(address(alternatePolicy));

        _prepareTeachingSession(teachingNftId);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        registry.coordinatorResolveCustomerFault(teachingNftId, 2);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherImmediatePayoutUnits,
            uint256 remedialTeacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 0);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherImmediatePayoutUnits == 200_000);
        assertTrue(remedialTeacherPayoutUnits == 0);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 200_000);
    }

    function testExistingSessionUsesFrozenFaultQuoteAfterPolicyBehaviourChanges() public {
        MutableTeachingFaultPolicy mutablePolicy = new MutableTeachingFaultPolicy();
        TeachingRegistry mutableRegistry = _deployRegistryWithPolicy(address(mutablePolicy));
        ResearchRegistry linkedResearch = auxResearchRegistry;
        TeachingRewardDistributor mutableDistributor =
            new TeachingRewardDistributor(address(mutableRegistry), address(linkedResearch));
        VM.prank(authority);
        mutableRegistry.setTeachingRewardDistributor(address(mutableDistributor));
        _wireTokensTo(mutableRegistry, linkedResearch);

        VM.prank(coordinator);
        uint64 courseTypeId =
            mutableRegistry.createTeachingCourseType("Mutable Fault Course", 1_000_000, 400_000, 0);
        VM.prank(coordinator);
        uint64 teachingNftId = mutableRegistry.createTeachingSession(
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

        mutablePolicy.setCustomerFaultTeacherPayoutDivisor(4);

        _prepareTeachingSessionFor(mutableRegistry, teachingNftId);
        VM.warp(block.timestamp + 38 days);
        VM.prank(coordinator);
        mutableRegistry.coordinatorResolveCustomerFault(teachingNftId, 2);

        (
            ,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherImmediatePayoutUnits,,,
            uint256 serviceReserveUnits
        ) = mutableRegistry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherImmediatePayoutUnits == 200_000);
        assertTrue(serviceReserveUnits == 200_000);
    }

    function testFaultPolicyQuoteSafetyValidationRejectsInvalidAdapters() public {
        _assertCourseCreationRejectedByPolicy(new MockTeachingFaultPolicy(2, 1));
        _assertCourseCreationRejectedByPolicy(new MockTeachingFaultPolicy(2, 2));
        _assertCourseCreationRejectedByPolicy(new MockTeachingFaultPolicy(2, 3));
        _assertCourseCreationRejectedByPolicy(new MockTeachingFaultPolicy(2, 4));
    }

    function testSettleTeachingRewardClaimRejectsNonDistributor() public {
        VM.expectRevert();
        registry.settleTeachingRewardClaim(address(stable), contributorOne, 0, 0, 0, 0);
    }

    function testResearchSettlementRevertsWhenRewardDistributorUnset() public {
        TeachingRegistry unwired = _deployUnwiredRegistry();
        ResearchRegistry unwiredResearch = auxResearchRegistry;
        _wireTokensTo(unwired, unwiredResearch);

        VM.startPrank(coordinator);
        uint64 assetId = unwiredResearch.createResearchAsset("Unwired Research", "ipfs://unwired");
        unwiredResearch.createPatchPosition(
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
        unwiredResearch.sealLayer(assetId, 1);
        uint64 courseTypeId = unwired.createTeachingCourseType(
            "Unwired Course", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        uint64 teachingNftId = unwired.createTeachingSession(
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
        unwired.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        unwired.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(unwired), 800_000);
        unwired.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(unwired), 800_000);
        unwired.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.warp(block.timestamp + 8 days);
        VM.prank(teacher);
        unwired.confirmTeachingCompletion(teachingNftId, true);
        VM.expectRevert();
        VM.prank(customer);
        unwired.confirmTeachingCompletion(teachingNftId, false);
    }

    function testRewardDistributorRecordPoolIsRegistryOnlyAndRejectsDuplicatePool() public {
        VM.expectRevert();
        rewardDistributor.recordTeachingRewardPool(
            77,
            88,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        VM.expectRevert();
        VM.prank(address(0xBEEF));
        rewardDistributor.recordTeachingRewardPool(
            77,
            88,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        VM.prank(address(registry));
        rewardDistributor.recordTeachingRewardPool(
            77,
            88,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        VM.expectRevert();
        VM.prank(address(registry));
        rewardDistributor.recordTeachingRewardPool(
            77,
            88,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );
    }

    function testFuzzDuplicateTeachingRewardPoolCannotOverwriteExistingClaimable(
        uint256 originalPoolUnitsSeed,
        uint256 overwritePoolUnitsSeed,
        uint64 originalUnlockDelaySeed,
        uint64 overwriteUnlockDelaySeed
    ) public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("No Overwrite Pool", "ipfs://no-overwrite");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();

        uint256 originalPoolUnits = 1 + (originalPoolUnitsSeed % 1_000_000_000);
        uint256 overwritePoolUnits = 1 + (overwritePoolUnitsSeed % 1_000_000_000);
        uint64 originalUnlockDelay = 1 + (originalUnlockDelaySeed % 365 days);
        uint64 overwriteUnlockDelay = 1 + (overwriteUnlockDelaySeed % 365 days);
        uint64 teachingNftId = 77;
        uint64 snapshotAt = uint64(block.timestamp);
        uint64 unlockAt = uint64(block.timestamp + originalUnlockDelay);
        VM.prank(address(registry));
        rewardDistributor.recordTeachingRewardPool(
            teachingNftId,
            assetId,
            address(stable),
            originalPoolUnits,
            originalPoolUnits,
            snapshotAt,
            unlockAt,
            1,
            10_000
        );

        VM.expectRevert(SparkDaoErrors.InvalidTeachingRewardPool.selector);
        VM.prank(address(registry));
        rewardDistributor.recordTeachingRewardPool(
            teachingNftId,
            assetId,
            address(eurc),
            overwritePoolUnits,
            overwritePoolUnits,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + overwriteUnlockDelay),
            1,
            10_000
        );

        (uint256 amount, uint64 storedUnlockAt, bool claimed) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        assertTrue(amount == originalPoolUnits);
        assertTrue(storedUnlockAt == unlockAt);
        assertTrue(!claimed);
    }

    function testWrongDistributorCannotSettleCallbackOrMarkClaimed() public {
        TeachingRewardDistributor wrongDistributor =
            new TeachingRewardDistributor(address(registry), address(researchRegistry));

        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Wrong Distributor", "ipfs://wrong-distributor");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();

        VM.prank(address(registry));
        wrongDistributor.recordTeachingRewardPool(
            78,
            assetId,
            address(stable),
            100,
            100,
            uint64(block.timestamp),
            uint64(block.timestamp),
            1,
            10_000
        );

        uint256 reservedBefore = registry.getVaultReservedUnits(address(stable));
        uint256 balanceBefore = stable.balanceOf(contributorOne);
        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRewardDistributor.selector);
        VM.prank(contributorOne);
        wrongDistributor.claimTeachingReward(78, assetId, positionId);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == reservedBefore);
        assertTrue(stable.balanceOf(contributorOne) == balanceBefore);
        (,, bool claimed) = wrongDistributor.getTeachingRewardClaimable(78, assetId, positionId);
        assertTrue(!claimed);
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

    function testCreateTeachingSessionRejectsPastOrCurrentScheduledAt() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Schedule Bounds", 1_000_000, 400_000, 0);

        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp - 1),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 1),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        assertTrue(teachingToken.ownerOf(teachingNftId) == teacher);
    }

    function testScheduledSnapshotCannotBeBackfilledAfterResearchUpdate() public {
        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset("No Backfill", "ipfs://no-backfill");
        researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 courseTypeId = registry.createTeachingCourseType(
            "No Backfill Course", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        VM.stopPrank();

        VM.warp(block.timestamp + 1 days);
        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp - 1),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: linkedAssetIds,
                linkedResearchWeightBps: new uint16[](0)
            })
        );
    }

    function testTeachingResearchShareCannotExceedFaultSolvencyCap() public {
        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingCourseType("Overlinked Course", 1_000_000, 400_000, 1_501);

        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType(
            "Discount-Sensitive Course", 1_000_000, 400_000, 1_500
        );

        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingSession(
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

    function testTeacherCanWithdrawUnmatchedCollateralBeforeCustomerLocks() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Unmatched Teacher", 1_000_000, 400_000, 0);
        uint64 teachingNftId = _createNoResearchTeachingSession(courseTypeId);
        _confirmSchedule(teachingNftId);

        uint256 beforeLock = stable.balanceOf(teacher);
        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        registry.withdrawUnmatchedTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        (uint8 status,, bool collateralLocked,,,) = registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 1);
        assertTrue(!collateralLocked);
        assertTrue(stable.balanceOf(teacher) == beforeLock);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();
        VM.startPrank(customer);
        stable.approve(address(registry), 1_000_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function testCustomerCanWithdrawUnmatchedPaymentBeforeTeacherLocks() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Unmatched Customer", 1_000_000, 400_000, 0);
        uint64 teachingNftId = _createNoResearchTeachingSession(courseTypeId);
        _confirmSchedule(teachingNftId);

        uint256 beforeLock = stable.balanceOf(customer);
        VM.startPrank(customer);
        stable.approve(address(registry), 1_000_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        registry.withdrawUnmatchedTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        (uint8 status,, bool collateralLocked,,,) = registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 1);
        assertTrue(!collateralLocked);
        assertTrue(stable.balanceOf(customer) == beforeLock);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();
        VM.startPrank(customer);
        stable.approve(address(registry), 1_000_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function testCannotWithdrawTeachingCollateralAfterBothSidesLock() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Matched Collateral", 1_000_000, 400_000, 0);
        uint64 teachingNftId = _createNoResearchTeachingSession(courseTypeId);
        _confirmSchedule(teachingNftId);
        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();
        VM.startPrank(customer);
        stable.approve(address(registry), 1_000_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();

        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        VM.prank(teacher);
        registry.withdrawUnmatchedTeachingCollateral(teachingNftId, true);
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
        uint64 assetId = researchRegistry.createResearchAsset("Ack Research", "ipfs://ack-research");
        uint64 layerOnePositionA = researchRegistry.createPatchPosition(
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
        uint64 layerOnePositionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Customer Ack Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetId, layerOnePositionA);
        researchRegistry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        researchRegistry.advanceLayer(assetId, preparedPositionIds);

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

        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionA) == 48_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionB) == 32_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerTwoPosition) == 0);
    }

    function testLinkedResearchWithZeroShareSkipsDistributionCleanly() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Zero Share Asset", "ipfs://zero-share-asset");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

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
        rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
    }

    function testImmediateTeachingRewardClaimWhenUnlockZero() public {
        VM.prank(authority);
        registry.updateRewardUnlockSeconds(0);

        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Immediate Reward", "ipfs://immediate-reward");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Immediate Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        (uint256 amount, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        assertTrue(unlockAt == block.timestamp);
        assertTrue(amount == 80_000);

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 80_000);
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
            uint256 remedialTeacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 1);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 0);
        assertTrue(remedialTeacherPayoutUnits == 200_000);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 200_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 200_000);
    }

    function testCoordinatorCanSettleTeacherFaultRemedialWage() public {
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

        _prepareTeachingSession(teachingNftId);
        VM.warp(block.timestamp + 33 days);

        VM.prank(coordinator);
        registry.coordinatorResolveTeacherFault(teachingNftId, 4);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 200_000);

        VM.expectRevert(SparkDaoErrors.UnauthorizedCoordinator.selector);
        VM.prank(customer);
        registry.coordinatorSettleTeacherFaultRemedialWage(teachingNftId);

        uint256 beforeTeacher = stable.balanceOf(teacher);
        VM.prank(coordinator);
        registry.coordinatorSettleTeacherFaultRemedialWage(teachingNftId);
        uint256 afterTeacher = stable.balanceOf(teacher);

        (uint256 remedialTeacherPayoutUnits, uint64 remedialWageSettledAt) =
            registry.getTeachingRemedialWageSettlement(teachingNftId);
        assertTrue(remedialTeacherPayoutUnits == 200_000);
        assertTrue(remedialWageSettledAt == block.timestamp);
        assertTrue(afterTeacher == beforeTeacher + 200_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);

        VM.expectRevert(SparkDaoErrors.InvalidTeachingStatus.selector);
        VM.prank(coordinator);
        registry.coordinatorSettleTeacherFaultRemedialWage(teachingNftId);
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

        (uint8 status,,, bool distributionRecorded, uint64 resolvedAt,) =
            registry.getTeachingSessionState(teachingNftId);
        assertTrue(status == 5);
        assertTrue(!distributionRecorded);
        assertTrue(resolvedAt != 0);
        assertTrue(afterRefund == beforeRefund + 400_000);
        assertTrue(afterTeacher == beforeTeacher + 1_000_000);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 remedialTeacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 0);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 200_000);
        assertTrue(remedialTeacherPayoutUnits == 0);
        assertTrue(researchRewardUnits == 0);
        assertTrue(serviceReserveUnits == 200_000);
    }

    function testResearchBackedTeachingDistributesSnapshotRewards() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Research Core", "ipfs://research-core");
        uint64 layerOnePositionA = researchRegistry.createPatchPosition(
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
        uint64 layerOnePositionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Research Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetId, layerOnePositionA);
        researchRegistry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        researchRegistry.advanceLayer(assetId, preparedPositionIds);

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

        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionA) == 48_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionB) == 32_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerTwoPosition) == 0);

        VM.warp(block.timestamp + 91 days);

        uint256 contributorOneBefore = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePositionA);
        uint256 contributorOneAfter = stable.balanceOf(contributorOne);
        assertTrue(contributorOneAfter == contributorOneBefore + 48_000);

        uint256 contributorTwoBefore = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePositionB);
        uint256 contributorTwoAfter = stable.balanceOf(contributorTwo);
        assertTrue(contributorTwoAfter == contributorTwoBefore + 32_000);
    }

    function testScheduledSnapshotIgnoresResearchUpdatesBeforeCompletion() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Layered Research", "ipfs://layered-research");
        uint64 layerOnePositionA = researchRegistry.createPatchPosition(
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
        uint64 layerOnePositionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Snapshot Theory", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetId, layerOnePositionA);
        researchRegistry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        researchRegistry.advanceLayer(assetId, preparedPositionIds);

        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers[0] == 1);

        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionA) == 48_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerTwoPosition) == 0);
    }

    function testTransferredResearchPositionLetsNewHolderClaimTeachingReward() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Transferable Research", "ipfs://transferable");
        uint64 layerOnePosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Transfer Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.transferResearchPosition(assetId, layerOnePosition, contributorTwo);
        assertTrue(
            researchToken.ownerOf(_researchTokenId(assetId, layerOnePosition)) == contributorTwo
        );

        VM.warp(block.timestamp + 91 days);

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);

        uint256 beforeClaim = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);
        uint256 afterClaim = stable.balanceOf(contributorTwo);
        assertTrue(afterClaim == beforeClaim + 80_000);
    }

    function testBoughtBackResearchPositionLetsTreasuryClaimTeachingReward() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Dao Buyback Research", "ipfs://dao-buyback");
        uint64 layerOnePosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Buyback Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        assertTrue(stable.transfer(address(researchRegistry), 500_000));

        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        researchRegistry.sellPositionBackToDao(assetId, layerOnePosition);
        assertTrue(researchToken.ownerOf(_researchTokenId(assetId, layerOnePosition)) == treasury);

        VM.warp(block.timestamp + 91 days);

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);

        uint256 beforeClaim = stable.balanceOf(treasury);
        VM.prank(treasury);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);
        uint256 afterClaim = stable.balanceOf(treasury);
        assertTrue(afterClaim == beforeClaim + 80_000);
    }

    function testBoughtBackTeachingRewardClaimUsesTreasuryAfterAuthorityRotation() public {
        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset(
            "Rotated Buyback Research", "ipfs://rotated-buyback"
        );
        uint64 layerOnePosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Rotated Buyback", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        assertTrue(stable.transfer(address(researchRegistry), 500_000));

        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        researchRegistry.sellPositionBackToDao(assetId, layerOnePosition);

        address newAuthority = address(0xA22CE);
        VM.prank(authority);
        registry.updateAuthority(newAuthority);

        VM.warp(block.timestamp + 91 days);

        VM.expectRevert();
        VM.prank(authority);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);
        VM.expectRevert();
        VM.prank(newAuthority);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);

        uint256 beforeClaim = stable.balanceOf(treasury);
        VM.prank(treasury);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, layerOnePosition);
        assertTrue(stable.balanceOf(treasury) == beforeClaim + 80_000);
    }

    function testResearchForceValidStillDistributesSnapshotRewards() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Forced Research", "ipfs://forced-research");
        uint64 layerOnePositionA = researchRegistry.createPatchPosition(
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
        uint64 layerOnePositionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Coordinator Rescue", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionA) == 48_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionB) == 32_000);
    }

    function testWeightedMultiAssetTeachingDistribution() public {
        VM.startPrank(coordinator);
        uint64 assetOne = researchRegistry.createResearchAsset("Asset One", "ipfs://asset-one");
        uint64 positionOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);

        uint64 assetTwo = researchRegistry.createResearchAsset("Asset Two", "ipfs://asset-two");
        uint64 positionTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Weighted Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        assertTrue(_claimableAmount(teachingNftId, assetOne, positionOne) == 56_000);
        assertTrue(_claimableAmount(teachingNftId, assetTwo, positionTwo) == 24_000);
    }

    function testBatchTeachingRewardClaim() public {
        VM.startPrank(coordinator);
        uint64 assetOne = researchRegistry.createResearchAsset("Batch One", "ipfs://batch-one");
        uint64 positionOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);

        uint64 assetTwo = researchRegistry.createResearchAsset("Batch Two", "ipfs://batch-two");
        uint64 positionTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Batch Claim Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        uint64[] memory teachingNftIds = new uint64[](2);
        teachingNftIds[0] = teachingNftId;
        teachingNftIds[1] = teachingNftId;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 80_000);
    }

    function testDustTeachingRewardSkipsZeroAmountPositions() public {
        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset("Dust Asset", "ipfs://dust-asset");
        uint64 positionA = researchRegistry.createPatchPosition(
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
        uint64 positionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

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

        assertTrue(_claimableAmount(teachingNftId, assetId, positionA) == 2);
        assertTrue(_claimableAmount(teachingNftId, assetId, positionB) == 0);

        (, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionA);
        VM.warp(unlockAt);

        uint256 reservedBeforeClaim = registry.getVaultReservedUnits(address(stable));
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionA);
        uint256 reservedAfterPositiveClaim = registry.getVaultReservedUnits(address(stable));
        assertTrue(reservedAfterPositiveClaim == reservedBeforeClaim - 2);

        VM.expectRevert(SparkDaoErrors.TeachingRewardAlreadyClaimed.selector);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionA);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == reservedAfterPositiveClaim);

        uint256 contributorTwoBefore = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionB);
        uint256 reservedAfterZeroClaim = registry.getVaultReservedUnits(address(stable));
        assertTrue(reservedAfterZeroClaim == reservedAfterPositiveClaim - 1);
        assertTrue(reservedAfterZeroClaim == reservedBeforeClaim - 3);
        assertTrue(stable.balanceOf(contributorTwo) == contributorTwoBefore);

        VM.expectRevert(SparkDaoErrors.TeachingRewardAlreadyClaimed.selector);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionB);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == reservedAfterZeroClaim);

        (,, bool positionAClaimed) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionA);
        (,, bool positionBClaimed) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionB);
        assertTrue(positionAClaimed);
        assertTrue(positionBClaimed);
    }

    function testBatchTeachingRewardRejectsDuplicateEntries() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Duplicate Batch", "ipfs://duplicate-batch");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Duplicate Batch Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        uint64[] memory teachingNftIds = new uint64[](2);
        teachingNftIds[0] = teachingNftId;
        teachingNftIds[1] = teachingNftId;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionId;
        positionIds[1] = positionId;

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);

        uint256 beforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);
        uint256 afterClaim = stable.balanceOf(contributorOne);
        assertTrue(afterClaim == beforeClaim + 80_000);
    }

    function testBatchTeachingRewardRejectsMixedHolders() public {
        VM.startPrank(coordinator);
        uint64 assetOne =
            researchRegistry.createResearchAsset("Mixed Batch One", "ipfs://mixed-batch-one");
        uint64 positionOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);

        uint64 assetTwo =
            researchRegistry.createResearchAsset("Mixed Batch Two", "ipfs://mixed-batch-two");
        uint64 positionTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Mixed Holder Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.transferResearchPosition(assetTwo, positionTwo, contributorTwo);

        VM.warp(block.timestamp + 91 days);

        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetOne;
        assetIds[1] = assetTwo;
        uint64[] memory teachingNftIds = new uint64[](2);
        teachingNftIds[0] = teachingNftId;
        teachingNftIds[1] = teachingNftId;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);

        uint256 oneBefore = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetOne, positionOne);
        uint256 oneAfter = stable.balanceOf(contributorOne);
        assertTrue(oneAfter == oneBefore + 40_000);

        uint256 twoBefore = stable.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetTwo, positionTwo);
        uint256 twoAfter = stable.balanceOf(contributorTwo);
        assertTrue(twoAfter == twoBefore + 40_000);
    }

    function testMultiAssetMultiLayerDistributionConservesTotalValue() public {
        VM.startPrank(coordinator);
        uint64 assetOne =
            researchRegistry.createResearchAsset("Conservation One", "ipfs://conservation-one");
        uint64 assetOneLayerOneA = researchRegistry.createPatchPosition(
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
        uint64 assetOneLayerOneB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);
        uint64 assetOneLayerTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 2);

        uint64 assetTwo =
            researchRegistry.createResearchAsset("Conservation Two", "ipfs://conservation-two");
        uint64 assetTwoLayerOneA = researchRegistry.createPatchPosition(
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
        uint64 assetTwoLayerOneB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);
        uint64 assetTwoLayerTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Conservation Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetOne, assetOneLayerOneA);
        researchRegistry.markPositionReady(assetOne, assetOneLayerOneB);
        uint64[] memory assetOnePrepared = new uint64[](1);
        assetOnePrepared[0] = assetOneLayerTwo;
        researchRegistry.advanceLayer(assetOne, assetOnePrepared);

        researchRegistry.markPositionReady(assetTwo, assetTwoLayerOneA);
        researchRegistry.markPositionReady(assetTwo, assetTwoLayerOneB);
        uint64[] memory assetTwoPrepared = new uint64[](1);
        assetTwoPrepared[0] = assetTwoLayerTwo;
        researchRegistry.advanceLayer(assetTwo, assetTwoPrepared);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        uint256 assetOneAmountA = _claimableAmount(teachingNftId, assetOne, assetOneLayerOneA);
        uint256 assetOneAmountB = _claimableAmount(teachingNftId, assetOne, assetOneLayerOneB);
        uint256 assetTwoAmountA = _claimableAmount(teachingNftId, assetTwo, assetTwoLayerOneA);
        uint256 assetTwoAmountB = _claimableAmount(teachingNftId, assetTwo, assetTwoLayerOneB);

        uint256 totalDistributed =
            assetOneAmountA + assetOneAmountB + assetTwoAmountA + assetTwoAmountB;
        assertTrue(assetOneAmountA == 33_600);
        assertTrue(assetOneAmountB == 22_400);
        assertTrue(assetTwoAmountA == 18_000);
        assertTrue(assetTwoAmountB == 6_000);
        assertTrue(totalDistributed == 80_000);

        assertTrue(_claimableAmount(teachingNftId, assetOne, assetOneLayerTwo) == 0);
        assertTrue(_claimableAmount(teachingNftId, assetTwo, assetTwoLayerTwo) == 0);
    }

    function testPastDeadlineResearchBackedTeachingNeedsCoordinatorAndKeepsSnapshot() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Timeout Research", "ipfs://timeout-research");
        uint64 layerOnePositionA = researchRegistry.createPatchPosition(
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
        uint64 layerOnePositionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Timeout Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetId, layerOnePositionA);
        researchRegistry.markPositionReady(assetId, layerOnePositionB);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        researchRegistry.advanceLayer(assetId, preparedPositionIds);

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

        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionA) == 48_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerOnePositionB) == 32_000);
        assertTrue(_claimableAmount(teachingNftId, assetId, layerTwoPosition) == 0);
    }

    function testTeacherFaultUsesHalfPriceToFundTwoResearchShares() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Fault Research", "ipfs://fault-research");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Fault Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        assertTrue(_claimableAmount(teachingNftId, assetId, positionId) == 160_000);

        (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 remedialTeacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialLessonCount == 1);
        assertTrue(customerChargeUnits == 400_000);
        assertTrue(customerRefundUnits == 400_000);
        assertTrue(teacherPayoutUnits == 0);
        assertTrue(remedialTeacherPayoutUnits == 200_000);
        assertTrue(researchRewardUnits == 160_000);
        assertTrue(serviceReserveUnits == 40_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 360_000);

        VM.prank(coordinator);
        registry.coordinatorSettleTeacherFaultRemedialWage(teachingNftId);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 160_000);

        VM.warp(block.timestamp + 91 days);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
    }

    function testTeacherFaultRecordsResearchPoolWhenOrdinaryResearchRewardIsZero() public {
        MockTeachingEconomicsPolicy faultOnlyResearchPolicy = new MockTeachingEconomicsPolicy(2, 5);
        VM.prank(authority);
        registry.updateDefaultTeachingEconomicsPolicy(address(faultOnlyResearchPolicy));

        VM.startPrank(coordinator);
        uint64 assetId = researchRegistry.createResearchAsset(
            "Fault Only Research", "ipfs://fault-only-research"
        );
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Fault Only Research Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        _prepareTeachingSession(teachingNftId);
        VM.warp(block.timestamp + 33 days);

        VM.prank(coordinator);
        registry.coordinatorResolveTeacherFault(teachingNftId, 4);

        assertTrue(_claimableAmount(teachingNftId, assetId, positionId) == 160_000);

        (
            ,,,,
            uint256 remedialTeacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        ) = registry.getTeachingFaultSettlement(teachingNftId);
        assertTrue(remedialTeacherPayoutUnits == 200_000);
        assertTrue(researchRewardUnits == 160_000);
        assertTrue(serviceReserveUnits == 40_000);
    }

    function testForceValidPreservesWeightedHistoricalSnapshot() public {
        VM.startPrank(coordinator);
        uint64 assetOne =
            researchRegistry.createResearchAsset("Force Asset One", "ipfs://force-asset-one");
        uint64 assetOneLayerOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);
        uint64 assetOneLayerTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 2);

        uint64 assetTwo =
            researchRegistry.createResearchAsset("Force Asset Two", "ipfs://force-asset-two");
        uint64 assetTwoLayerOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);
        uint64 assetTwoLayerTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 2);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Force Weighted Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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
        researchRegistry.markPositionReady(assetOne, assetOneLayerOne);
        researchRegistry.advanceLayer(assetOne, preparedOne);

        uint64[] memory preparedTwo = new uint64[](1);
        preparedTwo[0] = assetTwoLayerTwo;
        researchRegistry.markPositionReady(assetTwo, assetTwoLayerOne);
        researchRegistry.advanceLayer(assetTwo, preparedTwo);

        VM.warp(block.timestamp + 31 days);
        VM.prank(coordinator);
        registry.coordinatorForceTeachingValid(teachingNftId, 3);

        uint16[] memory settlementLayers =
            registry.getTeachingSessionSettlementResearchLayers(teachingNftId);
        assertTrue(settlementLayers.length == 2);
        assertTrue(settlementLayers[0] == 1);
        assertTrue(settlementLayers[1] == 1);

        assertTrue(_claimableAmount(teachingNftId, assetOne, assetOneLayerOne) == 56_000);
        assertTrue(_claimableAmount(teachingNftId, assetTwo, assetTwoLayerOne) == 24_000);

        assertTrue(_claimableAmount(teachingNftId, assetOne, assetOneLayerTwo) == 0);
        assertTrue(_claimableAmount(teachingNftId, assetTwo, assetTwoLayerTwo) == 0);
    }

    function testTeachingRewardClaimPullSupportsStagedClaims() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Bucket Research", "ipfs://bucket-research");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Bucket Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        (uint256 amountOne, uint64 unlockOne,) =
            rewardDistributor.getTeachingRewardClaimable(teachingOne, assetId, positionId);
        (uint256 amountTwo, uint64 unlockTwo,) =
            rewardDistributor.getTeachingRewardClaimable(teachingTwo, assetId, positionId);
        assertTrue(amountOne == 80_000);
        assertTrue(amountTwo == 80_000);
        assertTrue(unlockTwo > unlockOne);

        uint256 beforeFirstClaim = stable.balanceOf(contributorOne);
        VM.warp(unlockOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingOne, assetId, positionId);
        uint256 afterFirstClaim = stable.balanceOf(contributorOne);
        assertTrue(afterFirstClaim == beforeFirstClaim + 80_000);

        (,, bool firstClaimed) =
            rewardDistributor.getTeachingRewardClaimable(teachingOne, assetId, positionId);
        assertTrue(firstClaimed);
        assertTrue(_claimableAmount(teachingTwo, assetId, positionId) == 80_000);

        uint256 beforeSecondClaim = stable.balanceOf(contributorOne);
        VM.warp(unlockTwo);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingTwo, assetId, positionId);
        uint256 afterSecondClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSecondClaim == beforeSecondClaim + 80_000);

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingTwo, assetId, positionId);
    }

    function testBatchTeachingRewardClaimRevertsWhenOnePoolIsLocked() public {
        VM.startPrank(coordinator);
        uint64 assetOne = researchRegistry.createResearchAsset("Atomic One", "ipfs://atomic-one");
        uint64 positionOne = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetOne, 1);

        uint64 assetTwo = researchRegistry.createResearchAsset("Atomic Two", "ipfs://atomic-two");
        uint64 positionTwo = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetTwo, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Atomic Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        (, uint64 unlockOne,) =
            rewardDistributor.getTeachingRewardClaimable(teachingOne, assetOne, positionOne);
        (, uint64 unlockTwo,) =
            rewardDistributor.getTeachingRewardClaimable(teachingTwo, assetTwo, positionTwo);
        assertTrue(unlockTwo > unlockOne);

        uint64[] memory teachingNftIds = new uint64[](2);
        teachingNftIds[0] = teachingOne;
        teachingNftIds[1] = teachingTwo;
        uint64[] memory assetIds = new uint64[](2);
        assetIds[0] = assetOne;
        assetIds[1] = assetTwo;
        uint64[] memory positionIds = new uint64[](2);
        positionIds[0] = positionOne;
        positionIds[1] = positionTwo;

        uint256 beforeBatch = stable.balanceOf(contributorOne);
        VM.warp(unlockOne);
        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);
        uint256 afterFailedBatch = stable.balanceOf(contributorOne);
        assertTrue(afterFailedBatch == beforeBatch);

        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingOne, assetOne, positionOne);
        uint256 afterSingleClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSingleClaim == beforeBatch + 80_000);

        VM.expectRevert();
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingTwo, assetTwo, positionTwo);

        VM.warp(unlockTwo);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingTwo, assetTwo, positionTwo);
        uint256 afterSecondClaim = stable.balanceOf(contributorOne);
        assertTrue(afterSecondClaim == beforeBatch + 160_000);
    }

    function testVaultReservedUnitsTrackTeachingSettlementFlow() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Reserved Research", "ipfs://reserved-research");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId = registry.createTeachingCourseType(
            "Reserved Seminar", 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
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

        uint256 reservedAfterCollateral = registry.getVaultReservedUnits(address(stable));
        assertTrue(reservedAfterCollateral == 1_600_000);
        assertTrue(stable.balanceOf(address(registry)) == 1_600_000);

        VM.warp(block.timestamp + 8 days);
        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);

        uint256 reservedAfterSettlement = registry.getVaultReservedUnits(address(stable));
        assertTrue(reservedAfterSettlement == 480_000);
        assertTrue(stable.balanceOf(address(registry)) == 800_000);
        assertTrue(stable.balanceOf(address(registry)) - reservedAfterSettlement == 320_000);

        VM.warp(block.timestamp + 31 days);
        VM.prank(teacher);
        registry.redeemTeachingPayout(teachingNftId);

        uint256 reservedAfterRedeem = registry.getVaultReservedUnits(address(stable));
        assertTrue(reservedAfterRedeem == 80_000);
        assertTrue(stable.balanceOf(address(registry)) == 400_000);
        assertTrue(stable.balanceOf(address(registry)) - reservedAfterRedeem == 320_000);

        (, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);
        uint256 contributorBeforeClaim = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
        assertTrue(stable.balanceOf(address(registry)) == 320_000);
        assertTrue(stable.balanceOf(contributorOne) == contributorBeforeClaim + 80_000);
        SparkDaoTypes.ResearchPosition memory position =
            researchRegistry.getResearchPosition(assetId, positionId);
        assertTrue(position.totalClaimedUnits == 80_000);
    }

    function testAuthorityCanWithdrawCompletedTeachingIdleWithoutTouchingReservedClaims() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Teaching Idle Asset", "ipfs://teaching-idle");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();

        uint64 teachingNftId = _createResearchBackedTeachingSession(assetId, "Idle withdrawal");
        _completeTeachingLifecycle(teachingNftId);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 480_000);
        assertTrue(stable.balanceOf(address(registry)) == 800_000);

        uint256 authorityBefore = stable.balanceOf(authority);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 320_000);
        assertTrue(stable.balanceOf(authority) == authorityBefore + 320_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 480_000);
        assertTrue(stable.balanceOf(address(registry)) == 480_000);

        VM.expectRevert(SparkDaoErrors.VaultFundsReserved.selector);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 1);

        VM.warp(block.timestamp + 91 days);
        VM.prank(teacher);
        registry.redeemTeachingPayout(teachingNftId);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
        assertTrue(stable.balanceOf(address(registry)) == 0);
    }

    function testTeachingIdleWithdrawalRejectsInvalidCallerAssetAndAmount() public {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("Idle Negative", 1_000_000, 400_000, 0);
        uint64 teachingNftId = _createNoResearchTeachingSession(courseTypeId);
        _prepareFullPriceTeachingSession(teachingNftId);
        _settlePreparedTeaching(teachingNftId);

        VM.expectRevert(SparkDaoErrors.UnauthorizedAuthority.selector);
        VM.prank(coordinator);
        registry.withdrawTeachingIdleFor(address(stable), 1);

        VM.expectRevert(SparkDaoErrors.ZeroAddress.selector);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(0), 1);

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(0xBEEF), 1);

        VM.expectRevert(SparkDaoErrors.InvalidAmount.selector);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 0);

        VM.expectRevert(SparkDaoErrors.VaultFundsReserved.selector);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 600_001);
    }

    function testTeachingIdleWithdrawalIsPerStableAsset() public {
        VM.prank(coordinator);
        uint64 usdcCourse = registry.createTeachingCourseType("USDC Idle", 1_000_000, 400_000, 0);
        uint64 usdcTeaching = _createNoResearchTeachingSession(usdcCourse);

        VM.prank(authority);
        registry.updateStableAsset(address(eurc));
        VM.prank(coordinator);
        uint64 eurcCourse = registry.createTeachingCourseType("EURC Idle", 1_000_000, 400_000, 0);
        uint64 eurcTeaching = _createNoResearchTeachingSession(eurcCourse);

        _prepareFullPriceTeachingSessionWithStable(usdcTeaching, stable);
        _prepareFullPriceTeachingSessionWithStable(eurcTeaching, eurc);
        _settlePreparedTeaching(usdcTeaching);
        _settlePreparedTeaching(eurcTeaching);

        assertTrue(stable.balanceOf(address(registry)) == 1_000_000);
        assertTrue(eurc.balanceOf(address(registry)) == 1_000_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 400_000);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 400_000);

        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 600_000);

        assertTrue(stable.balanceOf(address(registry)) == 400_000);
        assertTrue(eurc.balanceOf(address(registry)) == 1_000_000);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 400_000);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 400_000);
    }

    function testReleasedTeachingDustBecomesWithdrawableIdle() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Withdrawable Dust", "ipfs://withdrawable-dust");
        uint64 positionA = researchRegistry.createPatchPosition(
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
        uint64 positionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        uint64 courseTypeId = registry.createTeachingCourseType("Dust Idle", 12, 1, 2_500);
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
        (, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionA);
        VM.warp(unlockAt);

        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionA);
        VM.prank(contributorTwo);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionB);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 1);
        assertTrue(stable.balanceOf(address(registry)) == 10);

        uint256 authorityBefore = stable.balanceOf(authority);
        VM.prank(authority);
        registry.withdrawTeachingIdleFor(address(stable), 9);
        assertTrue(stable.balanceOf(authority) == authorityBefore + 9);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 1);
        assertTrue(stable.balanceOf(address(registry)) == 1);

        VM.prank(teacher);
        registry.redeemTeachingPayout(teachingNftId);
        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
        assertTrue(stable.balanceOf(address(registry)) == 0);
    }

    function testSettlementGasDoesNotScaleLinearlyWithResearchPositionCount() public {
        uint64 singleAsset = _createResearchAssetWithPositions(
            "Single settlement asset", 1, SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        );
        uint64 manyAsset = _createResearchAssetWithPositions("Many settlement asset", 20, 500);

        uint64 singleTeaching =
            _createResearchBackedTeachingSession(singleAsset, "Single settlement gas");
        uint64 manyTeaching = _createResearchBackedTeachingSession(manyAsset, "Many settlement gas");

        uint256 singleSettlementGas = _settleTeachingAndMeasureSecondCompletion(singleTeaching);
        uint256 manySettlementGas = _settleTeachingAndMeasureSecondCompletion(manyTeaching);

        assertTrue(manySettlementGas < singleSettlementGas + 100_000);
    }

    function testStableAssetDefaultSwitchOnlyAffectsFutureTeachingSessions() public {
        VM.prank(coordinator);
        uint64 usdcCourse = registry.createTeachingCourseType("USDC Course", 1_000_000, 400_000, 0);
        VM.prank(coordinator);
        uint64 usdcTeaching = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: usdcCourse,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        VM.prank(authority);
        registry.updateStableAsset(address(eurc));

        VM.prank(coordinator);
        uint64 eurcCourse = registry.createTeachingCourseType("EURC Course", 1_000_000, 400_000, 0);
        VM.prank(coordinator);
        uint64 eurcTeaching = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: eurcCourse,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        _prepareTeachingSessionWithStable(usdcTeaching, stable);
        _prepareTeachingSessionWithStable(eurcTeaching, eurc);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 1_600_000);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 1_600_000);

        _settlePreparedTeaching(usdcTeaching);
        _settlePreparedTeaching(eurcTeaching);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 400_000);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 400_000);

        VM.warp(block.timestamp + 31 days);
        uint256 teacherUsdcBefore = stable.balanceOf(teacher);
        VM.prank(teacher);
        registry.redeemTeachingPayout(usdcTeaching);
        assertTrue(stable.balanceOf(teacher) == teacherUsdcBefore + 400_000);

        uint256 teacherEurcBefore = eurc.balanceOf(teacher);
        VM.prank(teacher);
        registry.redeemTeachingPayout(eurcTeaching);
        assertTrue(eurc.balanceOf(teacher) == teacherEurcBefore + 400_000);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 0);
    }

    function testTeachingRewardPoolUsesFrozenSessionStableAsset() public {
        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("EURC Reward Asset", "ipfs://eurc-reward");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();

        VM.prank(authority);
        registry.updateStableAsset(address(eurc));

        uint64 teachingNftId = _createResearchBackedTeachingSession(assetId, "EURC reward seminar");
        _prepareTeachingSessionWithStable(teachingNftId, eurc);
        _settlePreparedTeaching(teachingNftId);

        (, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);

        uint256 stableBefore = stable.balanceOf(contributorOne);
        uint256 eurcBefore = eurc.balanceOf(contributorOne);
        VM.prank(contributorOne);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);

        assertTrue(stable.balanceOf(contributorOne) == stableBefore);
        assertTrue(eurc.balanceOf(contributorOne) == eurcBefore + 80_000);
    }

    function testLockedTokenMintersBlockRotationButRegistryStillMints() public {
        VM.prank(authority);
        researchToken.lockMinter();
        VM.prank(authority);
        teachingToken.lockMinter();

        VM.expectRevert();
        VM.prank(authority);
        researchToken.setMinter(address(0xBEEF));
        VM.expectRevert();
        VM.prank(authority);
        teachingToken.setMinter(address(0xBEEF));

        VM.startPrank(coordinator);
        uint64 assetId =
            researchRegistry.createResearchAsset("Locked Minter Research", "ipfs://locked");
        uint64 positionId = researchRegistry.createPatchPosition(
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
        uint64 courseTypeId =
            registry.createTeachingCourseType("Locked Minter Teaching", 1_000_000, 400_000, 0);
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
        VM.stopPrank();

        assertTrue(researchToken.ownerOf(_researchTokenId(assetId, positionId)) == contributorOne);
        assertTrue(teachingToken.ownerOf(teachingNftId) == teacher);

        address newAuthority = address(0xA22CE);
        VM.prank(authority);
        registry.updateAuthority(newAuthority);
        VM.prank(newAuthority);
        registry.updateCoordinator(address(0xC002));
    }

    function _prepareTeachingSession(uint64 teachingNftId) internal {
        _prepareTeachingSessionWithStable(teachingNftId, stable);
    }

    function _prepareTeachingSessionWithStable(uint64 teachingNftId, MockERC20 stableAsset)
        internal
    {
        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stableAsset.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stableAsset.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function _prepareFullPriceTeachingSession(uint64 teachingNftId) internal {
        _prepareFullPriceTeachingSessionWithStable(teachingNftId, stable);
    }

    function _prepareFullPriceTeachingSessionWithStable(uint64 teachingNftId, MockERC20 stableAsset)
        internal
    {
        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stableAsset.approve(address(registry), 800_000);
        registry.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stableAsset.approve(address(registry), 1_000_000);
        registry.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function _prepareTeachingSessionFor(TeachingRegistry target, uint64 teachingNftId) internal {
        VM.prank(teacher);
        target.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        target.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(target), 800_000);
        target.lockTeachingCollateral(teachingNftId, true);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(target), 800_000);
        target.lockTeachingCollateral(teachingNftId, false);
        VM.stopPrank();
    }

    function _completeTeachingLifecycle(uint64 teachingNftId) internal {
        _prepareTeachingSession(teachingNftId);
        _settlePreparedTeaching(teachingNftId);
    }

    function _settlePreparedTeaching(uint64 teachingNftId) internal {
        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingCompletion(teachingNftId, false);
    }

    function _settleTeachingAndMeasureSecondCompletion(uint64 teachingNftId)
        internal
        returns (uint256 gasUsed)
    {
        _prepareTeachingSession(teachingNftId);
        VM.warp(block.timestamp + 8 days);

        VM.prank(teacher);
        registry.confirmTeachingCompletion(teachingNftId, true);
        VM.prank(customer);
        uint256 gasBefore = gasleft();
        registry.confirmTeachingCompletion(teachingNftId, false);
        gasUsed = gasBefore - gasleft();
    }

    function _createResearchAssetWithPositions(
        string memory title,
        uint64 positionCount,
        uint16 shareBps
    ) internal returns (uint64 assetId) {
        VM.startPrank(coordinator);
        assetId = researchRegistry.createResearchAsset(title, "ipfs://scalable-asset");
        for (uint64 i = 0; i < positionCount;) {
            researchRegistry.createPatchPosition(
                SparkDaoTypes.CreatePatchPositionParams({
                    assetId: assetId,
                    layerIndex: 1,
                    layerShareBps: shareBps,
                    buybackFloor: 250_000,
                    decayWaitSeconds: 365 days,
                    decayPeriodSeconds: 365 days,
                    decayRateBps: 5_000,
                    beneficiary: address(uint160(0x9000 + i))
                })
            );
            unchecked {
                ++i;
            }
        }
        researchRegistry.sealLayer(assetId, 1);
        VM.stopPrank();
    }

    function _createResearchBackedTeachingSession(uint64 assetId, string memory courseTitle)
        internal
        returns (uint64 teachingNftId)
    {
        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType(
            courseTitle, 1_000_000, 400_000, SAFE_RESEARCH_SHARE_BPS
        );
        uint64[] memory linkedAssetIds = new uint64[](1);
        linkedAssetIds[0] = assetId;
        VM.prank(coordinator);
        teachingNftId = registry.createTeachingSession(
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
    }

    function _claimableAmount(uint64 teachingNftId, uint64 assetId, uint64 positionId)
        internal
        view
        returns (uint256 amount)
    {
        (amount,,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
    }

    function _deployUnwiredRegistry() internal returns (TeachingRegistry unwired) {
        unwired = _deployRegistryWithPolicy(address(faultPolicy));
    }

    function _deployRegistryWithEconomicsPolicy(address policy)
        internal
        returns (TeachingRegistry unwired)
    {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();
        unwired = _deployRegistryWithEconomicsPolicy(policy, linkedResearch);
    }

    function _deployRegistryWithEconomicsPolicy(address policy, ResearchRegistry linkedResearch)
        internal
        returns (TeachingRegistry unwired)
    {
        unwired = _deployRegistryWithEconomicsPolicyOnly(policy, linkedResearch);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(unwired));
    }

    function _deployRegistryWithEconomicsPolicyOnly(address policy, ResearchRegistry linkedResearch)
        internal
        returns (TeachingRegistry unwired)
    {
        unwired = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(linkedResearch),
            address(teachingToken),
            address(policyGuard),
            policy,
            address(faultPolicy)
        );
    }

    function _deployRegistryWithPolicy(address policy) internal returns (TeachingRegistry unwired) {
        ResearchRegistry linkedResearch = _deployAuxResearchRegistry();
        unwired = _deployRegistryWithPolicy(policy, linkedResearch);
    }

    function _deployRegistryWithPolicy(address policy, ResearchRegistry linkedResearch)
        internal
        returns (TeachingRegistry unwired)
    {
        unwired = _deployRegistryWithPolicyOnly(policy, linkedResearch);
        VM.prank(authority);
        linkedResearch.setTeachingRegistry(address(unwired));
    }

    function _deployRegistryWithPolicyOnly(address policy, ResearchRegistry linkedResearch)
        internal
        returns (TeachingRegistry unwired)
    {
        unwired = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(linkedResearch),
            address(teachingToken),
            address(policyGuard),
            address(economicsPolicy),
            policy
        );
    }

    function _assertCourseCreationRejectedByEconomicsPolicy(MockTeachingEconomicsPolicy policy)
        internal
    {
        VM.prank(authority);
        registry.updateDefaultTeachingEconomicsPolicy(address(policy));
        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingCourseType("Unsafe Economics Course", 1_000_000, 400_000, 0);
        VM.prank(authority);
        registry.updateDefaultTeachingEconomicsPolicy(address(economicsPolicy));
    }

    function _assertCourseCreationRejectedByPolicy(MockTeachingFaultPolicy policy) internal {
        VM.prank(authority);
        registry.updateDefaultTeachingFaultPolicy(address(policy));
        VM.expectRevert();
        VM.prank(coordinator);
        registry.createTeachingCourseType("Unsafe Policy Course", 1_000_000, 400_000, 0);
        VM.prank(authority);
        registry.updateDefaultTeachingFaultPolicy(address(faultPolicy));
    }

    function _deployAuxResearchRegistry() internal returns (ResearchRegistry linkedResearch) {
        linkedResearch = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );
        auxResearchRegistry = linkedResearch;
    }

    function _wireTokensTo(TeachingRegistry target, ResearchRegistry linkedResearch) internal {
        VM.prank(authority);
        researchToken.setMinter(address(linkedResearch));
        VM.prank(authority);
        teachingToken.setMinter(address(target));
    }

    function _createNoResearchTeachingSession(uint64 courseTypeId)
        internal
        returns (uint64 teachingNftId)
    {
        VM.prank(coordinator);
        teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp + 7 days),
                customerDiscountBps: 10_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );
    }

    function _confirmSchedule(uint64 teachingNftId) internal {
        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(customer);
        registry.confirmTeachingSchedule(teachingNftId, false);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }

    function _researchTokenId(uint64 assetId, uint64 positionId) internal pure returns (uint256) {
        return (uint256(assetId) << 64) | uint256(positionId);
    }
}
