// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

interface GasCalibrationVm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function writeFile(string calldata path, string calldata data) external;
    function writeLine(string calldata path, string calldata data) external;
}

contract TeachingGasCalibrationTest {
    GasCalibrationVm internal constant VM =
        GasCalibrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    string internal constant OUT = "teaching_gas_calibration.csv";

    TeachingRegistry internal registry;
    TeachingNftToken internal teachingToken;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal teacher = address(0x7001);
    address internal customer = address(0x7002);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);
    address internal contributorThree = address(0x1003);
    address internal contributorFour = address(0x1004);

    struct AssetBundle {
        uint64 firstAsset;
        uint64 secondAsset;
        uint256 setupGas;
    }

    struct PathInput {
        string path;
        string category;
        uint16 researchShareBps;
        uint64[] linkedAssetIds;
        uint16[] weights;
        bool forceValid;
        bool customerFault;
        bool teacherFault;
        bool mutateLayersBeforeResolution;
        uint64 firstAsset;
        uint64 secondAsset;
        uint64 firstAssetLayerOneA;
        uint64 firstAssetLayerOneB;
        uint64 firstAssetLayerTwo;
        uint64 secondAssetLayerOneA;
        uint64 secondAssetLayerTwo;
        uint256 setupGas;
    }

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://teaching/");
        registry = new TeachingRegistry(
            authority,
            coordinator,
            address(stable),
            90 days,
            30 days,
            address(researchToken),
            address(teachingToken)
        );
        VM.prank(authority);
        researchToken.setMinter(address(registry));
        VM.prank(authority);
        teachingToken.setMinter(address(registry));

        stable.mint(authority, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(customer, 1_000_000_000);
    }

    function testWriteTeachingGasCalibrationCsv() public {
        VM.writeFile(
            OUT, "path,category,total_gas,setup_gas,lesson_gas,valid_lesson,revenue_weight_bps\n"
        );

        _recordPath(_noResearch("ORD_NR", "ordinary", false, false, false));
        _recordPath(_zeroShare("ORD_ZS", "ordinary", false, false, false));
        _recordPath(_researchBacked("ORD_RB", "ordinary", false, false, false));
        _recordPath(_weightedMultiAsset("ORD_WM", "ordinary", false, false, false));
        _recordPath(_multiLayer("ORD_ML", "ordinary", false, false, false));

        _recordPath(_noResearch("FV_NR", "forced_valid", true, false, false));
        _recordPath(_zeroShare("FV_ZS", "forced_valid", true, false, false));
        _recordPath(_researchBacked("FV_RB", "forced_valid", true, false, false));
        _recordPath(_weightedMultiAsset("FV_WM", "forced_valid", true, false, false));
        _recordPath(_multiLayer("FV_ML", "forced_valid", true, false, false));

        _recordPath(_noResearch("CF_NR", "customer_fault", false, true, false));
        _recordPath(_zeroShare("CF_ZS", "customer_fault", false, true, false));
        _recordPath(_researchBacked("CF_RB", "customer_fault", false, true, false));
        _recordPath(_weightedMultiAsset("CF_WM", "customer_fault", false, true, false));
        _recordPath(_multiLayer("CF_ML", "customer_fault", false, true, false));

        _recordPath(_noResearch("TF_NR", "teacher_fault", false, false, true));
        _recordPath(_zeroShare("TF_ZS", "teacher_fault", false, false, true));
        _recordPath(_researchBacked("TF_RB", "teacher_fault", false, false, true));
        _recordPath(_weightedMultiAsset("TF_WM", "teacher_fault", false, false, true));
        _recordPath(_multiLayer("TF_ML", "teacher_fault", false, false, true));
    }

    function _recordPath(PathInput memory input) internal {
        (
            string memory path,
            string memory category,
            uint256 setupGas,
            uint256 lessonGas,
            bool validLesson,
            uint16 revenueWeightBps
        ) = _runPath(input);
        _record(path, category, setupGas, lessonGas, validLesson, revenueWeightBps);
    }

    function _runPath(PathInput memory input)
        internal
        returns (
            string memory path,
            string memory category,
            uint256 setupGas,
            uint256 lessonGas,
            bool validLesson,
            uint16 revenueWeightBps
        )
    {
        uint64 courseTypeId;
        uint256 gasUsed;

        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        courseTypeId = registry.createTeachingCourseType(
            input.path, 1_000_000, 400_000, input.researchShareBps
        );
        gasUsed = gasBefore - gasleft();
        lessonGas += gasUsed;

        uint64 scheduledAt = uint64(block.timestamp + 7 days);
        SparkDaoTypes.CreateTeachingSessionParams memory params =
            SparkDaoTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                customer: customer,
                scheduledAt: scheduledAt,
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: input.linkedAssetIds,
                linkedResearchWeightBps: input.weights
            });

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 teachingNftId = registry.createTeachingSession(params);
        gasUsed = gasBefore - gasleft();
        lessonGas += gasUsed;

        lessonGas += _confirmSchedule(teachingNftId, true);
        lessonGas += _confirmSchedule(teachingNftId, false);
        lessonGas += _approveStable(teacher, 800_000);
        lessonGas += _lockCollateral(teachingNftId, true);
        lessonGas += _approveStable(customer, 800_000);
        lessonGas += _lockCollateral(teachingNftId, false);

        if (input.mutateLayersBeforeResolution) {
            VM.warp(block.timestamp + 8 days);
            lessonGas += _advancePreparedLayers(input);
        }

        if (input.forceValid) {
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorForceTeachingValid(teachingNftId, 3);
            gasUsed = gasBefore - gasleft();
            lessonGas += gasUsed;
            lessonGas += _redeem(teachingNftId);
            validLesson = true;
            revenueWeightBps = 10_000;
        } else if (input.customerFault) {
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorResolveCustomerFault(teachingNftId, 2);
            gasUsed = gasBefore - gasleft();
            lessonGas += gasUsed;
            validLesson = false;
            revenueWeightBps = 5_000;
        } else if (input.teacherFault) {
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorResolveTeacherFault(teachingNftId, 4);
            gasUsed = gasBefore - gasleft();
            lessonGas += gasUsed;
            validLesson = false;
            revenueWeightBps = 5_000;
        } else {
            VM.warp(uint256(scheduledAt) + 8 days);
            lessonGas += _confirmCompletion(teachingNftId, true);
            lessonGas += _confirmCompletion(teachingNftId, false);
            lessonGas += _redeem(teachingNftId);
            validLesson = true;
            revenueWeightBps = 10_000;
        }

        (uint8 status,,,,,) = registry.getTeachingSessionState(teachingNftId);
        if (input.teacherFault) {
            assert(status == 4);
        } else if (input.customerFault) {
            assert(status == 5);
        } else {
            assert(status == 7);
        }

        path = input.path;
        category = input.category;
        setupGas = input.setupGas;
    }

    function _noResearch(
        string memory path,
        string memory category,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal pure returns (PathInput memory input) {
        input.path = path;
        input.category = category;
        input.linkedAssetIds = new uint64[](0);
        input.weights = new uint16[](0);
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
    }

    function _zeroShare(
        string memory path,
        string memory category,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal returns (PathInput memory input) {
        AssetBundle memory bundle = _oneLayerOnePosition(path);
        input = _oneAssetInput(path, category, bundle, 0, forceValid, customerFault, teacherFault);
    }

    function _researchBacked(
        string memory path,
        string memory category,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal returns (PathInput memory input) {
        AssetBundle memory bundle = _oneLayerTwoPositions(path);
        input = _oneAssetInput(
            path, category, bundle, 2_500, forceValid, customerFault, teacherFault
        );
    }

    function _weightedMultiAsset(
        string memory path,
        string memory category,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal returns (PathInput memory input) {
        AssetBundle memory bundleOne = _oneLayerOnePosition(string.concat(path, "_A"));
        AssetBundle memory bundleTwo = _oneLayerOnePosition(string.concat(path, "_B"));
        input.path = path;
        input.category = category;
        input.researchShareBps = 2_500;
        input.linkedAssetIds = new uint64[](2);
        input.linkedAssetIds[0] = bundleOne.firstAsset;
        input.linkedAssetIds[1] = bundleTwo.firstAsset;
        input.weights = new uint16[](2);
        input.weights[0] = 7_000;
        input.weights[1] = 3_000;
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.firstAsset = bundleOne.firstAsset;
        input.secondAsset = bundleTwo.firstAsset;
        input.setupGas = bundleOne.setupGas + bundleTwo.setupGas;
    }

    function _multiLayer(
        string memory path,
        string memory category,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal returns (PathInput memory input) {
        input.path = path;
        input.category = category;
        input.researchShareBps = 2_500;
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.mutateLayersBeforeResolution = true;

        AssetBundle memory first = _twoLayerAsset(path, "_A", contributorOne, contributorThree);
        AssetBundle memory second = _twoLayerAsset(path, "_B", contributorTwo, contributorFour);

        input.linkedAssetIds = new uint64[](2);
        input.linkedAssetIds[0] = first.firstAsset;
        input.linkedAssetIds[1] = second.firstAsset;
        input.weights = new uint16[](2);
        input.weights[0] = 7_000;
        input.weights[1] = 3_000;
        input.firstAsset = first.firstAsset;
        input.secondAsset = second.firstAsset;
        input.firstAssetLayerOneA = uint64(uint256(first.secondAsset));
        input.firstAssetLayerTwo = uint64(first.setupGas >> 128);
        input.secondAssetLayerOneA = uint64(uint256(second.secondAsset));
        input.secondAssetLayerTwo = uint64(second.setupGas >> 128);
        input.setupGas = uint128(first.setupGas) + uint128(second.setupGas);
    }

    function _oneAssetInput(
        string memory path,
        string memory category,
        AssetBundle memory bundle,
        uint16 researchShareBps,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal pure returns (PathInput memory input) {
        input.path = path;
        input.category = category;
        input.researchShareBps = researchShareBps;
        input.linkedAssetIds = new uint64[](1);
        input.linkedAssetIds[0] = bundle.firstAsset;
        input.weights = new uint16[](0);
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.firstAsset = bundle.firstAsset;
        input.setupGas = bundle.setupGas;
    }

    function _oneLayerOnePosition(string memory salt) internal returns (AssetBundle memory bundle) {
        uint256 setupGas;
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        uint64 assetId = registry.createResearchAsset(
            string.concat("Asset_", salt), string.concat("ipfs://", salt)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 positionId = registry.createPatchPosition(
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
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        bundle.firstAsset = assetId;
        bundle.secondAsset = positionId;
        bundle.setupGas = setupGas;
    }

    function _oneLayerTwoPositions(string memory salt)
        internal
        returns (AssetBundle memory bundle)
    {
        uint256 setupGas;
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        uint64 assetId = registry.createResearchAsset(
            string.concat("Research_", salt), string.concat("ipfs://", salt)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.createPatchPosition(
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
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.createPatchPosition(
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
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        bundle.firstAsset = assetId;
        bundle.setupGas = setupGas;
    }

    function _twoLayerAsset(
        string memory path,
        string memory suffix,
        address layerOneHolder,
        address layerTwoHolder
    ) internal returns (AssetBundle memory bundle) {
        uint256 setupGas;
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        uint64 assetId = registry.createResearchAsset(
            string.concat(path, suffix), string.concat("ipfs://", path, suffix)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 layerOnePosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: layerOneHolder
            })
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 5_000,
                beneficiary: layerTwoHolder
            })
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.sealLayer(assetId, 2);
        setupGas += gasBefore - gasleft();

        bundle.firstAsset = assetId;
        bundle.secondAsset = layerOnePosition;
        bundle.setupGas = (uint256(layerTwoPosition) << 128) | setupGas;
    }

    function _advancePreparedLayers(PathInput memory input) internal returns (uint256 gasUsed) {
        uint64[] memory prepared = new uint64[](1);
        uint256 gasBefore;

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.markPositionReady(input.firstAsset, input.firstAssetLayerOneA);
        gasUsed += gasBefore - gasleft();

        prepared[0] = input.firstAssetLayerTwo;
        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.advanceLayer(input.firstAsset, prepared);
        gasUsed += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.markPositionReady(input.secondAsset, input.secondAssetLayerOneA);
        gasUsed += gasBefore - gasleft();

        prepared[0] = input.secondAssetLayerTwo;
        VM.prank(coordinator);
        gasBefore = gasleft();
        registry.advanceLayer(input.secondAsset, prepared);
        gasUsed += gasBefore - gasleft();
    }

    function _confirmSchedule(uint64 teachingNftId, bool teacherSide)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(teacherSide ? teacher : customer);
        uint256 gasBefore = gasleft();
        registry.confirmTeachingSchedule(teachingNftId, teacherSide);
        gasUsed = gasBefore - gasleft();
    }

    function _approveStable(address owner, uint256 amount) internal returns (uint256 gasUsed) {
        VM.prank(owner);
        uint256 gasBefore = gasleft();
        stable.approve(address(registry), amount);
        gasUsed = gasBefore - gasleft();
    }

    function _lockCollateral(uint64 teachingNftId, bool teacherSide)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(teacherSide ? teacher : customer);
        uint256 gasBefore = gasleft();
        registry.lockTeachingCollateral(teachingNftId, teacherSide);
        gasUsed = gasBefore - gasleft();
    }

    function _confirmCompletion(uint64 teachingNftId, bool teacherSide)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(teacherSide ? teacher : customer);
        uint256 gasBefore = gasleft();
        registry.confirmTeachingCompletion(teachingNftId, teacherSide);
        gasUsed = gasBefore - gasleft();
    }

    function _redeem(uint64 teachingNftId) internal returns (uint256 gasUsed) {
        VM.warp(block.timestamp + 31 days);
        VM.prank(teacher);
        uint256 gasBefore = gasleft();
        registry.redeemTeachingPayout(teachingNftId);
        gasUsed = gasBefore - gasleft();
    }

    function _record(
        string memory path,
        string memory category,
        uint256 setupGas,
        uint256 lessonGas,
        bool validLesson,
        uint16 revenueWeightBps
    ) internal {
        VM.writeLine(
            OUT,
            string.concat(
                path,
                ",",
                category,
                ",",
                _u(setupGas + lessonGas),
                ",",
                _u(setupGas),
                ",",
                _u(lessonGas),
                ",",
                _b(validLesson),
                ",",
                _u(revenueWeightBps)
            )
        );
    }

    function _u(uint256 value) internal pure returns (string memory) {
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

    function _b(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }
}
