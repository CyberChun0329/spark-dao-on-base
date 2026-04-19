// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SparkDaoConfig} from "./SparkDaoConfig.sol";
import {SparkDaoErrors} from "./SparkDaoErrors.sol";
import {SparkDaoTypes} from "./SparkDaoTypes.sol";
import {SparkMath} from "./SparkMath.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IResearchPositionToken} from "./interfaces/IResearchPositionToken.sol";

contract ResearchRegistry is SparkDaoConfig {
    using SparkMath for uint16;

    address public immutable RESEARCH_POSITION_TOKEN;
    mapping(uint64 assetId => SparkDaoTypes.ResearchAsset) internal researchAssets;
    mapping(uint64 assetId => mapping(uint64 positionId => SparkDaoTypes.ResearchPosition))
        internal researchPositions;
    mapping(uint64 assetId => uint64[] positionIds) internal researchAssetPositionIds;
    mapping(uint64 assetId => mapping(uint64 positionId => mapping(uint64 revenueId => SparkDaoTypes.RevenueEscrow)))
        internal revenueEscrows;

    event ResearchAssetCreated(
        uint64 indexed assetId,
        address indexed createdBy,
        string title,
        string metadataUri
    );
    event ResearchPositionCreated(
        uint64 indexed assetId,
        uint64 indexed positionId,
        address indexed beneficiary,
        uint16 layerIndex,
        uint16 layerShareBps,
        bool activatedImmediately
    );
    event LayerSealed(uint64 indexed assetId, uint16 indexed layerIndex);
    event PositionReady(uint64 indexed assetId, uint64 indexed positionId, uint16 releasedShareBps);
    event LayerAdvanced(uint64 indexed assetId, uint16 indexed fromLayer, uint16 indexed toLayer);
    event ResearchPositionTransferred(
        uint64 indexed assetId,
        uint64 indexed positionId,
        address indexed previousHolder,
        address newHolder
    );
    event RevenueEscrowCreated(
        uint64 indexed assetId,
        uint64 indexed positionId,
        uint64 indexed revenueId,
        uint256 amount,
        uint64 unlockAt
    );
    event RevenueClaimed(
        uint64 indexed assetId,
        uint64 indexed positionId,
        uint64 indexed revenueId,
        address holder,
        uint256 amount
    );
    event PositionBoughtBack(
        uint64 indexed assetId,
        uint64 indexed positionId,
        address indexed previousHolder,
        uint256 price
    );

    constructor(
        address authority_,
        address coordinator_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_,
        address researchPositionToken_
    )
        SparkDaoConfig(
            authority_,
            coordinator_,
            stableAsset_,
            rewardUnlockSeconds_,
            buybackWaitSeconds_
        )
    {
        if (researchPositionToken_ == address(0)) revert SparkDaoErrors.ZeroAddress();
        RESEARCH_POSITION_TOKEN = researchPositionToken_;
    }

    function getResearchAsset(uint64 assetId)
        external
        view
        returns (SparkDaoTypes.ResearchAsset memory)
    {
        SparkDaoTypes.ResearchAsset memory asset = researchAssets[assetId];
        if (!asset.exists) revert SparkDaoErrors.AssetNotFound();
        return asset;
    }

    function getResearchPosition(uint64 assetId, uint64 positionId)
        external
        view
        returns (SparkDaoTypes.ResearchPosition memory)
    {
        SparkDaoTypes.ResearchPosition memory position = researchPositions[assetId][positionId];
        if (!position.exists) revert SparkDaoErrors.PositionNotFound();
        return position;
    }

    function createResearchAsset(string calldata title, string calldata metadataUri)
        external
        onlyCoordinator
        returns (uint64 assetId)
    {
        if (bytes(title).length > SparkDaoTypes.MAX_TITLE_LEN) {
            revert SparkDaoErrors.StringTooLong();
        }
        if (bytes(metadataUri).length > SparkDaoTypes.MAX_URI_LEN) {
            revert SparkDaoErrors.StringTooLong();
        }

        assetId = daoState.nextAssetId;
        daoState.nextAssetId += 1;

        SparkDaoTypes.ResearchAsset storage asset = researchAssets[assetId];
        asset.exists = true;
        asset.assetId = assetId;
        asset.title = title;
        asset.metadataUri = metadataUri;
        asset.createdBy = msg.sender;
        asset.currentActiveLayer = 1;
        asset.currentLayerCapacityBps = SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        asset.createdAt = uint64(block.timestamp);

        emit ResearchAssetCreated(assetId, msg.sender, title, metadataUri);
    }

    function createPatchPosition(SparkDaoTypes.CreatePatchPositionParams calldata params)
        external
        onlyCoordinator
        returns (uint64 positionId)
    {
        if (params.beneficiary == address(0)) revert SparkDaoErrors.ZeroAddress();
        if (
            params.layerShareBps == 0
                || params.layerShareBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        ) {
            revert SparkDaoErrors.InvalidShareBps();
        }
        if (params.decayPeriodSeconds == 0) revert SparkDaoErrors.InvalidDecayPeriod();
        if (
            params.decayRateBps == 0
                || params.decayRateBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        ) {
            revert SparkDaoErrors.InvalidDecayRate();
        }

        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(params.assetId);
        uint16 nextLayerIndex = asset.currentActiveLayer + 1;
        if (params.layerIndex != asset.currentActiveLayer && params.layerIndex != nextLayerIndex) {
            revert SparkDaoErrors.InvalidLayerIndex();
        }
        uint64 nowTs = uint64(block.timestamp);

        positionId = asset.nextPositionId;
        asset.nextPositionId += 1;

        (, uint16 firstStepReleaseBps) =
            SparkMath.computeDecaySplit(params.layerShareBps, params.decayRateBps, 1);

        SparkDaoTypes.ResearchPosition storage position =
            researchPositions[params.assetId][positionId];
        position.exists = true;
        position.positionId = positionId;
        position.beneficiary = params.beneficiary;
        position.currentHolder = params.beneficiary;
        position.layerIndex = params.layerIndex;
        position.layerShareBps = params.layerShareBps;
        position.buybackFloor = params.buybackFloor;
        position.buybackWaitSeconds = daoState.buybackWaitSeconds;
        position.decayWaitSeconds = params.decayWaitSeconds;
        position.decayPeriodSeconds = params.decayPeriodSeconds;
        position.decayRateBps = params.decayRateBps;
        position.retainedShareBps = params.layerShareBps;
        position.createdAt = nowTs;
        researchAssetPositionIds[params.assetId].push(positionId);

        bool activatedImmediately = params.layerIndex == asset.currentActiveLayer;
        if (activatedImmediately) {
            _activateCurrentLayerPosition(
                asset, position, params.layerShareBps, firstStepReleaseBps, nowTs
            );
        } else {
            _prepareNextLayerPosition(asset, params.layerShareBps, firstStepReleaseBps);
        }

        emit ResearchPositionCreated(
            params.assetId,
            positionId,
            params.beneficiary,
            params.layerIndex,
            params.layerShareBps,
            activatedImmediately
        );
        IResearchPositionToken(RESEARCH_POSITION_TOKEN).mint(
            params.beneficiary, _researchPositionTokenId(params.assetId, positionId)
        );
    }

    function _activateCurrentLayerPosition(
        SparkDaoTypes.ResearchAsset storage asset,
        SparkDaoTypes.ResearchPosition storage position,
        uint16 layerShareBps,
        uint16 firstStepReleaseBps,
        uint64 nowTs
    ) internal {
        if (asset.currentLayerSealed) revert SparkDaoErrors.LayerAlreadySealed();

        uint16 updatedShareTotal = asset.currentLayerShareBpsTotal + layerShareBps;
        if (updatedShareTotal > asset.currentLayerCapacityBps) {
            revert SparkDaoErrors.LayerShareOverflow();
        }

        position.isActivated = true;
        position.activatedAt = nowTs;
        position.buybackUnlockAt = nowTs + position.buybackWaitSeconds;
        position.decayStartAt = nowTs + position.decayWaitSeconds;

        asset.currentLayerPositionCount += 1;
        asset.currentLayerShareBpsTotal = updatedShareTotal;
        asset.currentLayerPreparableCapacityBps += firstStepReleaseBps;
    }

    function _prepareNextLayerPosition(
        SparkDaoTypes.ResearchAsset storage asset,
        uint16 layerShareBps,
        uint16 firstStepReleaseBps
    ) internal {
        if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();
        if (asset.preparedNextLayerSealed) revert SparkDaoErrors.LayerAlreadySealed();

        uint16 updatedPreparedTotal = asset.preparedNextLayerShareBpsTotal + layerShareBps;
        if (updatedPreparedTotal > asset.currentLayerPreparableCapacityBps) {
            revert SparkDaoErrors.LayerShareOverflow();
        }

        asset.preparedNextLayerPositionCount += 1;
        asset.preparedNextLayerShareBpsTotal = updatedPreparedTotal;
        asset.preparedNextLayerPreparableCapacityBps += firstStepReleaseBps;
    }

    function sealLayer(uint64 assetId, uint16 layerIndex) external onlyCoordinator {
        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(assetId);

        if (layerIndex == asset.currentActiveLayer) {
            if (asset.currentLayerPositionCount == 0) revert SparkDaoErrors.CannotSealEmptyLayer();
            if (asset.currentLayerSealed) revert SparkDaoErrors.LayerAlreadySealed();
            asset.currentLayerSealed = true;
        } else if (layerIndex == asset.currentActiveLayer + 1) {
            if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();
            if (asset.preparedNextLayerPositionCount == 0) {
                revert SparkDaoErrors.CannotSealEmptyLayer();
            }
            if (asset.preparedNextLayerSealed) revert SparkDaoErrors.LayerAlreadySealed();
            asset.preparedNextLayerSealed = true;
        } else {
            revert SparkDaoErrors.InvalidLayerPreparationTarget();
        }

        emit LayerSealed(assetId, layerIndex);
    }

    function approveEarlyDecay(uint64 assetId, uint64 positionId) external {
        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(assetId);
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);

        if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();
        if (position.layerIndex != asset.currentActiveLayer) revert SparkDaoErrors.LayerNotActivated();
        if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();
        if (!position.isActivated) revert SparkDaoErrors.LayerNotActivated();
        if (position.rolloverReady) revert SparkDaoErrors.PositionAlreadyReady();

        (uint16 retainedShareBps, uint16 releasedShareBps) =
            SparkMath.computeDecaySplit(position.layerShareBps, position.decayRateBps, 1);

        position.rolloverReady = true;
        position.retainedShareBps = retainedShareBps;
        position.releasedShareBps = releasedShareBps;
        position.readyAt = uint64(block.timestamp);

        asset.currentLayerReadyCount += 1;
        asset.nextLayerCapacityBps += releasedShareBps;

        emit PositionReady(assetId, positionId, releasedShareBps);
    }

    function markPositionReady(uint64 assetId, uint64 positionId) external {
        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(assetId);
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);

        if (position.layerIndex != asset.currentActiveLayer) revert SparkDaoErrors.LayerNotActivated();
        if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();
        if (!position.isActivated) revert SparkDaoErrors.LayerNotActivated();
        if (position.rolloverReady) revert SparkDaoErrors.PositionAlreadyReady();
        if (block.timestamp < position.decayStartAt) revert SparkDaoErrors.DecayNotStarted();

        uint64 decaySteps = SparkMath.computeDecayStepCountFromNow(
            uint64(block.timestamp), position.decayStartAt, position.decayPeriodSeconds
        );
        (uint16 retainedShareBps, uint16 releasedShareBps) =
            SparkMath.computeDecaySplit(position.layerShareBps, position.decayRateBps, decaySteps);

        position.rolloverReady = true;
        position.retainedShareBps = retainedShareBps;
        position.releasedShareBps = releasedShareBps;
        position.readyAt = uint64(block.timestamp);

        asset.currentLayerReadyCount += 1;
        asset.nextLayerCapacityBps += releasedShareBps;

        emit PositionReady(assetId, positionId, releasedShareBps);
    }

    function advanceLayer(uint64 assetId, uint64[] calldata preparedPositionIds) external {
        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(assetId);

        if (asset.currentLayerPositionCount == 0) revert SparkDaoErrors.EmptyLayer();
        if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();
        if (asset.currentLayerReadyCount != asset.currentLayerPositionCount) {
            revert SparkDaoErrors.LayerNotReadyToAdvance();
        }
        if (asset.preparedNextLayerPositionCount == 0) revert SparkDaoErrors.NextLayerNotPrepared();
        if (!asset.preparedNextLayerSealed) revert SparkDaoErrors.LayerNotSealed();
        if (preparedPositionIds.length != asset.preparedNextLayerPositionCount) {
            revert SparkDaoErrors.InvalidPreparedLayerAccounts();
        }
        if (asset.preparedNextLayerShareBpsTotal > asset.nextLayerCapacityBps) {
            revert SparkDaoErrors.LayerShareOverflow();
        }

        uint16 nextLayerIndex = asset.currentActiveLayer + 1;
        uint64 nowTs = uint64(block.timestamp);
        uint256 preparedCount = preparedPositionIds.length;

        for (uint256 i = 0; i < preparedCount;) {
            SparkDaoTypes.ResearchPosition storage position =
                _requirePosition(assetId, preparedPositionIds[i]);

            if (position.layerIndex != nextLayerIndex || position.isActivated) {
                revert SparkDaoErrors.InvalidPreparedLayerAccounts();
            }

            position.isActivated = true;
            position.activatedAt = nowTs;
            position.buybackUnlockAt = nowTs + position.buybackWaitSeconds;
            position.decayStartAt = nowTs + position.decayWaitSeconds;
            unchecked {
                ++i;
            }
        }

        uint16 previousLayer = asset.currentActiveLayer;
        asset.currentActiveLayer = nextLayerIndex;
        asset.currentLayerCapacityBps = asset.nextLayerCapacityBps;
        asset.currentLayerPositionCount = asset.preparedNextLayerPositionCount;
        asset.currentLayerReadyCount = 0;
        asset.currentLayerShareBpsTotal = asset.preparedNextLayerShareBpsTotal;
        asset.currentLayerSealed = asset.preparedNextLayerSealed;
        asset.currentLayerPreparableCapacityBps = asset.preparedNextLayerPreparableCapacityBps;
        asset.nextLayerCapacityBps = 0;
        asset.preparedNextLayerPositionCount = 0;
        asset.preparedNextLayerShareBpsTotal = 0;
        asset.preparedNextLayerSealed = false;
        asset.preparedNextLayerPreparableCapacityBps = 0;

        emit LayerAdvanced(assetId, previousLayer, nextLayerIndex);
    }

    function transferResearchPosition(uint64 assetId, uint64 positionId, address newHolder) external {
        if (newHolder == address(0)) revert SparkDaoErrors.ZeroAddress();

        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);
        if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();

        address previousHolder = position.currentHolder;
        position.currentHolder = newHolder;
        IResearchPositionToken(RESEARCH_POSITION_TOKEN).protocolTransfer(
            previousHolder, newHolder, _researchPositionTokenId(assetId, positionId)
        );

        emit ResearchPositionTransferred(assetId, positionId, previousHolder, newHolder);
    }

    function createRevenueEscrow(uint64 assetId, uint64 positionId, uint256 amount)
        external
        onlyAuthority
        returns (uint64 revenueId)
    {
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();

        SparkDaoTypes.ResearchAsset storage asset = _requireAsset(assetId);
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);

        if (position.layerIndex != asset.currentActiveLayer) {
            revert SparkDaoErrors.LayerNotActivated();
        }
        if (!asset.currentLayerSealed) revert SparkDaoErrors.LayerNotSealed();

        revenueId = position.nextRevenueId;
        position.nextRevenueId += 1;

        if (!IERC20(daoState.stableAsset).transferFrom(msg.sender, address(this), amount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }

        uint64 unlockAt = uint64(block.timestamp) + daoState.rewardUnlockSeconds;
        SparkDaoTypes.RevenueEscrow storage escrow = revenueEscrows[assetId][positionId][revenueId];
        escrow.amount = amount;
        escrow.unlockAt = unlockAt;

        daoState.vaultReservedUnits += amount;

        emit RevenueEscrowCreated(assetId, positionId, revenueId, amount, unlockAt);
    }

    function claimRevenue(uint64 assetId, uint64 positionId, uint64 revenueId) external {
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);
        SparkDaoTypes.RevenueEscrow storage escrow =
            _requireRevenueEscrow(assetId, positionId, revenueId);

        if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();
        if (escrow.claimed) revert SparkDaoErrors.RevenueAlreadyClaimed();
        if (block.timestamp < escrow.unlockAt) revert SparkDaoErrors.RevenueStillLocked();

        escrow.claimed = true;
        position.totalClaimedUnits += escrow.amount;
        daoState.vaultReservedUnits -= escrow.amount;

        if (!IERC20(daoState.stableAsset).transfer(msg.sender, escrow.amount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }

        emit RevenueClaimed(assetId, positionId, revenueId, msg.sender, escrow.amount);
    }

    function fundDaoVault(uint256 amount) external onlyAuthority {
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();
        if (!IERC20(daoState.stableAsset).transferFrom(msg.sender, address(this), amount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }
    }

    function withdrawDaoVault(uint256 amount) external onlyAuthority {
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();
        uint256 idleVaultUnits =
            IERC20(daoState.stableAsset).balanceOf(address(this)) - daoState.vaultReservedUnits;
        if (amount > idleVaultUnits) revert SparkDaoErrors.VaultFundsReserved();
        if (!IERC20(daoState.stableAsset).transfer(msg.sender, amount)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }
    }

    function sellPositionBackToDao(uint64 assetId, uint64 positionId) external {
        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);

        if (position.currentHolder != msg.sender) revert SparkDaoErrors.UnauthorizedHolder();
        if (!position.isActivated) revert SparkDaoErrors.LayerNotActivated();
        if (position.boughtBack) revert SparkDaoErrors.PositionAlreadyBoughtBack();
        if (block.timestamp < position.buybackUnlockAt) revert SparkDaoErrors.BuybackNotYetAvailable();

        uint256 availableVaultUnits =
            IERC20(daoState.stableAsset).balanceOf(address(this)) - daoState.vaultReservedUnits;
        if (availableVaultUnits < position.buybackFloor) {
            revert SparkDaoErrors.VaultFundsReserved();
        }

        position.currentHolder = daoState.authority;
        position.boughtBack = true;
        position.boughtBackAt = uint64(block.timestamp);
        position.boughtBackPrice = position.buybackFloor;
        IResearchPositionToken(RESEARCH_POSITION_TOKEN).protocolTransfer(
            msg.sender, daoState.authority, _researchPositionTokenId(assetId, positionId)
        );

        if (!IERC20(daoState.stableAsset).transfer(msg.sender, position.buybackFloor)) {
            revert SparkDaoErrors.TokenTransferFailed();
        }

        emit PositionBoughtBack(assetId, positionId, msg.sender, position.buybackFloor);
    }

    function _requireAsset(uint64 assetId)
        internal
        view
        returns (SparkDaoTypes.ResearchAsset storage asset)
    {
        asset = researchAssets[assetId];
        if (!asset.exists) revert SparkDaoErrors.AssetNotFound();
    }

    function _requirePosition(uint64 assetId, uint64 positionId)
        internal
        view
        returns (SparkDaoTypes.ResearchPosition storage position)
    {
        position = researchPositions[assetId][positionId];
        if (!position.exists) revert SparkDaoErrors.PositionNotFound();
    }

    function _requireRevenueEscrow(uint64 assetId, uint64 positionId, uint64 revenueId)
        internal
        view
        returns (SparkDaoTypes.RevenueEscrow storage escrow)
    {
        escrow = revenueEscrows[assetId][positionId][revenueId];
        if (escrow.amount == 0) revert SparkDaoErrors.InvalidRevenueId();
    }

    function _researchPositionTokenId(uint64 assetId, uint64 positionId)
        internal
        pure
        returns (uint256)
    {
        return (uint256(assetId) << 64) | uint256(positionId);
    }
}
