// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {TeachingRegistry} from "../src/TeachingRegistry.sol";
interface Vm {
    function envAddress(string calldata name) external returns (address);
    function envUint(string calldata name) external returns (uint256);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployRegistry {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (address registryAddress) {
        address authority = VM.envAddress("DAO_AUTHORITY");
        address coordinator = VM.envAddress("DAO_COORDINATOR");
        address stableAsset = VM.envAddress("STABLE_ASSET");
        address researchPositionToken = VM.envAddress("RESEARCH_POSITION_TOKEN");
        address teachingNftToken = VM.envAddress("TEACHING_NFT_TOKEN");
        uint64 rewardUnlockSeconds = uint64(VM.envUint("REWARD_UNLOCK_SECONDS"));
        uint64 buybackWaitSeconds = uint64(VM.envUint("BUYBACK_WAIT_SECONDS"));

        VM.startBroadcast();

        TeachingRegistry registry = new TeachingRegistry(
            authority,
            coordinator,
            stableAsset,
            rewardUnlockSeconds,
            buybackWaitSeconds,
            researchPositionToken,
            teachingNftToken
        );

        VM.stopBroadcast();

        registryAddress = address(registry);
    }
}
