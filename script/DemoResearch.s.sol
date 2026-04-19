// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ResearchRegistry} from "../src/ResearchRegistry.sol";
import {ResearchPositionToken} from "../src/ResearchPositionToken.sol";
import {SparkDaoTypes} from "../src/SparkDaoTypes.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

interface Vm {
    function envUint(string calldata name) external returns (uint256);
    function addr(uint256 privateKey) external returns (address);
    function startBroadcast(uint256 privateKey) external;
    function stopBroadcast() external;
}

contract DemoResearch {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct DemoDeployment {
        address stableAsset;
        address researchPositionToken;
        address registry;
        uint64 assetId;
        uint64 layerOnePositionId;
        uint64 layerTwoPositionId;
    }

    function run() external returns (DemoDeployment memory deployment) {
        uint256 authorityPk = VM.envUint("DEMO_AUTHORITY_PRIVATE_KEY");
        uint256 coordinatorPk = VM.envUint("DEMO_COORDINATOR_PRIVATE_KEY");
        uint256 contributorOnePk = VM.envUint("DEMO_CONTRIBUTOR_ONE_PRIVATE_KEY");
        uint256 contributorTwoPk = VM.envUint("DEMO_CONTRIBUTOR_TWO_PRIVATE_KEY");

        address authority = VM.addr(authorityPk);
        address coordinator = VM.addr(coordinatorPk);
        address contributorOne = VM.addr(contributorOnePk);
        address contributorTwo = VM.addr(contributorTwoPk);

        VM.startBroadcast(authorityPk);
        MockERC20 stable = new MockERC20("USD Coin", "USDC", 6);
        ResearchPositionToken researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://demo-research/"
        );
        ResearchRegistry registry =
            new ResearchRegistry(authority, coordinator, address(stable), 0, 0, address(researchToken));
        researchToken.setMinter(address(registry));
        stable.mint(authority, 5_000_000_000);
        VM.stopBroadcast();

        VM.startBroadcast(coordinatorPk);
        uint64 assetId = registry.createResearchAsset("Demo Research Asset", "ipfs://demo-research-asset");
        uint64 positionOneId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 200_000_000,
                decayWaitSeconds: 0,
                decayPeriodSeconds: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS,
                decayRateBps: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_RATE_BPS,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 positionTwoId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 10_000,
                buybackFloor: 250_000_000,
                decayWaitSeconds: 0,
                decayPeriodSeconds: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_PERIOD_SECONDS,
                decayRateBps: SparkDaoTypes.DEFAULT_RESEARCH_DECAY_RATE_BPS,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 2);
        VM.stopBroadcast();

        VM.startBroadcast(contributorOnePk);
        registry.approveEarlyDecay(assetId, positionOneId);
        registry.markPositionReady(assetId, positionOneId);
        VM.stopBroadcast();

        VM.startBroadcast(coordinatorPk);
        uint64[] memory preparedPositions = new uint64[](1);
        preparedPositions[0] = positionTwoId;
        registry.advanceLayer(assetId, preparedPositions);
        VM.stopBroadcast();

        VM.startBroadcast(authorityPk);
        stable.approve(address(registry), type(uint256).max);
        registry.createRevenueEscrow(assetId, positionTwoId, 125_000_000);
        registry.fundDaoVault(500_000_000);
        VM.stopBroadcast();

        VM.startBroadcast(contributorTwoPk);
        registry.claimRevenue(assetId, positionTwoId, 0);
        registry.sellPositionBackToDao(assetId, positionTwoId);
        VM.stopBroadcast();

        deployment = DemoDeployment({
            stableAsset: address(stable),
            researchPositionToken: address(researchToken),
            registry: address(registry),
            assetId: assetId,
            layerOnePositionId: positionOneId,
            layerTwoPositionId: positionTwoId
        });
    }
}
