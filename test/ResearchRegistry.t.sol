// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ResearchRegistry} from "../src/ResearchRegistry.sol";
import {ResearchPositionToken} from "../src/ResearchPositionToken.sol";
import {SparkDaoTypes} from "../src/SparkDaoTypes.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert() external;
}

contract ResearchRegistryTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

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

        stable.mint(authority, 1_000_000_000);
        stable.mint(address(registry), 1_000_000_000);
    }

    function testCreateResearchAssetAndCurrentLayerPosition() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Calculus", "ipfs://paper");

        SparkDaoTypes.ResearchAsset memory asset = registry.getResearchAsset(assetId);
        assertTrue(asset.exists);
        assertTrue(asset.currentActiveLayer == 1);
        assertTrue(asset.currentLayerCapacityBps == 10_000);

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 6_000,
                buybackFloor: 100 ether,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        SparkDaoTypes.ResearchPosition memory position = registry.getResearchPosition(assetId, positionId);
        assertTrue(position.exists);
        assertTrue(position.isActivated);
        assertTrue(position.currentHolder == contributorOne);
        assertTrue(position.layerIndex == 1);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == contributorOne);
    }

    function testSealPrepareAndAdvanceLayer() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Physics", "ipfs://physics");
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
        registry.sealLayer(assetId, 1);
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
        registry.sealLayer(assetId, 2);
        VM.stopPrank();

        VM.warp(block.timestamp + 366 days);
        registry.markPositionReady(assetId, layerOnePositionId);

        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = preparedLayerTwoPositionId;
        registry.advanceLayer(assetId, preparedPositionIds);

        SparkDaoTypes.ResearchAsset memory asset = registry.getResearchAsset(assetId);
        SparkDaoTypes.ResearchPosition memory layerTwoPosition =
            registry.getResearchPosition(assetId, preparedLayerTwoPositionId);

        assertTrue(asset.currentActiveLayer == 2);
        assertTrue(layerTwoPosition.isActivated);
        assertTrue(layerTwoPosition.currentHolder == contributorTwo);
    }

    function testApproveEarlyDecayMarksReadyAndEnablesAdvance() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Early Decay", "ipfs://early-decay");
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
        registry.sealLayer(assetId, 1);
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
        registry.sealLayer(assetId, 2);
        VM.stopPrank();

        VM.prank(contributorOne);
        registry.approveEarlyDecay(assetId, layerOnePositionId);

        SparkDaoTypes.ResearchPosition memory readyPosition =
            registry.getResearchPosition(assetId, layerOnePositionId);
        assertTrue(readyPosition.rolloverReady);
        assertTrue(readyPosition.retainedShareBps == 5_000);
        assertTrue(readyPosition.releasedShareBps == 5_000);

        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = preparedLayerTwoPositionId;
        registry.advanceLayer(assetId, preparedPositionIds);

        SparkDaoTypes.ResearchAsset memory asset = registry.getResearchAsset(assetId);
        SparkDaoTypes.ResearchPosition memory layerTwoPosition =
            registry.getResearchPosition(assetId, preparedLayerTwoPositionId);
        assertTrue(asset.currentActiveLayer == 2);
        assertTrue(layerTwoPosition.isActivated);
    }

    function testTransferResearchPosition() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Biology", "ipfs://bio");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 4_000,
                buybackFloor: 100 ether,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        VM.prank(contributorOne);
        registry.transferResearchPosition(assetId, positionId, contributorTwo);

        SparkDaoTypes.ResearchPosition memory position = registry.getResearchPosition(assetId, positionId);
        assertTrue(position.currentHolder == contributorTwo);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == contributorTwo);
    }

    function testCreateAndClaimRevenueEscrow() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Chemistry", "ipfs://chem");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 7_000,
                buybackFloor: 100 ether,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        VM.prank(coordinator);
        registry.sealLayer(assetId, 1);

        VM.startPrank(authority);
        stable.approve(address(registry), 500_000);
        uint64 revenueId = registry.createRevenueEscrow(assetId, positionId, 500_000);
        VM.stopPrank();

        VM.warp(block.timestamp + 91 days);

        uint256 beforeBalance = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimRevenue(assetId, positionId, revenueId);
        uint256 afterBalance = stable.balanceOf(contributorOne);

        assertTrue(afterBalance == beforeBalance + 500_000);
    }

    function testSellPositionBackToDao() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("History", "ipfs://history");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 3_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        VM.warp(block.timestamp + 31 days);

        uint256 beforeBalance = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(assetId, positionId);
        uint256 afterBalance = stable.balanceOf(contributorOne);

        SparkDaoTypes.ResearchPosition memory position = registry.getResearchPosition(assetId, positionId);
        assertTrue(afterBalance == beforeBalance + 250_000);
        assertTrue(position.currentHolder == authority);
        assertTrue(position.boughtBack);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == authority);
    }

    function testAuthorityCanFundAndWithdrawIdleDaoVault() public {
        uint256 authorityBefore = stable.balanceOf(authority);

        VM.startPrank(authority);
        stable.approve(address(registry), 200_000);
        registry.fundDaoVault(200_000);
        registry.withdrawDaoVault(150_000);
        VM.stopPrank();

        uint256 authorityAfter = stable.balanceOf(authority);
        assertTrue(authorityAfter == authorityBefore - 50_000);
    }

    function testWithdrawDaoVaultRejectsReservedFunds() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Reserved Vault", "ipfs://reserved-vault");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        VM.prank(coordinator);
        registry.sealLayer(assetId, 1);

        VM.startPrank(authority);
        stable.approve(address(registry), 500_000);
        registry.createRevenueEscrow(assetId, positionId, 500_000);
        SparkDaoTypes.DaoState memory daoState = registry.getDaoState();
        uint256 contractBalance = stable.balanceOf(address(registry));
        uint256 idleBalance = contractBalance - daoState.vaultReservedUnits;
        VM.expectRevert();
        registry.withdrawDaoVault(idleBalance + 1);
        VM.stopPrank();
    }

    function testUpdatedBuybackWaitSecondsAppliesToNewPositions() public {
        VM.prank(authority);
        registry.updateBuybackWaitSeconds(0);

        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Instant Buyback", "ipfs://instant-buyback");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 150_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );

        SparkDaoTypes.ResearchPosition memory position = registry.getResearchPosition(assetId, positionId);
        assertTrue(position.buybackWaitSeconds == 0);
        assertTrue(position.buybackUnlockAt == block.timestamp);

        uint256 beforeBalance = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(assetId, positionId);
        uint256 afterBalance = stable.balanceOf(contributorOne);

        assertTrue(afterBalance == beforeBalance + 150_000);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == authority);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }

    function _tokenId(uint64 assetId, uint64 positionId) internal pure returns (uint256) {
        return (uint256(assetId) << 64) | uint256(positionId);
    }
}
