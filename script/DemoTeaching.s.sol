// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256);
    function addr(uint256 privateKey) external returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DemoTeaching {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DemoDeployment {
        address stableAsset;
        address researchPositionToken;
        address teachingNftToken;
        address registry;
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
        TeachingRegistry registry = new TeachingRegistry(
            authority,
            coordinator,
            address(stable),
            0,
            0,
            address(researchToken),
            address(teachingToken)
        );
        researchToken.setMinter(address(registry));
        teachingToken.setMinter(address(registry));
        stable.mint(authority, 5_000_000_000);
        stable.mint(teacher, 5_000_000_000);
        stable.mint(customer, 5_000_000_000);
        VM.stopBroadcast();

        VM.startBroadcast(coordinatorPk);
        uint64 assetId =
            registry.createResearchAsset("Demo Teaching Research", "ipfs://demo-teaching-research");
        uint64 positionOneId = registry.createPatchPosition(
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
        uint64 positionTwoId = registry.createPatchPosition(
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
        registry.sealLayer(assetId, 1);

        uint64 courseTypeId =
            registry.createTeachingCourseType("Demo Teaching Course", 1_000_000, 400_000, 2_000);
        uint64[] memory assetIds = new uint64[](1);
        assetIds[0] = assetId;
        uint16[] memory weights = new uint16[](1);
        weights[0] = 10_000;
        uint64 teachingNftId = registry.createTeachingSession(
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: uint64(block.timestamp),
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: assetIds,
                linkedResearchWeightBps: weights
            })
        );
        VM.stopBroadcast();

        VM.startBroadcast(teacherPk);
        registry.confirmTeachingSchedule(teachingNftId, true);
        stable.approve(address(registry), type(uint256).max);
        VM.stopBroadcast();

        VM.startBroadcast(customerPk);
        registry.confirmTeachingSchedule(teachingNftId, false);
        stable.approve(address(registry), type(uint256).max);
        VM.stopBroadcast();

        VM.startBroadcast(teacherPk);
        registry.lockTeachingCollateral(teachingNftId, true);
        registry.acknowledgeTeachingCompletion(teachingNftId, true);
        VM.stopBroadcast();

        VM.startBroadcast(customerPk);
        registry.lockTeachingCollateral(teachingNftId, false);
        registry.confirmTeachingCompletion(teachingNftId, false);
        VM.stopBroadcast();

        VM.startBroadcast(contributorOnePk);
        registry.claimTeachingReward(assetId, positionOneId);
        VM.stopBroadcast();

        VM.startBroadcast(contributorTwoPk);
        registry.claimTeachingReward(assetId, positionTwoId);
        VM.stopBroadcast();

        deployment = DemoDeployment({
            stableAsset: address(stable),
            researchPositionToken: address(researchToken),
            teachingNftToken: address(teachingToken),
            registry: address(registry),
            assetId: assetId,
            teachingNftId: teachingNftId,
            contributorOnePositionId: positionOneId,
            contributorTwoPositionId: positionTwoId
        });
    }
}
