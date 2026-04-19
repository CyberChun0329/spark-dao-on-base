// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ResearchPositionToken} from "../src/ResearchPositionToken.sol";
import {TeachingNftToken} from "../src/TeachingNftToken.sol";

interface Vm {
    function envAddress(string calldata name) external returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract SetTokenMinters {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external {
        address registry = VM.envAddress("TEACHING_REGISTRY");
        address researchPositionToken = VM.envAddress("RESEARCH_POSITION_TOKEN");
        address teachingNftToken = VM.envAddress("TEACHING_NFT_TOKEN");

        VM.startBroadcast();

        ResearchPositionToken(researchPositionToken).setMinter(registry);
        TeachingNftToken(teachingNftToken).setMinter(registry);

        VM.stopBroadcast();
    }
}
