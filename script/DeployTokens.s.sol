// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ResearchPositionToken} from "../src/ResearchPositionToken.sol";
import {TeachingNftToken} from "../src/TeachingNftToken.sol";

interface Vm {
    function envAddress(string calldata name) external returns (address);
    function envString(string calldata name) external returns (string memory);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract DeployTokens {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct Deployment {
        address researchPositionToken;
        address teachingNftToken;
    }

    function run() external returns (Deployment memory deployment) {
        address authority = VM.envAddress("DAO_AUTHORITY");
        string memory researchBaseUri = VM.envString("RESEARCH_BASE_URI");
        string memory teachingBaseUri = VM.envString("TEACHING_BASE_URI");

        VM.startBroadcast();

        ResearchPositionToken researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", researchBaseUri
        );
        TeachingNftToken teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", teachingBaseUri);

        VM.stopBroadcast();

        deployment = Deployment({
            researchPositionToken: address(researchToken),
            teachingNftToken: address(teachingToken)
        });
    }
}
