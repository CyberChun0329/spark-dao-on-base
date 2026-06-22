// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ResearchRegistry } from "../src/ResearchRegistry.sol";
import { ResearchPositionToken } from "../src/ResearchPositionToken.sol";
import { SparkDaoErrors } from "../src/SparkDaoErrors.sol";
import { SparkDaoTypes } from "../src/SparkDaoTypes.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
}

contract ResearchRegistryTest {
    Vm internal constant VM = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    ResearchRegistry internal registry;
    ResearchPositionToken internal researchToken;
    MockERC20 internal stable;
    MockERC20 internal eurc;

    address internal authority = address(0xA11CE);
    address internal coordinator = address(0xC001);
    address internal treasury = address(0xDA01);
    address internal contributorOne = address(0x1001);
    address internal contributorTwo = address(0x1002);

    function setUp() public {
        stable = new MockERC20("USD Coin", "USDC", 6);
        eurc = new MockERC20("Euro Coin", "EURC", 6);
        researchToken = new ResearchPositionToken(
            authority, "Spark Research Position", "SRP", "ipfs://research-position/"
        );
        registry = new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(stable),
            90 days,
            30 days,
            address(researchToken)
        );
        VM.prank(authority);
        researchToken.setMinter(address(registry));

        stable.mint(authority, 1_000_000_000);
        stable.mint(address(registry), 1_000_000_000);
        eurc.mint(authority, 1_000_000_000);
        eurc.mint(address(registry), 1_000_000_000);
    }

    function testConstructorRejectsNonContractStableAssetOrToken() public {
        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        new ResearchRegistry(
            authority,
            coordinator,
            treasury,
            address(0xBEEF),
            90 days,
            30 days,
            address(researchToken)
        );

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        new ResearchRegistry(
            authority, coordinator, treasury, address(stable), 90 days, 30 days, address(0xBEEF)
        );
    }

    function testStableAssetUpdatesAndVaultFundingRequireTokenContracts() public {
        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        VM.prank(authority);
        registry.updateStableAsset(address(0xBEEF));

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        VM.prank(authority);
        registry.fundDaoVaultFor(address(0xBEEF), 1);

        VM.expectRevert(SparkDaoErrors.InvalidContractAddress.selector);
        VM.prank(authority);
        registry.withdrawDaoVaultFor(address(0xBEEF), 1);
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

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
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

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
        assertTrue(position.currentHolder == contributorTwo);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == contributorTwo);
    }

    function testSetTeachingRegistryRequiresAuthorityValidHandshakeAndOneTime() public {
        MockTeachingRegistryForResearch teaching =
            new MockTeachingRegistryForResearch(address(registry));

        VM.expectRevert(SparkDaoErrors.UnauthorizedAuthority.selector);
        VM.prank(coordinator);
        registry.setTeachingRegistry(address(teaching));

        VM.expectRevert(SparkDaoErrors.InvalidTeachingRegistry.selector);
        VM.prank(authority);
        registry.setTeachingRegistry(address(0));

        VM.expectRevert(SparkDaoErrors.InvalidTeachingRegistry.selector);
        VM.prank(authority);
        registry.setTeachingRegistry(address(0xBEEF));

        MockTeachingRegistryForResearch mismatched =
            new MockTeachingRegistryForResearch(address(0xCAFE));
        VM.expectRevert(SparkDaoErrors.InvalidTeachingRegistry.selector);
        VM.prank(authority);
        registry.setTeachingRegistry(address(mismatched));

        VM.prank(authority);
        registry.setTeachingRegistry(address(teaching));

        MockTeachingRegistryForResearch second =
            new MockTeachingRegistryForResearch(address(registry));
        VM.expectRevert(SparkDaoErrors.TeachingRegistryAlreadySet.selector);
        VM.prank(authority);
        registry.setTeachingRegistry(address(second));
    }

    function testTeachingClaimAccountingIsTeachingRegistryOnly() public {
        MockTeachingRegistryForResearch teaching =
            new MockTeachingRegistryForResearch(address(registry));
        VM.prank(authority);
        registry.setTeachingRegistry(address(teaching));

        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Teaching Claim", "ipfs://teaching-claim");
        uint64 positionId = registry.createPatchPosition(
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
        VM.stopPrank();

        VM.expectRevert(SparkDaoErrors.UnauthorizedTeachingRegistry.selector);
        registry.recordTeachingRewardClaim(assetId, positionId, 321);

        VM.prank(address(teaching));
        registry.recordTeachingRewardClaim(assetId, positionId, 321);

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
        assertTrue(position.totalClaimedUnits == 321);
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

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
        assertTrue(afterBalance == beforeBalance + 250_000);
        assertTrue(position.currentHolder == treasury);
        assertTrue(position.boughtBack);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == treasury);
    }

    function testRetainedOldLayerPositionCanReceiveDirectRevenueEscrowAfterAdvance() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Retained Revenue", "ipfs://retained");
        uint64 layerOnePosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 5_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 2);
        VM.stopPrank();

        VM.warp(block.timestamp + 2 days);
        registry.markPositionReady(assetId, layerOnePosition);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.startPrank(authority);
        stable.approve(address(registry), 500_000);
        uint64 revenueId = registry.createRevenueEscrow(assetId, layerOnePosition, 500_000);
        VM.stopPrank();

        VM.warp(block.timestamp + 91 days);
        uint256 beforeBalance = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimRevenue(assetId, layerOnePosition, revenueId);
        assertTrue(stable.balanceOf(contributorOne) == beforeBalance + 500_000);
    }

    function testFullyReleasedOldLayerPositionCannotReceiveDirectRevenueEscrow() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Released Revenue", "ipfs://released");
        uint64 layerOnePosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 10_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(assetId, 1);
        uint64 layerTwoPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 2,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(assetId, 2);
        VM.stopPrank();

        VM.warp(block.timestamp + 2 days);
        registry.markPositionReady(assetId, layerOnePosition);
        uint64[] memory preparedPositionIds = new uint64[](1);
        preparedPositionIds[0] = layerTwoPosition;
        registry.advanceLayer(assetId, preparedPositionIds);

        VM.startPrank(authority);
        stable.approve(address(registry), 500_000);
        VM.expectRevert();
        registry.createRevenueEscrow(assetId, layerOnePosition, 500_000);
        VM.stopPrank();
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
        uint256 contractBalance = stable.balanceOf(address(registry));
        uint256 idleBalance = contractBalance - registry.getVaultReservedUnits(address(stable));
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

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
        assertTrue(position.buybackWaitSeconds == 0);
        assertTrue(position.buybackUnlockAt == block.timestamp);

        uint256 beforeBalance = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(assetId, positionId);
        uint256 afterBalance = stable.balanceOf(contributorOne);

        assertTrue(afterBalance == beforeBalance + 150_000);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == treasury);
    }

    function testUpdateTreasuryAffectsFutureBuybacksOnly() public {
        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Treasury Rotation", "ipfs://treasury");
        uint64 firstPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 5_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        uint64 secondPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 5_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        VM.stopPrank();

        VM.warp(block.timestamp + 31 days);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(assetId, firstPosition);

        address newTreasury = address(0xDA02);
        VM.prank(authority);
        registry.updateTreasury(newTreasury);

        VM.prank(contributorTwo);
        registry.sellPositionBackToDao(assetId, secondPosition);

        assertTrue(researchToken.ownerOf(_tokenId(assetId, firstPosition)) == treasury);
        assertTrue(researchToken.ownerOf(_tokenId(assetId, secondPosition)) == newTreasury);
    }

    function testRevenueEscrowsFreezeStableAssetAtCreation() public {
        VM.startPrank(coordinator);
        uint64 usdcAsset = registry.createResearchAsset("USDC Escrow", "ipfs://usdc-escrow");
        uint64 usdcPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: usdcAsset,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        registry.sealLayer(usdcAsset, 1);
        VM.stopPrank();

        VM.startPrank(authority);
        stable.approve(address(registry), 500_000);
        uint64 usdcRevenue = registry.createRevenueEscrow(usdcAsset, usdcPosition, 500_000);
        registry.updateStableAsset(address(eurc));
        VM.stopPrank();

        VM.startPrank(coordinator);
        uint64 eurcAsset = registry.createResearchAsset("EURC Escrow", "ipfs://eurc-escrow");
        uint64 eurcPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: eurcAsset,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        registry.sealLayer(eurcAsset, 1);
        VM.stopPrank();

        VM.startPrank(authority);
        eurc.approve(address(registry), 700_000);
        uint64 eurcRevenue = registry.createRevenueEscrow(eurcAsset, eurcPosition, 700_000);
        VM.stopPrank();

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 500_000);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 700_000);

        VM.warp(block.timestamp + 91 days);
        uint256 contributorOneUsdcBefore = stable.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.claimRevenue(usdcAsset, usdcPosition, usdcRevenue);
        assertTrue(stable.balanceOf(contributorOne) == contributorOneUsdcBefore + 500_000);

        uint256 contributorTwoEurcBefore = eurc.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        registry.claimRevenue(eurcAsset, eurcPosition, eurcRevenue);
        assertTrue(eurc.balanceOf(contributorTwo) == contributorTwoEurcBefore + 700_000);

        assertTrue(registry.getVaultReservedUnits(address(stable)) == 0);
        assertTrue(registry.getVaultReservedUnits(address(eurc)) == 0);
    }

    function testBuybackUsesPositionStableAssetAfterDefaultSwitch() public {
        VM.startPrank(coordinator);
        uint64 usdcAsset = registry.createResearchAsset("USDC Buyback", "ipfs://usdc-buyback");
        uint64 usdcPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: usdcAsset,
                layerIndex: 1,
                layerShareBps: 5_000,
                buybackFloor: 250_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
        VM.stopPrank();

        VM.prank(authority);
        registry.updateStableAsset(address(eurc));

        VM.startPrank(coordinator);
        uint64 eurcAsset = registry.createResearchAsset("EURC Buyback", "ipfs://eurc-buyback");
        uint64 eurcPosition = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: eurcAsset,
                layerIndex: 1,
                layerShareBps: 5_000,
                buybackFloor: 350_000,
                decayWaitSeconds: 365 days,
                decayPeriodSeconds: 365 days,
                decayRateBps: 5_000,
                beneficiary: contributorTwo
            })
        );
        VM.stopPrank();

        VM.warp(block.timestamp + 31 days);
        uint256 contributorOneUsdcBefore = stable.balanceOf(contributorOne);
        uint256 contributorOneEurcBefore = eurc.balanceOf(contributorOne);
        VM.prank(contributorOne);
        registry.sellPositionBackToDao(usdcAsset, usdcPosition);
        assertTrue(stable.balanceOf(contributorOne) == contributorOneUsdcBefore + 250_000);
        assertTrue(eurc.balanceOf(contributorOne) == contributorOneEurcBefore);

        uint256 contributorTwoUsdcBefore = stable.balanceOf(contributorTwo);
        uint256 contributorTwoEurcBefore = eurc.balanceOf(contributorTwo);
        VM.prank(contributorTwo);
        registry.sellPositionBackToDao(eurcAsset, eurcPosition);
        assertTrue(stable.balanceOf(contributorTwo) == contributorTwoUsdcBefore);
        assertTrue(eurc.balanceOf(contributorTwo) == contributorTwoEurcBefore + 350_000);
    }

    function testLockedResearchTokenMinterBlocksRotationButRegistryStillMints() public {
        VM.prank(authority);
        researchToken.lockMinter();

        VM.expectRevert();
        VM.prank(authority);
        researchToken.setMinter(address(0xBEEF));

        VM.startPrank(coordinator);
        uint64 assetId = registry.createResearchAsset("Locked Research Minter", "ipfs://locked");
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
        VM.stopPrank();

        assertTrue(researchToken.ownerOf(_tokenId(assetId, positionId)) == contributorOne);

        address newAuthority = address(0xA22CE);
        VM.prank(authority);
        registry.updateAuthority(newAuthority);
        VM.prank(newAuthority);
        registry.updateCoordinator(address(0xC002));
    }

    function testTinyDecayPeriodIsRejected() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Tiny Decay", "ipfs://tiny-decay");

        VM.expectRevert();
        VM.prank(coordinator);
        registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 hours,
                decayRateBps: 5_000,
                beneficiary: contributorOne
            })
        );
    }

    function testLongInactivityDecayStepsAreCapped() public {
        VM.prank(coordinator);
        uint64 assetId = registry.createResearchAsset("Capped Decay", "ipfs://capped-decay");

        VM.prank(coordinator);
        uint64 positionId = registry.createPatchPosition(
            SparkDaoTypes.CreatePatchPositionParams({
                assetId: assetId,
                layerIndex: 1,
                layerShareBps: 10_000,
                buybackFloor: 100_000,
                decayWaitSeconds: 1 days,
                decayPeriodSeconds: 1 days,
                decayRateBps: 100,
                beneficiary: contributorOne
            })
        );
        VM.prank(coordinator);
        registry.sealLayer(assetId, 1);

        VM.warp(block.timestamp + 1_000 days);
        registry.markPositionReady(assetId, positionId);

        SparkDaoTypes.ResearchPosition memory position =
            registry.getResearchPosition(assetId, positionId);
        assertTrue(position.rolloverReady);
        assertTrue(position.retainedShareBps > 0);
    }

    function assertTrue(bool ok) internal pure {
        if (!ok) revert("assert failed");
    }

    function _tokenId(uint64 assetId, uint64 positionId) internal pure returns (uint256) {
        return (uint256(assetId) << 64) | uint256(positionId);
    }
}

contract MockTeachingRegistryForResearch {
    address public immutable RESEARCH_REGISTRY;

    constructor(address researchRegistry_) {
        RESEARCH_REGISTRY = researchRegistry_;
    }
}
