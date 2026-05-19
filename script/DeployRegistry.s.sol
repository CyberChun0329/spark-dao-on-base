// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";

interface Vm {
    function envAddress(string calldata name) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployRegistry {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (address registryAddress, address rewardDistributorAddress) {
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

        TeachingRegistry registry = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            stableAsset,
            rewardUnlockSeconds,
            buybackWaitSeconds,
            researchPositionToken,
            teachingNftToken
        );
        TeachingRewardDistributor rewardDistributor =
            new TeachingRewardDistributor(address(registry));
        registry.setTeachingRewardDistributor(address(rewardDistributor));

        VM.stopBroadcast();

        registryAddress = address(registry);
        rewardDistributorAddress = address(rewardDistributor);
    }
}
