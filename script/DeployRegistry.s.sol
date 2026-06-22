// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingPricingPolicyV1 } from "../src/TeachingPricingPolicyV1.sol";
import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";
import { ResearchRegistry } from "../src/ResearchRegistry.sol";

interface Vm {
    function envAddress(string calldata name) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployRegistry {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run()
        external
        returns (
            address researchRegistryAddress,
            address teachingRegistryAddress,
            address teachingRewardDistributorAddress,
            address teachingPricingPolicyAddress,
            address teachingNftTokenAddress
        )
    {
        address authority = VM.envAddress("DAO_AUTHORITY");
        address coordinator = VM.envAddress("DAO_COORDINATOR");
        address treasury = VM.envAddress("DAO_TREASURY");
        address stableAsset = VM.envAddress("STABLE_ASSET");
        address researchPositionToken = VM.envAddress("RESEARCH_POSITION_TOKEN");
        address teachingNftToken = VM.envAddress("TEACHING_NFT_TOKEN");
        uint256 rewardUnlockSecondsRaw = VM.envUint("REWARD_UNLOCK_SECONDS");
        uint256 buybackWaitSecondsRaw = VM.envUint("BUYBACK_WAIT_SECONDS");
        require(rewardUnlockSecondsRaw <= type(uint64).max, "REWARD_UNLOCK_SECONDS too large");
        require(buybackWaitSecondsRaw <= type(uint64).max, "BUYBACK_WAIT_SECONDS too large");
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 rewardUnlockSeconds = uint64(rewardUnlockSecondsRaw);
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 buybackWaitSeconds = uint64(buybackWaitSecondsRaw);

        VM.startBroadcast();

        ResearchRegistry researchRegistry = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            stableAsset,
            rewardUnlockSeconds,
            buybackWaitSeconds,
            researchPositionToken
        );
        TeachingPricingPolicyV1 teachingPricingPolicy = new TeachingPricingPolicyV1();
        TeachingRegistry teachingRegistry = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            stableAsset,
            rewardUnlockSeconds,
            buybackWaitSeconds,
            address(researchRegistry),
            address(teachingPricingPolicy),
            teachingNftToken
        );
        TeachingRewardDistributor teachingRewardDistributor =
            new TeachingRewardDistributor(address(teachingRegistry), address(researchRegistry));
        researchRegistry.setTeachingRegistry(address(teachingRegistry));
        teachingRegistry.setTeachingRewardDistributor(address(teachingRewardDistributor));

        VM.stopBroadcast();

        researchRegistryAddress = address(researchRegistry);
        teachingRegistryAddress = address(teachingRegistry);
        teachingRewardDistributorAddress = address(teachingRewardDistributor);
        teachingPricingPolicyAddress = address(teachingPricingPolicy);
        teachingNftTokenAddress = teachingNftToken;
    }
}
