// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ResearchRegistry} from "../src/ResearchRegistry.sol";
import {ResearchPositionToken} from "../src/ResearchPositionToken.sol";
import {SparkDaoTypes} from "../src/SparkDaoTypes.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

interface ResearchGasCalibrationVm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function writeFile(string calldata path, string calldata data) external;
    function writeLine(string calldata path, string calldata data) external;
}

contract ResearchGasCalibrationTest {
    ResearchGasCalibrationVm internal constant VM =
        ResearchGasCalibrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant OUT = "research_gas_calibration.csv";

    ResearchRegistry internal registry;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        registry = new ResearchRegistry(
            authority,
            coordinator,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );

        VM.prank(authority);
        researchToken.setMinter(address(registry));
    }

    function testWriteResearchGasCalibrationCsv() public {
        VM.writeFile(OUT, "path,gas\n");

        VM.startPrank(coordinator);

        uint256 gasBefore = gasleft();
        uint64 assetId = registry.createResearchAsset("Calibration", "ipfs://calibration");
        _record("createResearchAsset", gasBefore - gasleft());

        gasBefore = gasleft();
        uint64 layerOnePositionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100 ether,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        _record("createPatchPosition_current", gasBefore - gasleft());

        gasBefore = gasleft();
        registry.sealLayer(assetId, 1);
        _record("sealLayer_current", gasBefore - gasleft());

        gasBefore = gasleft();
        uint64 preparedLayerTwoPositionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 100 ether,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        _record("createPatchPosition_prepared", gasBefore - gasleft());

        gasBefore = gasleft();
        registry.sealLayer(assetId, 2);
        _record("sealLayer_prepared", gasBefore - gasleft());

        VM.stopPrank();

        VM.prank(contributorOne);
        gasBefore = gasleft();
        registry.approveEarlyDecay(assetId, layerOnePositionId);
        _record("approveEarlyDecay", gasBefore - gasleft());

        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = preparedLayerTwoPositionId;
        gasBefore = gasleft();
        registry.advanceLayer(assetId, preparedPositionIds);
        _record("advanceLayer", gasBefore - gasleft());
    }

    function _record(string memory path, uint256 gasUsed) internal {
        VM.writeLine(OUT, string.concat(path, ",", _toString(gasUsed)));
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}
