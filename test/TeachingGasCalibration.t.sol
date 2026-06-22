// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TeachingPricingPolicyV1 } from "../src/TeachingPricingPolicyV1.sol";
import { TeachingRegistry } from "../src/TeachingRegistry.sol";
import { TeachingRewardDistributor } from "../src/TeachingRewardDistributor.sol";
import { ResearchRegistry } from "../src/ResearchRegistry.sol";
import { TeachingNftToken } from "../src/TeachingNftToken.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkTeachingTypes } from "../src/SparkTeachingTypes.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

interface GasCalibrationVm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function removeFile(string calldata path) external;
    function writeFile(string calldata path, string calldata data) external;
    function writeLine(string calldata path, string calldata data) external;
}

abstract contract TeachingGasCalibrationHarness {
    GasCalibrationVm internal constant VM =
        GasCalibrationVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    uint16 internal constant SAFE_RESEARCH_SHARE_BPS = 1_000;

    TeachingRegistry internal registry;
    ResearchRegistry internal researchRegistry;
    TeachingRewardDistributor internal rewardDistributor;
    TeachingPricingPolicyV1 internal pricingPolicy;
    TeachingNftToken internal teachingToken;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal treasury = address(0xDA01);
    address internal teacher = address(0x7001);
    address internal customer = address(0x7002);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);
    address internal contributorThree = address(0x1003);
    address internal contributorFour = address(0x1004);

    struct AssetBundle {
        uint64 assetId;
        uint64 layerOnePositionA;
        uint64 layerOnePositionB;
        uint64 layerTwoPosition;
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
        uint64 secondAssetLayerOneB;
        uint64 secondAssetLayerTwo;
        address firstAssetLayerOneAHolder;
        address firstAssetLayerOneBHolder;
        address secondAssetLayerOneAHolder;
        address secondAssetLayerOneBHolder;
        uint256 setupGas;
    }

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        teachingToken =
            new TeachingNftToken(authority, "Spark Teaching NFT", "STN", "ipfs://teaching/");
        pricingPolicy = new TeachingPricingPolicyV1();
        researchRegistry = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );
        registry = new TeachingRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchRegistry),
            address(pricingPolicy),
            address(teachingToken)
        );
        rewardDistributor =
            new TeachingRewardDistributor(address(registry), address(researchRegistry));
        VM.prank(authority);
        researchRegistry.setTeachingRegistry(address(registry));
        VM.prank(authority);
        registry.setTeachingRewardDistributor(address(rewardDistributor));
        VM.prank(authority);
        researchToken.setMinter(address(researchRegistry));
        VM.prank(authority);
        teachingToken.setMinter(address(registry));

        stable.mint(authority, 1_000_000_000);
        stable.mint(teacher, 1_000_000_000);
        stable.mint(customer, 1_000_000_000);
    }

    function _clearOutput(string memory path) internal {
        try VM.removeFile(path) { } catch { }
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
            path, category, bundle, SAFE_RESEARCH_SHARE_BPS, forceValid, customerFault, teacherFault
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
        input.researchShareBps = SAFE_RESEARCH_SHARE_BPS;
        input.linkedAssetIds = new uint64[](2);
        input.linkedAssetIds[0] = bundleOne.assetId;
        input.linkedAssetIds[1] = bundleTwo.assetId;
        input.weights = new uint16[](2);
        input.weights[0] = 7_000;
        input.weights[1] = 3_000;
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.firstAsset = bundleOne.assetId;
        input.secondAsset = bundleTwo.assetId;
        input.firstAssetLayerOneA = bundleOne.layerOnePositionA;
        input.secondAssetLayerOneA = bundleTwo.layerOnePositionA;
        input.firstAssetLayerOneAHolder = contributorOne;
        input.secondAssetLayerOneAHolder = contributorOne;
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
        input.researchShareBps = SAFE_RESEARCH_SHARE_BPS;
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.mutateLayersBeforeResolution = true;

        AssetBundle memory first = _twoLayerAsset(path, "_A", contributorOne, contributorThree);
        AssetBundle memory second = _twoLayerAsset(path, "_B", contributorTwo, contributorFour);

        input.linkedAssetIds = new uint64[](2);
        input.linkedAssetIds[0] = first.assetId;
        input.linkedAssetIds[1] = second.assetId;
        input.weights = new uint16[](2);
        input.weights[0] = 7_000;
        input.weights[1] = 3_000;
        input.firstAsset = first.assetId;
        input.secondAsset = second.assetId;
        input.firstAssetLayerOneA = first.layerOnePositionA;
        input.firstAssetLayerTwo = first.layerTwoPosition;
        input.secondAssetLayerOneA = second.layerOnePositionA;
        input.secondAssetLayerTwo = second.layerTwoPosition;
        input.firstAssetLayerOneAHolder = contributorOne;
        input.secondAssetLayerOneAHolder = contributorTwo;
        input.setupGas = first.setupGas + second.setupGas;
    }

    function _oneAssetInput(
        string memory path,
        string memory category,
        AssetBundle memory bundle,
        uint16 researchShareBps,
        bool forceValid,
        bool customerFault,
        bool teacherFault
    ) internal view returns (PathInput memory input) {
        input.path = path;
        input.category = category;
        input.researchShareBps = researchShareBps;
        input.linkedAssetIds = new uint64[](1);
        input.linkedAssetIds[0] = bundle.assetId;
        input.weights = new uint16[](0);
        input.forceValid = forceValid;
        input.customerFault = customerFault;
        input.teacherFault = teacherFault;
        input.firstAsset = bundle.assetId;
        input.firstAssetLayerOneA = bundle.layerOnePositionA;
        input.firstAssetLayerOneB = bundle.layerOnePositionB;
        input.firstAssetLayerOneAHolder = contributorOne;
        input.firstAssetLayerOneBHolder = contributorTwo;
        input.setupGas = bundle.setupGas;
    }

    function _oneLayerOnePosition(string memory salt) internal returns (AssetBundle memory bundle) {
        uint256 setupGas;
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        uint64 assetId = researchRegistry.createResearchAsset(
            string.concat("Asset_", salt), string.concat("ipfs://", salt)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 positionId = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        bundle.assetId = assetId;
        bundle.layerOnePositionA = positionId;
        bundle.setupGas = setupGas;
    }

    function _oneLayerTwoPositions(string memory salt)
        internal
        returns (AssetBundle memory bundle)
    {
        uint256 setupGas;
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        uint64 assetId = researchRegistry.createResearchAsset(
            string.concat("Research_", salt), string.concat("ipfs://", salt)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 positionA = researchRegistry.createPatchPosition(
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
        uint64 positionB = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        bundle.assetId = assetId;
        bundle.layerOnePositionA = positionA;
        bundle.layerOnePositionB = positionB;
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
        uint64 assetId = researchRegistry.createResearchAsset(
            string.concat(path, suffix), string.concat("ipfs://", path, suffix)
        );
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 layerOnePosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 1);
        setupGas += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 layerTwoPosition = researchRegistry.createPatchPosition(
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
        researchRegistry.sealLayer(assetId, 2);
        setupGas += gasBefore - gasleft();

        bundle.assetId = assetId;
        bundle.layerOnePositionA = layerOnePosition;
        bundle.layerTwoPosition = layerTwoPosition;
        bundle.setupGas = setupGas;
    }

    function _advancePreparedLayers(PathInput memory input) internal returns (uint256 gasUsed) {
        uint64[] memory prepared = new uint64[](1);
        uint256 gasBefore;

        VM.prank(coordinator);
        gasBefore = gasleft();
        researchRegistry.markPositionReady(input.firstAsset, input.firstAssetLayerOneA);
        gasUsed += gasBefore - gasleft();

        prepared[0] = input.firstAssetLayerTwo;
        VM.prank(coordinator);
        gasBefore = gasleft();
        researchRegistry.advanceLayer(input.firstAsset, prepared);
        gasUsed += gasBefore - gasleft();

        VM.prank(coordinator);
        gasBefore = gasleft();
        researchRegistry.markPositionReady(input.secondAsset, input.secondAssetLayerOneA);
        gasUsed += gasBefore - gasleft();

        prepared[0] = input.secondAssetLayerTwo;
        VM.prank(coordinator);
        gasBefore = gasleft();
        researchRegistry.advanceLayer(input.secondAsset, prepared);
        gasUsed += gasBefore - gasleft();
    }

    function _confirmSchedule(uint64 teachingNftId, bool teacherSide)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(teacherSide ? teacher : coordinator);
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
        if (teacherSide) {
            registry.lockTeachingTeacherBond(teachingNftId);
        } else {
            registry.payTeachingSeat(teachingNftId, 0);
        }
        gasUsed = gasBefore - gasleft();
    }

    function _confirmCompletion(uint64 teachingNftId, bool teacherSide)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(teacherSide ? teacher : customer);
        uint256 gasBefore = gasleft();
        if (teacherSide) {
            registry.confirmTeachingDelivery(teachingNftId);
        } else {
            registry.confirmTeachingAttendance(teachingNftId, 0);
        }
        gasUsed = gasBefore - gasleft();
    }

    function _payTeachingSeat(uint64 teachingNftId, uint16 seatIndex, address student)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(student);
        uint256 gasBefore = gasleft();
        registry.payTeachingSeat(teachingNftId, seatIndex);
        gasUsed = gasBefore - gasleft();
    }

    function _confirmTeachingAttendance(uint64 teachingNftId, uint16 seatIndex, address student)
        internal
        returns (uint256 gasUsed)
    {
        VM.prank(student);
        uint256 gasBefore = gasleft();
        registry.confirmTeachingAttendance(teachingNftId, seatIndex);
        gasUsed = gasBefore - gasleft();
    }

    function _redeem(uint64 teachingNftId) internal returns (uint256 gasUsed) {
        VM.warp(block.timestamp + 31 days);
        VM.prank(teacher);
        uint256 gasBefore = gasleft();
        registry.redeemTeachingTeacherPayout(teachingNftId);
        gasUsed = gasBefore - gasleft();
    }

    function _claimRewards(PathInput memory input, uint64 teachingNftId)
        internal
        returns (uint256 gasUsed)
    {
        if (input.customerFault || input.researchShareBps == 0 || input.linkedAssetIds.length == 0)
        {
            return 0;
        }

        if (
            input.firstAssetLayerOneAHolder != address(0)
                && input.secondAssetLayerOneAHolder != address(0) && input.firstAssetLayerOneB == 0
                && input.secondAssetLayerOneB == 0
                && input.firstAssetLayerOneAHolder == input.secondAssetLayerOneAHolder
        ) {
            _warpToRewardUnlock(teachingNftId, input.firstAsset, input.firstAssetLayerOneA);
            uint64[] memory teachingNftIds = new uint64[](2);
            teachingNftIds[0] = teachingNftId;
            teachingNftIds[1] = teachingNftId;
            uint64[] memory assetIds = new uint64[](2);
            assetIds[0] = input.firstAsset;
            assetIds[1] = input.secondAsset;
            uint64[] memory positionIds = new uint64[](2);
            positionIds[0] = input.firstAssetLayerOneA;
            positionIds[1] = input.secondAssetLayerOneA;

            VM.prank(input.firstAssetLayerOneAHolder);
            uint256 gasBefore = gasleft();
            rewardDistributor.claimTeachingRewardBatch(teachingNftIds, assetIds, positionIds);
            return gasBefore - gasleft();
        }

        _warpToRewardUnlock(teachingNftId, input.firstAsset, input.firstAssetLayerOneA);
        gasUsed += _claimOne(
            input.firstAsset,
            input.firstAssetLayerOneA,
            input.firstAssetLayerOneAHolder,
            teachingNftId
        );
        if (input.firstAssetLayerOneB != 0) {
            gasUsed += _claimOne(
                input.firstAsset,
                input.firstAssetLayerOneB,
                input.firstAssetLayerOneBHolder,
                teachingNftId
            );
        }
        if (input.secondAsset != 0) {
            gasUsed += _claimOne(
                input.secondAsset,
                input.secondAssetLayerOneA,
                input.secondAssetLayerOneAHolder,
                teachingNftId
            );
            if (input.secondAssetLayerOneB != 0) {
                gasUsed += _claimOne(
                    input.secondAsset,
                    input.secondAssetLayerOneB,
                    input.secondAssetLayerOneBHolder,
                    teachingNftId
                );
            }
        }
    }

    function _claimOne(uint64 assetId, uint64 positionId, address holder, uint64 teachingNftId)
        internal
        returns (uint256 gasUsed)
    {
        if (holder == address(0)) return 0;
        VM.prank(holder);
        uint256 gasBefore = gasleft();
        rewardDistributor.claimTeachingReward(teachingNftId, assetId, positionId);
        gasUsed = gasBefore - gasleft();
    }

    function _warpToRewardUnlock(uint64 teachingNftId, uint64 assetId, uint64 positionId) internal {
        (, uint64 unlockAt,) =
            rewardDistributor.getTeachingRewardClaimable(teachingNftId, assetId, positionId);
        VM.warp(unlockAt);
    }

    function _prepareTeachingSession(uint64 teachingNftId) internal {
        VM.prank(teacher);
        registry.confirmTeachingSchedule(teachingNftId, true);
        VM.prank(coordinator);
        registry.confirmTeachingSchedule(teachingNftId, false);

        VM.startPrank(teacher);
        stable.approve(address(registry), 800_000);
        registry.lockTeachingTeacherBond(teachingNftId);
        VM.stopPrank();

        VM.startPrank(customer);
        stable.approve(address(registry), 800_000);
        registry.payTeachingSeat(teachingNftId, 0);
        VM.stopPrank();
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
            // forge-lint: disable-next-line(unsafe-typecast)
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _b(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }

    function _classSizeStudent(uint16 classSize, uint16 seatIndex) internal pure returns (address) {
        return address(uint160(0x9000 + uint256(classSize) * 1_000 + uint256(seatIndex)));
    }
}

contract TeachingGasCalibrationTest is TeachingGasCalibrationHarness {
    string internal constant OUT = "teaching_gas_calibration.csv";
    string internal constant CLASS_SIZE_OUT = "teaching_class_size_gas_calibration.csv";
    string internal constant FAULT_SIZE_OUT = "teaching_fault_size_gas_calibration.csv";
    string internal constant FOLLOWUP_OUT = "teaching_followup_gas_calibration.csv";

    struct PathGas {
        string path;
        string category;
        uint256 courseTypeGas;
        uint256 researchSetupGas;
        uint256 researchMutationGas;
        uint256 lessonGas;
        uint256 claimGas;
        bool validLesson;
        uint16 revenueWeightBps;
    }

    struct ClassSizeGas {
        uint16 classSize;
        uint16 paidSeats;
        uint16 attendanceConfirmations;
        uint256 courseTypeGas;
        uint256 sessionGas;
    }

    struct FaultSizeGas {
        string path;
        string scenario;
        uint16 classSize;
        uint16 paidSeats;
        uint16 customerFaultSeats;
        uint256 closeGas;
    }

    function testWriteTeachingGasCalibrationCsv() public {
        _clearOutput(OUT);
        VM.writeFile(
            OUT,
            "path,category,course_type_gas,research_setup_gas,research_mutation_gas,lesson_gas,claim_gas,valid_lesson,revenue_weight_bps\n"
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

    function testWriteTeachingSizeGasCalibrationCsv() public {
        _clearOutput(CLASS_SIZE_OUT);
        VM.writeFile(
            CLASS_SIZE_OUT,
            "class_size,paid_seats,attendance_confirmations,course_type_gas,session_gas\n"
        );

        _recordClassSize(1);
        _recordClassSize(2);
        _recordClassSize(5);
        _recordClassSize(20);
        _recordClassSize(50);
        _recordClassSize(100);
    }

    function testWriteTeachingFaultSizeGasCalibrationCsv() public {
        _clearOutput(FAULT_SIZE_OUT);
        VM.writeFile(
            FAULT_SIZE_OUT, "path,scenario,class_size,paid_seats,customer_fault_seats,close_gas\n"
        );

        _recordFaultSize(1, false);
        _recordFaultSize(1, true);
        _recordFaultSize(2, false);
        _recordFaultSize(2, true);
        _recordFaultSize(5, false);
        _recordFaultSize(5, true);
        _recordFaultSize(20, false);
        _recordFaultSize(20, true);
        _recordFaultSize(50, false);
        _recordFaultSize(50, true);
        _recordFaultSize(100, false);
        _recordFaultSize(100, true);
    }

    function testWriteTeachingFollowupGasCalibrationCsv() public {
        _clearOutput(FOLLOWUP_OUT);
        VM.writeFile(FOLLOWUP_OUT, "path,category,gas,measurement_context\n");
        _recordFollowupPrimitive(
            "TF_REMEDIAL_WAGE_CLOSE",
            "remedial_wage",
            _teacherFaultRemedialWageClose(),
            "same-test-warm-call"
        );
    }

    function _recordFaultSize(uint16 classSize, bool teacherFault) internal {
        FaultSizeGas memory gasRow = _runFaultSize(classSize, teacherFault);
        VM.writeLine(
            FAULT_SIZE_OUT,
            string.concat(
                gasRow.path,
                ",",
                gasRow.scenario,
                ",",
                _u(gasRow.classSize),
                ",",
                _u(gasRow.paidSeats),
                ",",
                _u(gasRow.customerFaultSeats),
                ",",
                _u(gasRow.closeGas)
            )
        );
    }

    function _runFaultSize(uint16 classSize, bool teacherFault)
        internal
        returns (FaultSizeGas memory gasRow)
    {
        VM.prank(coordinator);
        uint64 courseTypeId = registry.createTeachingCourseType(
            string.concat(teacherFault ? "TFS_" : "CFS_", _u(classSize)), 1_000_000, 400_000, 0
        );

        address[] memory students = new address[](classSize);
        for (uint16 i = 0; i < classSize;) {
            students[i] = _faultSizeStudent(classSize, i, teacherFault);
            stable.mint(students[i], 1_000_000_000);
            unchecked {
                ++i;
            }
        }

        uint64 scheduledAt = uint64(
            block.timestamp + (teacherFault ? uint256(200 days) : uint256(300 days))
                + uint256(classSize) * 1 days
        );
        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: scheduledAt,
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        _confirmSchedule(teachingNftId, true);
        _confirmSchedule(teachingNftId, false);
        _approveStable(teacher, 5_000_000);
        _lockCollateral(teachingNftId, true);

        for (uint16 i = 0; i < classSize;) {
            _approveStable(students[i], 1_000_000);
            _payTeachingSeat(teachingNftId, i, students[i]);
            unchecked {
                ++i;
            }
        }

        if (!teacherFault) {
            VM.prank(coordinator);
            registry.markTeachingCustomerFault(teachingNftId, 0, 2);
            gasRow.customerFaultSeats = 1;
        }

        VM.warp(uint256(scheduledAt) + 31 days);
        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        if (teacherFault) {
            registry.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);
            gasRow.path = string.concat("TF_CS", _u(classSize));
            gasRow.scenario = "teacher_fault";
        } else {
            registry.coordinatorCloseTeachingValid(teachingNftId, 1);
            gasRow.path = string.concat("CF_VALID_CS", _u(classSize));
            gasRow.scenario = "customer_fault_valid_close";
        }
        gasRow.closeGas = gasBefore - gasleft();

        gasRow.classSize = classSize;
        gasRow.paidSeats = classSize;
    }

    function _recordPath(PathInput memory input) internal {
        PathGas memory gasRow = _runPath(input);
        _record(gasRow);
    }

    function _recordClassSize(uint16 classSize) internal {
        ClassSizeGas memory gasRow = _runClassSize(classSize);
        VM.writeLine(
            CLASS_SIZE_OUT,
            string.concat(
                _u(gasRow.classSize),
                ",",
                _u(gasRow.paidSeats),
                ",",
                _u(gasRow.attendanceConfirmations),
                ",",
                _u(gasRow.courseTypeGas),
                ",",
                _u(gasRow.sessionGas)
            )
        );
    }

    function _runClassSize(uint16 classSize) internal returns (ClassSizeGas memory gasRow) {
        uint256 gasBefore;

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 courseTypeId = registry.createTeachingCourseType(
            string.concat("CS_", _u(classSize)), 1_000_000, 400_000, 0
        );
        gasRow.courseTypeGas = gasBefore - gasleft();

        address[] memory students = new address[](classSize);
        for (uint16 i = 0; i < classSize;) {
            students[i] = _classSizeStudent(classSize, i);
            stable.mint(students[i], 1_000_000_000);
            unchecked {
                ++i;
            }
        }

        uint64 scheduledAt = uint64((uint256(classSize) + 1) * 100 days);
        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 teachingNftId = registry.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: scheduledAt,
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );
        gasRow.sessionGas += gasBefore - gasleft();

        gasRow.sessionGas += _confirmSchedule(teachingNftId, true);
        gasRow.sessionGas += _confirmSchedule(teachingNftId, false);
        gasRow.sessionGas += _approveStable(teacher, 5_000_000);
        gasRow.sessionGas += _lockCollateral(teachingNftId, true);

        for (uint16 i = 0; i < classSize;) {
            gasRow.sessionGas += _approveStable(students[i], 1_000_000);
            gasRow.sessionGas += _payTeachingSeat(teachingNftId, i, students[i]);
            unchecked {
                ++i;
            }
        }

        VM.warp(uint256(scheduledAt) + 8 days);
        gasRow.sessionGas += _confirmCompletion(teachingNftId, true);

        uint16 attendanceConfirmations = classSize / 2 + 1;
        for (uint16 i = 0; i < attendanceConfirmations;) {
            gasRow.sessionGas += _confirmTeachingAttendance(teachingNftId, i, students[i]);
            unchecked {
                ++i;
            }
        }

        gasRow.sessionGas += _redeem(teachingNftId);

        (uint8 status,,,,,,,,,,,) = registry.getTeachingSessionState(teachingNftId);
        assert(status == 1);

        gasRow.classSize = classSize;
        gasRow.paidSeats = classSize;
        gasRow.attendanceConfirmations = attendanceConfirmations;
    }

    function _faultSizeStudent(uint16 classSize, uint16 seatIndex, bool teacherFault)
        internal
        pure
        returns (address)
    {
        uint256 scenarioOffset = teacherFault ? 0xB000 : 0xC000;
        // forge-lint: disable-next-line(unsafe-typecast)
        return address(uint160(scenarioOffset + uint256(classSize) * 1_000 + uint256(seatIndex)));
    }

    function _runPath(PathInput memory input) internal returns (PathGas memory gasRow) {
        uint64 courseTypeId;
        uint256 gasUsed;

        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        courseTypeId = registry.createTeachingCourseType(
            input.path, 1_000_000, 400_000, input.researchShareBps
        );
        gasUsed = gasBefore - gasleft();
        gasRow.courseTypeGas = gasUsed;

        uint64 scheduledAt = uint64(block.timestamp + 7 days);
        address[] memory students = new address[](1);
        students[0] = customer;
        SparkTeachingTypes.CreateTeachingSessionParams memory params =
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: scheduledAt,
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: input.linkedAssetIds,
                linkedResearchWeightBps: input.weights
            });

        VM.prank(coordinator);
        gasBefore = gasleft();
        uint64 teachingNftId = registry.createTeachingSession(params);
        gasUsed = gasBefore - gasleft();
        gasRow.lessonGas += gasUsed;

        gasRow.lessonGas += _confirmSchedule(teachingNftId, true);
        gasRow.lessonGas += _confirmSchedule(teachingNftId, false);
        gasRow.lessonGas += _approveStable(teacher, 800_000);
        gasRow.lessonGas += _lockCollateral(teachingNftId, true);
        gasRow.lessonGas += _approveStable(customer, 800_000);
        gasRow.lessonGas += _lockCollateral(teachingNftId, false);

        if (input.mutateLayersBeforeResolution) {
            VM.warp(block.timestamp + 8 days);
            gasRow.researchMutationGas += _advancePreparedLayers(input);
        }

        if (input.forceValid) {
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorCloseTeachingValid(teachingNftId, 3);
            gasUsed = gasBefore - gasleft();
            gasRow.lessonGas += gasUsed;
            gasRow.lessonGas += _redeem(teachingNftId);
            gasRow.validLesson = true;
            gasRow.revenueWeightBps = 10_000;
        } else if (input.customerFault) {
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.markTeachingCustomerFault(teachingNftId, 0, 2);
            gasUsed = gasBefore - gasleft();
            gasRow.lessonGas += gasUsed;
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorCloseTeachingValid(teachingNftId, 1);
            gasUsed = gasBefore - gasleft();
            gasRow.lessonGas += gasUsed;
            gasRow.validLesson = false;
            gasRow.revenueWeightBps = 5_000;
        } else if (input.teacherFault) {
            VM.warp(uint256(scheduledAt) + 31 days);
            VM.prank(coordinator);
            gasBefore = gasleft();
            registry.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);
            gasUsed = gasBefore - gasleft();
            gasRow.lessonGas += gasUsed;
            gasRow.validLesson = false;
            gasRow.revenueWeightBps = 5_000;
        } else {
            VM.warp(uint256(scheduledAt) + 8 days);
            gasRow.lessonGas += _confirmCompletion(teachingNftId, true);
            gasRow.lessonGas += _confirmCompletion(teachingNftId, false);
            gasRow.lessonGas += _redeem(teachingNftId);
            gasRow.validLesson = true;
            gasRow.revenueWeightBps = 10_000;
        }

        gasRow.claimGas = _claimRewards(input, teachingNftId);

        (uint8 status,,,,,,,,,,,) = registry.getTeachingSessionState(teachingNftId);
        if (input.teacherFault) {
            assert(status == 2);
        } else if (input.customerFault) {
            assert(status == 1);
        } else {
            assert(status == 1);
        }

        gasRow.path = input.path;
        gasRow.category = input.category;
        gasRow.researchSetupGas = input.setupGas;
    }

    function _teacherFaultRemedialWageClose() internal returns (uint256 gasUsed) {
        VM.prank(coordinator);
        uint64 courseTypeId =
            registry.createTeachingCourseType("TF Remedial Wage", 1_000_000, 400_000, 0);

        uint64 scheduledAt = uint64(block.timestamp + 7 days);
        address[] memory students = new address[](1);
        students[0] = customer;
        VM.prank(coordinator);
        uint64 teachingNftId = registry.createTeachingSession(
            SparkTeachingTypes.CreateTeachingSessionParams({
                courseTypeId: courseTypeId,
                teacher: teacher,
                students: students,
                scheduledAt: scheduledAt,
                customerDiscountBps: 8_000,
                linkedResearchAssetIds: new uint64[](0),
                linkedResearchWeightBps: new uint16[](0)
            })
        );

        _prepareTeachingSession(teachingNftId);
        VM.warp(uint256(scheduledAt) + 31 days);
        VM.prank(coordinator);
        registry.coordinatorCloseTeachingTeacherFault(teachingNftId, 4);

        VM.prank(coordinator);
        uint256 gasBefore = gasleft();
        registry.coordinatorSettleTeachingRemedialWage(teachingNftId);
        gasUsed = gasBefore - gasleft();
    }

    function _record(PathGas memory gasRow) internal {
        VM.writeLine(
            OUT,
            string.concat(
                gasRow.path,
                ",",
                gasRow.category,
                ",",
                _u(gasRow.courseTypeGas),
                ",",
                _u(gasRow.researchSetupGas),
                ",",
                _u(gasRow.researchMutationGas),
                ",",
                _u(gasRow.lessonGas),
                ",",
                _u(gasRow.claimGas),
                ",",
                _b(gasRow.validLesson),
                ",",
                _u(gasRow.revenueWeightBps)
            )
        );
    }

    function _recordFollowupPrimitive(
        string memory path,
        string memory category,
        uint256 gasUsed,
        string memory measurementContext
    ) internal {
        VM.writeLine(
            FOLLOWUP_OUT,
            string.concat(path, ",", category, ",", _u(gasUsed), ",", measurementContext)
        );
    }
}
