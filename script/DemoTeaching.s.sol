// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingPricingPolicyV1 } from "../src/TeachingPricingPolicyV1.sol";
import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { ResearchRegistry } from "../src/ResearchRegistry.sol";
import { SparkTeachingTypes } from "../src/SparkTeachingTypes.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256);
    function addr(uint256 privateKey) external returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
    function warp(uint256 timestamp) external;
}

contract DemoTeaching {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DemoDeployment {
        address stableAsset;
        address researchPositionToken;
        address teachingNftToken;
        address pricingPolicy;
        address researchRegistry;
        address teachingRegistry;
        address rewardDistributor;
        uint64 assetId;
        uint64 teachingNftId;
        uint64 contributorOnePositionId;
        uint64 contributorTwoPositionId;
    }

    function run() external returns (DemoDeployment memory deployment) {
        uint256 authorityPk = VM.envUint("DEMO_AUTHORITY_PRIVATE_KEY");
        uint256 coordinatorPk = VM.envUint("DEMO_COORDINATOR_PRIVATE_KEY");
        uint256 teacherPk = VM.envUint("DEMO_TEACHER_PRIVATE_KEY");
        uint256 customerPk = VM.envUint("DEMO_CUSTOMER_PRIVATE_KEY");
        uint256 contributorOnePk = VM.envUint("DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY");
        uint256 contributorTwoPk = VM.envUint("DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY");

        address authority = VM.addr(authorityPk);
        address coordinator = VM.addr(coordinatorPk);
        address teacher = VM.addr(teacherPk);
        address customer = VM.addr(customerPk);
        address contributorOne = VM.addr(contributorOnePk);
        address contributorTwo = VM.addr(contributorTwoPk);

        VM.startBroadcast(authorityPk);
        MockERC20 stable = new MockERC20("USD Coin", "USDC", 6);
        ResearchPositionToken researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://demo-research/"
        );
        TeachingNftToken teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://demo-teaching/");
        TeachingPricingPolicyV1 pricingPolicy = new TeachingPricingPolicyV1();
        ResearchRegistry researchRegistry = new ResearchRegistry(
            authority, coordinator, authority, address(stable), 0, 0, address(researchToken)
        );
        TeachingRegistry teaching = new TeachingRegistry(
            authority,
            coordinator,
            authority,
            address(stable),
            0,
            0,
            address(researchRegistry),
            address(pricingPolicy),
            address(teachingToken)
        );
        TeachingRewardDistributor rewardDistributor =
            new TeachingRewardDistributor(address(teaching), address(researchRegistry));
        researchRegistry.setTeachingRegistry(address(teaching));
        teaching.setTeachingRewardDistributor(address(rewardDistributor));
        researchToken.setMinter(address(researchRegistry));
        teachingToken.setMinter(address(teaching));
        researchToken.lockMinter();
        teachingToken.lockMinter();
        stable.mint(teacher, 5_000_000_000);
        stable.mint(customer, 5_000_000_000);
        stable.mint(contributorTwo, 5_000_000_000);
        VM.stopBroadcast();

        VM.startBroadcast(coordinatorPk);
        uint64 assetId = researchRegistry.createResearchAsset(
            "Demo Teaching Research", "ipfs://demo-teaching"
        );
        uint64 positionOneId = researchRegistry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 200_000_000,
                decayWaitSeconds: 0,
                decayPeriodSeconds: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS,
                decayRateBps: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_RATE_BPS,
                beneficiary: contributorOne
            })
        );
        uint64 positionTwoId = researchRegistry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 150_000_000,
                decayWaitSeconds: 0,
                decayPeriodSeconds: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS,
                decayRateBps: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_RATE_BPS,
                beneficiary: contributorTwo
            })
        );
        researchRegistry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            teaching.createTeachingCourseType("Demo Teaching", 1_000_000, 400_000, 1_000);
        address[] memory students = new address[](2);
        students[0] = customer;
        students[1] = contributorTwo;
        uint64[] memory assetIds = new uint64[](1);
        assetIds[0] = assetId;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10_000;
        uint64 teachingNftId = teaching.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: uint64(block.timestamp + 1),
                customerDiscountBps: 10_000,
                linkedResearchAssetIds: assetIds,
                linkedResearchWeightBps: weights
            })
        );
        teaching.confirmTeachingSchedule(teachingNftId, false);
        VM.stopBroadcast();

        VM.startBroadcast(teacherPk);
        teaching.confirmTeachingSchedule(teachingNftId, true);
        stable.approve(address(teaching), type(uint256).max);
        teaching.lockTeachingTeacherBond(teachingNftId);
        VM.stopBroadcast();

        VM.startBroadcast(customerPk);
        stable.approve(address(teaching), type(uint256).max);
        teaching.payTeachingSeat(teachingNftId, 0);
        VM.stopBroadcast();

        VM.startBroadcast(contributorTwoPk);
        stable.approve(address(teaching), type(uint256).max);
        teaching.payTeachingSeat(teachingNftId, 1);
        VM.stopBroadcast();

        VM.warp(block.timestamp + 1);

        VM.startBroadcast(customerPk);
        teaching.confirmTeachingAttendance(teachingNftId, 0);
        VM.stopBroadcast();

        VM.startBroadcast(contributorTwoPk);
        teaching.confirmTeachingAttendance(teachingNftId, 1);
        VM.stopBroadcast();

        VM.startBroadcast(teacherPk);
        teaching.confirmTeachingDelivery(teachingNftId);
        VM.stopBroadcast();

        VM.startBroadcast(contributorOnePk);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionOneId);
        VM.stopBroadcast();

        VM.startBroadcast(contributorTwoPk);
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionTwoId);
        VM.stopBroadcast();

        deployment = DemoDeployment({
            stableAsset: address(stable),
            researchPositionToken: address(researchToken),
            teachingNftToken: address(teachingToken),
            pricingPolicy: address(pricingPolicy),
            researchRegistry: address(researchRegistry),
            teachingRegistry: address(teaching),
            rewardDistributor: address(rewardDistributor),
            assetId: assetId,
            teachingNftId: teachingNftId,
            contributorOnePositionId: positionOneId,
            contributorTwoPositionId: positionTwoId
        });
    }
}
