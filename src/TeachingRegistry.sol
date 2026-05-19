// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { ResearchRegistry } from "./ResearchRegistry.sol";
import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingRewardDistributor } from "./interfaces/ITeachingRewardDistributor.sol";
import { ITeachingNftToken } from "./interfaces/ITeachingNftToken.sol";

contract TeachingRegistry is ResearchRegistry {
    uint8 internal constant TEACHING_STATUS_SCHEDULED = 0;
    uint8 internal constant TEACHING_STATUS_CONFIRMED = 1;
    uint8 internal constant TEACHING_STATUS_COMPLETED = 2;
    uint8 internal constant TEACHING_STATUS_FORCED_VALID = 3;
    uint8 internal constant TEACHING_STATUS_TEACHER_FAULT_REMEDIATION = 4;
    uint8 internal constant TEACHING_STATUS_CUSTOMER_FAULT_SETTLED = 5;
    uint8 internal constant TEACHING_STATUS_REDEEMED = 7;

    uint8 internal constant TEACHING_RESOLUTION_NONE = 0;
    uint8 internal constant TEACHING_RESOLUTION_SUCCESSFUL_COMPLETION = 1;
    uint8 internal constant TEACHING_RESOLUTION_CUSTOMER_FAULT = 2;
    uint8 internal constant TEACHING_RESOLUTION_COORDINATOR_FORCED_VALID = 3;
    uint8 internal constant TEACHING_RESOLUTION_TEACHER_FAULT = 4;
    uint8 internal constant TEACHING_RESOLUTION_MUTUAL_DISPUTE = 5;
    uint8 internal constant TEACHING_RESOLUTION_EXTERNAL_EXCEPTION = 6;

    address internal immutable TEACHING_NFT_TOKEN;
    address internal teachingRewardDistributor;
    mapping(uint64 courseTypeId => SparkDaoTypes.TeachingCourseType) internal teachingCourseTypes;
    mapping(uint64 teachingNftId => SparkDaoTypes.TeachingSession) internal teachingSessions;

    event TeachingCourseTypeCreated(
        uint64 indexed courseTypeId,
        string name,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    );
    event TeachingSessionCreated(
        uint64 indexed teachingNftId,
        uint64 indexed courseTypeId,
        address indexed teacher,
        address customer,
        uint64 scheduledAt
    );
    event TeachingResolved(
        uint64 indexed teachingNftId,
        uint8 status,
        uint8 resolutionReasonCode,
        address indexed resolver
    );
    event TeachingFaultSettlement(
        uint64 indexed teachingNftId,
        uint8 indexed resolutionReasonCode,
        uint256 customerChargeUnits,
        uint256 customerRefundUnits,
        uint256 teacherPayoutUnits,
        uint256 researchRewardUnits,
        uint256 serviceReserveUnits,
        uint8 remedialLessonCount
    );
    event TeachingRedeemed(uint64 indexed teachingNftId, address indexed teacher, uint256 amount);

    constructor(
        address authority_,
        address coordinator_,
        address treasury_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_,
        address researchPositionToken_,
        address teachingNftToken_
    )
        ResearchRegistry(
            authority_,
            coordinator_,
            treasury_,
            stableAsset_,
            rewardUnlockSeconds_,
            buybackWaitSeconds_,
            researchPositionToken_
        )
    {
        if (teachingNftToken_ == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }
        TEACHING_NFT_TOKEN = teachingNftToken_;
    }

    function setTeachingRewardDistributor(address distributor) external onlyAuthority {
        if (teachingRewardDistributor != address(0)) {
            revert SparkDaoErrors.TeachingRewardDistributorAlreadySet();
        }
        if (ITeachingRewardDistributor(distributor).TEACHING_REGISTRY() != address(this)) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
        teachingRewardDistributor = distributor;
    }

    function settleTeachingRewardClaim(
        address stableAsset,
        address recipient,
        uint64 assetId,
        uint64 positionId,
        uint256 claimAmount,
        uint256 dustUnits
    ) external {
        if (msg.sender != teachingRewardDistributor) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }

        SparkDaoTypes.ResearchPosition storage position = _requirePosition(assetId, positionId);
        if (claimAmount != 0) {
            position.totalClaimedUnits += claimAmount;
        }
        uint256 releasedUnits = claimAmount + dustUnits;
        if (releasedUnits != 0) {
            _releaseVaultUnits(stableAsset, releasedUnits);
        }
        if (claimAmount != 0) {
            _safeTransfer(stableAsset, recipient, claimAmount);
        }
    }

    function getTeachingSessionState(uint64 teachingNftId)
        external
        view
        returns (
            uint8 status,
            bool firstRoundFrozen,
            bool collateralLocked,
            bool researchDistributionRecorded,
            uint64 resolvedAt,
            uint64 redeemedAt
        )
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        uint8 statusValue = session.status;
        return (
            statusValue,
            session.firstRoundFrozen,
            session.collateralLocked,
            statusValue == TEACHING_STATUS_COMPLETED || statusValue == TEACHING_STATUS_FORCED_VALID
                || statusValue == TEACHING_STATUS_REDEEMED
                || statusValue == TEACHING_STATUS_TEACHER_FAULT_REMEDIATION
                || statusValue == TEACHING_STATUS_CUSTOMER_FAULT_SETTLED,
            session.resolvedAt,
            session.redeemedAt
        );
    }

    function getTeachingFaultSettlement(uint64 teachingNftId)
        external
        view
        returns (
            uint8 remedialLessonCount,
            uint256 customerChargeUnits,
            uint256 customerRefundUnits,
            uint256 teacherPayoutUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits
        )
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        return (
            session.remedialLessonCount,
            session.faultCustomerChargeUnits,
            session.faultCustomerRefundUnits,
            session.faultTeacherPayoutUnits,
            session.faultResearchRewardUnits,
            session.faultServiceReserveUnits
        );
    }

    function getTeachingSessionSettlementResearchLayers(uint64 teachingNftId)
        external
        view
        returns (uint16[] memory)
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        uint256 layerCount = session.settlementResearchLayerCount;
        uint16[] memory layers = new uint16[](layerCount);
        uint256 packed = session.settlementResearchActiveLayersPacked;
        for (uint256 i = 0; i < layerCount;) {
            // forge-lint: disable-next-line(unsafe-typecast)
            layers[i] = uint16(packed >> (i * 16));
            unchecked {
                ++i;
            }
        }
        return layers;
    }

    function createTeachingCourseType(
        string calldata name,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) external onlyCoordinator returns (uint64 courseTypeId) {
        if (bytes(name).length == 0 || bytes(name).length > SparkDaoTypes.MAX_COURSE_TYPE_NAME_LEN)
        {
            revert SparkDaoErrors.InvalidCourseTypeName();
        }
        if (listPriceUnits == 0 || teacherSalaryUnits == 0) {
            revert SparkDaoErrors.InvalidAmount();
        }
        if (researchShareBps > SparkDaoTypes.MAX_TEACHING_RESEARCH_SHARE_BPS) {
            revert SparkDaoErrors.InvalidResearchShareBps();
        }

        courseTypeId = daoState.nextCourseTypeId;
        daoState.nextCourseTypeId += 1;

        SparkDaoTypes.TeachingCourseType storage courseType = teachingCourseTypes[courseTypeId];
        courseType.exists = true;
        courseType.courseTypeId = courseTypeId;
        courseType.name = name;
        courseType.stableAsset = daoState.stableAsset;
        courseType.listPriceUnits = listPriceUnits;
        courseType.teacherSalaryUnits = teacherSalaryUnits;
        courseType.researchShareBps = researchShareBps;

        emit TeachingCourseTypeCreated(
            courseTypeId, name, listPriceUnits, teacherSalaryUnits, researchShareBps
        );
    }

    function createTeachingSession(SparkDaoTypes.CreateTeachingSessionParams calldata params)
        external
        onlyCoordinator
        returns (uint64 teachingNftId)
    {
        if (params.teacher == address(0) || params.customer == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }
        if (
            params.customerDiscountBps == 0
                || params.customerDiscountBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR
        ) {
            revert SparkDaoErrors.InvalidDiscountBps();
        }
        if (params.linkedResearchAssetIds.length > SparkDaoTypes.MAX_TEACHING_RESEARCH_LINKS) {
            revert SparkDaoErrors.TooManyResearchLinks();
        }
        if (params.scheduledAt <= block.timestamp) revert SparkDaoErrors.InvalidScheduledAt();

        SparkDaoTypes.TeachingCourseType storage courseType =
            _requireTeachingCourseType(params.courseTypeId);
        uint256 discountedPriceUnits = (courseType.listPriceUnits * params.customerDiscountBps)
            / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        uint256 researchPoolUnits = (discountedPriceUnits * courseType.researchShareBps)
            / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        if (discountedPriceUnits < courseType.teacherSalaryUnits + researchPoolUnits) {
            revert SparkDaoErrors.InvalidAmount();
        }
        uint16[] memory normalizedWeights = _normalizeResearchWeights(
            params.linkedResearchAssetIds, params.linkedResearchWeightBps
        );
        _assertLinkedResearchAssetsReady(params.linkedResearchAssetIds, courseType.researchShareBps);

        teachingNftId = daoState.nextTeachingNftId;
        daoState.nextTeachingNftId += 1;

        SparkDaoTypes.TeachingSession storage session = teachingSessions[teachingNftId];
        session.exists = true;
        session.teachingNftId = teachingNftId;
        session.courseTypeId = params.courseTypeId;
        session.teacher = params.teacher;
        session.customer = params.customer;
        session.stableAsset = courseType.stableAsset;
        session.scheduledAt = params.scheduledAt;
        session.listPriceUnits = courseType.listPriceUnits;
        session.teacherSalaryUnits = courseType.teacherSalaryUnits;
        session.customerDiscountBps = params.customerDiscountBps;
        session.researchShareBps = courseType.researchShareBps;
        session.linkedResearchLinks =
            _packResearchLinks(params.linkedResearchAssetIds, normalizedWeights);
        session.secondRoundDeadlineAt =
            params.scheduledAt + SparkDaoTypes.TEACHING_SECOND_ROUND_TIMEOUT_SECONDS;
        session.redeemableAt = params.scheduledAt + SparkDaoTypes.TEACHING_REDEEM_DELAY_SECONDS;
        session.status = TEACHING_STATUS_SCHEDULED;
        ITeachingNftToken(TEACHING_NFT_TOKEN).mint(params.teacher, teachingNftId);

        emit TeachingSessionCreated(
            teachingNftId, params.courseTypeId, params.teacher, params.customer, params.scheduledAt
        );
    }

    function confirmTeachingSchedule(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _confirmTeachingSchedule(session, teacherSide);
    }

    function lockTeachingCollateral(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _lockTeachingCollateral(session, teacherSide);
    }

    function confirmTeachingCompletion(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _confirmTeachingCompletion(session, teacherSide);
    }

    function acknowledgeTeachingCompletion(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _acknowledgeTeachingCompletion(session, teacherSide);
    }

    function coordinatorForceTeachingValid(uint64 teachingNftId, uint8 reasonCode)
        external
        onlyCoordinator
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _assertCoordinatorResolutionWindow(session);
        _assertForcedResolutionCode(reasonCode);

        _settleTeachingAsValid(session, msg.sender, TEACHING_STATUS_FORCED_VALID, reasonCode);
    }

    function coordinatorResolveCustomerFault(uint64 teachingNftId, uint8 reasonCode)
        external
        onlyCoordinator
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _assertCoordinatorResolutionWindow(session);
        _assertCustomerFaultResolutionCode(reasonCode);

        _settleTeachingAsCustomerFault(session, msg.sender, reasonCode);
    }

    function coordinatorResolveTeacherFault(uint64 teachingNftId, uint8 reasonCode)
        external
        onlyCoordinator
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _assertCoordinatorResolutionWindow(session);
        _assertTeacherFaultResolutionCode(reasonCode);

        _settleTeachingAsTeacherFault(session, msg.sender, reasonCode);
    }

    function redeemTeachingPayout(uint64 teachingNftId) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
        if (
            session.status != TEACHING_STATUS_COMPLETED
                && session.status != TEACHING_STATUS_FORCED_VALID
        ) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        if (session.redeemedAt != 0) revert SparkDaoErrors.TeachingAlreadyRedeemed();
        if (block.timestamp < session.redeemableAt) {
            revert SparkDaoErrors.TeachingNotRedeemableYet();
        }

        session.redeemedAt = uint64(block.timestamp);
        session.status = TEACHING_STATUS_REDEEMED;
        _releaseVaultUnits(session.stableAsset, session.teacherSalaryUnits);

        _safeTransfer(session.stableAsset, session.teacher, session.teacherSalaryUnits);

        emit TeachingRedeemed(teachingNftId, session.teacher, session.teacherSalaryUnits);
    }

    function _freezeFirstRoundIfReady(SparkDaoTypes.TeachingSession storage session) internal {
        if (session.teacherConfirmedSchedule && session.customerConfirmedSchedule) {
            session.firstRoundFrozen = true;
            session.status = TEACHING_STATUS_CONFIRMED;
        }
    }

    function _confirmTeachingSchedule(
        SparkDaoTypes.TeachingSession storage session,
        bool teacherSide
    ) internal {
        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (session.teacherConfirmedSchedule) revert SparkDaoErrors.TeachingAlreadySigned();
            session.teacherConfirmedSchedule = true;
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (session.customerConfirmedSchedule) revert SparkDaoErrors.TeachingAlreadySigned();
            session.customerConfirmedSchedule = true;
        }

        _assertRoundOneSchedulable(session);
        _freezeFirstRoundIfReady(session);
    }

    function _updateCollateralState(SparkDaoTypes.TeachingSession storage session) internal {
        if (session.teacherBondLocked && session.customerPaymentLocked) {
            session.collateralLocked = true;
        }
    }

    function _lockTeachingCollateral(
        SparkDaoTypes.TeachingSession storage session,
        bool teacherSide
    ) internal {
        uint256 amount;
        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (session.teacherBondLocked) revert SparkDaoErrors.TeachingCollateralAlreadyLocked();
            session.teacherBondLocked = true;
            amount = _teacherBondUnits(session);
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (session.customerPaymentLocked) {
                revert SparkDaoErrors.TeachingCollateralAlreadyLocked();
            }
            session.customerPaymentLocked = true;
            amount = _discountedPriceUnits(session);
        }

        if (!session.firstRoundFrozen || session.status != TEACHING_STATUS_CONFIRMED) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        _safeTransferFrom(session.stableAsset, msg.sender, address(this), amount);

        _updateCollateralState(session);
        _reserveVaultUnits(session.stableAsset, amount);
    }

    function _confirmTeachingCompletion(
        SparkDaoTypes.TeachingSession storage session,
        bool teacherSide
    ) internal {
        _assertTeachingCompletionWindow(session);

        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (session.teacherConfirmedCompletion) revert SparkDaoErrors.TeachingAlreadySigned();
            session.teacherConfirmedCompletion = true;
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (session.customerConfirmedCompletion) revert SparkDaoErrors.TeachingAlreadySigned();
            session.customerConfirmedCompletion = true;
        }

        if (session.teacherConfirmedCompletion && session.customerConfirmedCompletion) {
            _settleTeachingAsValid(
                session,
                msg.sender,
                TEACHING_STATUS_COMPLETED,
                TEACHING_RESOLUTION_SUCCESSFUL_COMPLETION
            );
        }
    }

    function _acknowledgeTeachingCompletion(
        SparkDaoTypes.TeachingSession storage session,
        bool teacherSide
    ) internal {
        _assertTeachingCompletionWindow(session);

        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (session.teacherConfirmedCompletion) revert SparkDaoErrors.TeachingAlreadySigned();
            if (session.customerConfirmedCompletion) {
                revert SparkDaoErrors.TeachingRequiresSettlementAccounts();
            }
            session.teacherConfirmedCompletion = true;
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (session.customerConfirmedCompletion) revert SparkDaoErrors.TeachingAlreadySigned();
            if (session.teacherConfirmedCompletion) {
                revert SparkDaoErrors.TeachingRequiresSettlementAccounts();
            }
            session.customerConfirmedCompletion = true;
        }
    }

    function _settleTeachingAsValid(
        SparkDaoTypes.TeachingSession storage session,
        address resolver,
        uint8 finalStatus,
        uint8 reasonCode
    ) internal {
        if (session.teacherBondReleasedAt != 0) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint256 distributedResearchUnits = _recordSettlementRewards(session);
        uint256 teacherBondUnits = _teacherBondUnits(session);
        uint256 daoResidualUnits = _daoResidualUnits(session);
        uint256 undistributedResearchUnits = _researchPoolUnits(session) - distributedResearchUnits;
        _releaseVaultUnits(
            session.stableAsset, teacherBondUnits + daoResidualUnits + undistributedResearchUnits
        );

        session.teacherBondReleasedAt = uint64(block.timestamp);
        session.resolvedAt = uint64(block.timestamp);
        session.status = finalStatus;

        _safeTransfer(session.stableAsset, session.teacher, teacherBondUnits);

        emit TeachingResolved(session.teachingNftId, session.status, reasonCode, resolver);
    }

    function _settleTeachingAsCustomerFault(
        SparkDaoTypes.TeachingSession storage session,
        address resolver,
        uint8 reasonCode
    ) internal {
        if (session.teacherBondReleasedAt != 0) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint256 customerPaymentUnits = _discountedPriceUnits(session);
        uint256 customerChargeUnits = _halfPriceUnits(customerPaymentUnits);
        uint256 customerRefundUnits = customerPaymentUnits - customerChargeUnits;
        uint256 teacherPayoutUnits = _min(session.teacherSalaryUnits, customerChargeUnits);
        uint256 serviceReserveUnits = customerChargeUnits - teacherPayoutUnits;
        uint256 teacherBondUnits = _teacherBondUnits(session);

        _releaseVaultUnits(session.stableAsset, teacherBondUnits + customerPaymentUnits);
        session.teacherBondReleasedAt = uint64(block.timestamp);
        _recordFaultSettlement(
            session,
            TEACHING_STATUS_CUSTOMER_FAULT_SETTLED,
            reasonCode,
            0,
            customerChargeUnits,
            customerRefundUnits,
            teacherPayoutUnits,
            0,
            serviceReserveUnits
        );

        _safeTransfer(session.stableAsset, session.teacher, teacherBondUnits + teacherPayoutUnits);
        if (customerRefundUnits != 0) {
            _safeTransfer(session.stableAsset, session.customer, customerRefundUnits);
        }

        emit TeachingResolved(session.teachingNftId, session.status, reasonCode, resolver);
    }

    function _settleTeachingAsTeacherFault(
        SparkDaoTypes.TeachingSession storage session,
        address resolver,
        uint8 reasonCode
    ) internal {
        if (session.teacherBondReleasedAt != 0) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint256 customerPaymentUnits = _discountedPriceUnits(session);
        uint256 customerChargeUnits = _halfPriceUnits(customerPaymentUnits);
        uint256 customerRefundUnits = customerPaymentUnits - customerChargeUnits;
        uint256 teacherBondUnits = _teacherBondUnits(session);
        uint256 targetResearchUnits = _teacherFaultResearchPoolUnits(session);
        if (targetResearchUnits > customerChargeUnits) {
            revert SparkDaoErrors.FaultSettlementInsolvent();
        }

        uint256 distributedResearchUnits =
            _recordSettlementRewardsWithPool(session, targetResearchUnits);
        uint256 serviceReserveUnits = customerChargeUnits - distributedResearchUnits;
        _releaseVaultUnits(
            session.stableAsset, teacherBondUnits + customerPaymentUnits - distributedResearchUnits
        );
        session.teacherBondReleasedAt = uint64(block.timestamp);
        _recordFaultSettlement(
            session,
            TEACHING_STATUS_TEACHER_FAULT_REMEDIATION,
            reasonCode,
            1,
            customerChargeUnits,
            customerRefundUnits,
            0,
            distributedResearchUnits,
            serviceReserveUnits
        );

        _safeTransfer(session.stableAsset, session.teacher, teacherBondUnits);
        if (customerRefundUnits != 0) {
            _safeTransfer(session.stableAsset, session.customer, customerRefundUnits);
        }

        emit TeachingResolved(session.teachingNftId, session.status, reasonCode, resolver);
    }

    function _recordFaultSettlement(
        SparkDaoTypes.TeachingSession storage session,
        uint8 status,
        uint8 reasonCode,
        uint8 remedialLessonCount,
        uint256 customerChargeUnits,
        uint256 customerRefundUnits,
        uint256 teacherPayoutUnits,
        uint256 researchRewardUnits,
        uint256 serviceReserveUnits
    ) internal {
        session.resolvedAt = uint64(block.timestamp);
        session.status = status;
        session.remedialLessonCount = remedialLessonCount;
        session.faultCustomerChargeUnits = customerChargeUnits;
        session.faultCustomerRefundUnits = customerRefundUnits;
        session.faultTeacherPayoutUnits = teacherPayoutUnits;
        session.faultResearchRewardUnits = researchRewardUnits;
        session.faultServiceReserveUnits = serviceReserveUnits;

        emit TeachingFaultSettlement(
            session.teachingNftId,
            reasonCode,
            customerChargeUnits,
            customerRefundUnits,
            teacherPayoutUnits,
            researchRewardUnits,
            serviceReserveUnits,
            remedialLessonCount
        );
    }

    function _recordSettlementRewards(SparkDaoTypes.TeachingSession storage session)
        internal
        returns (uint256 distributedUnits)
    {
        return _recordSettlementRewardsWithPool(session, _researchPoolUnits(session));
    }

    function _recordSettlementRewardsWithPool(
        SparkDaoTypes.TeachingSession storage session,
        uint256 researchPoolUnits
    ) internal returns (uint256 distributedUnits) {
        if (!_requiresResearchDistribution(session)) {
            _clearSettlementResearchLayers(session);
            return 0;
        }

        address distributor = _requireTeachingRewardDistributor();
        uint64 snapshotAt = session.scheduledAt;
        uint64 unlockAt = _normalizeTeachingUnlockBucket(
            uint64(block.timestamp) + daoState.rewardUnlockSeconds, daoState.rewardUnlockSeconds
        );
        uint256 linkCount = session.linkedResearchLinks.length;

        _clearSettlementResearchLayers(session);
        for (uint256 assetIndex = 0; assetIndex < linkCount;) {
            (uint64 assetId, uint16 assetWeightBps) =
                _unpackResearchLink(session.linkedResearchLinks[assetIndex]);
            (uint16 snapshotActiveLayer, uint256 assetDistributedUnits) = _recordAssetRewardPool(
                distributor,
                session,
                assetId,
                assetWeightBps,
                researchPoolUnits,
                snapshotAt,
                unlockAt
            );
            _pushSettlementResearchLayer(session, snapshotActiveLayer);
            distributedUnits += assetDistributedUnits;
            unchecked {
                ++assetIndex;
            }
        }
    }

    function _recordAssetRewardPool(
        address distributor,
        SparkDaoTypes.TeachingSession storage session,
        uint64 assetId,
        uint16 assetWeightBps,
        uint256 researchPoolUnits,
        uint64 snapshotAt,
        uint64 unlockAt
    ) internal returns (uint16 snapshotActiveLayer, uint256 distributedUnits) {
        _requireAsset(assetId);
        snapshotActiveLayer = _snapshotActiveLayerFromCheckpoints(assetId, snapshotAt);

        uint256 assetPoolUnits = _computeWeightedAmount(researchPoolUnits, assetWeightBps);
        if (assetPoolUnits == 0 || snapshotActiveLayer == 0) {
            return (snapshotActiveLayer, 0);
        }

        uint16 totalEffectiveShareBps = _snapshotEffectiveShareBps(assetId, snapshotAt);
        distributedUnits = _computeWeightedAmount(assetPoolUnits, totalEffectiveShareBps);
        if (distributedUnits == 0) return (snapshotActiveLayer, 0);

        ITeachingRewardDistributor(distributor)
            .recordTeachingRewardPool(
                session.teachingNftId,
                assetId,
                session.stableAsset,
                assetPoolUnits,
                distributedUnits,
                snapshotAt,
                unlockAt,
                snapshotActiveLayer,
                totalEffectiveShareBps
            );
    }

    function _unpackResearchLink(uint80 packedLink)
        internal
        pure
        returns (uint64 assetId, uint16 weightBps)
    {
        // forge-lint: disable-next-line(unsafe-typecast)
        assetId = uint64(packedLink);
        // forge-lint: disable-next-line(unsafe-typecast)
        weightBps = uint16(packedLink >> 64);
    }

    function _clearSettlementResearchLayers(SparkDaoTypes.TeachingSession storage session)
        internal
    {
        session.settlementResearchActiveLayersPacked = 0;
        session.settlementResearchLayerCount = 0;
    }

    function _pushSettlementResearchLayer(
        SparkDaoTypes.TeachingSession storage session,
        uint16 snapshotActiveLayer
    ) internal {
        uint256 index = session.settlementResearchLayerCount;
        session.settlementResearchActiveLayersPacked |= uint256(snapshotActiveLayer) << (index * 16);
        session.settlementResearchLayerCount += 1;
    }

    function _normalizeTeachingUnlockBucket(uint64 exactUnlockAt, uint64 rewardUnlockSeconds)
        internal
        pure
        returns (uint64)
    {
        if (rewardUnlockSeconds == 0) return exactUnlockAt;
        uint64 daySeconds = SparkDaoTypes.DAY_SECONDS;
        // forge-lint: disable-next-line(divide-before-multiply)
        return ((exactUnlockAt + daySeconds - 1) / daySeconds) * daySeconds;
    }

    function _computeWeightedAmount(uint256 baseAmount, uint16 weightBps)
        internal
        pure
        returns (uint256)
    {
        return (baseAmount * weightBps) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
    }

    function _assertRoundOneSchedulable(SparkDaoTypes.TeachingSession storage session)
        internal
        view
    {
        if (session.status != TEACHING_STATUS_SCHEDULED) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        if (session.firstRoundFrozen) revert SparkDaoErrors.TeachingAlreadyFrozen();
    }

    function _assertTeachingCompletionWindow(SparkDaoTypes.TeachingSession storage session)
        internal
        view
    {
        if (session.status != TEACHING_STATUS_CONFIRMED) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        if (!session.collateralLocked) revert SparkDaoErrors.TeachingCollateralNotLocked();
        if (block.timestamp < session.scheduledAt) {
            revert SparkDaoErrors.TeachingCompletionTooEarly();
        }
        if (block.timestamp > session.secondRoundDeadlineAt) {
            revert SparkDaoErrors.TeachingCoordinatorTooEarly();
        }
    }

    function _assertCoordinatorResolutionWindow(SparkDaoTypes.TeachingSession storage session)
        internal
        view
    {
        if (session.status != TEACHING_STATUS_CONFIRMED) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        if (!session.collateralLocked) revert SparkDaoErrors.TeachingCollateralNotLocked();
        if (block.timestamp < session.secondRoundDeadlineAt) {
            revert SparkDaoErrors.TeachingCoordinatorTooEarly();
        }
    }

    function _assertForcedResolutionCode(uint8 reasonCode) internal pure {
        if (
            reasonCode != TEACHING_RESOLUTION_COORDINATOR_FORCED_VALID
                && reasonCode != TEACHING_RESOLUTION_MUTUAL_DISPUTE
                && reasonCode != TEACHING_RESOLUTION_EXTERNAL_EXCEPTION
        ) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _assertCustomerFaultResolutionCode(uint8 reasonCode) internal pure {
        if (reasonCode != TEACHING_RESOLUTION_CUSTOMER_FAULT) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _assertTeacherFaultResolutionCode(uint8 reasonCode) internal pure {
        if (reasonCode != TEACHING_RESOLUTION_TEACHER_FAULT) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _normalizeResearchWeights(uint64[] calldata assetIds, uint16[] calldata weights)
        internal
        pure
        returns (uint16[] memory normalized)
    {
        uint256 assetCount = assetIds.length;
        if (assetCount == 0) {
            if (weights.length != 0) revert SparkDaoErrors.InvalidResearchWeights();
            return new uint16[](0);
        }

        for (uint256 i = 0; i < assetCount;) {
            for (uint256 j = i + 1; j < assetCount;) {
                if (assetIds[i] == assetIds[j]) revert SparkDaoErrors.InvalidResearchWeights();
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (weights.length == 0) {
            normalized = new uint16[](assetCount);
            // forge-lint: disable-next-line(unsafe-typecast)
            uint16 compactAssetCount = uint16(assetCount);
            uint16 evenWeight = SparkDaoTypes.BASIS_POINTS_DENOMINATOR / compactAssetCount;
            uint16 assignedTotal = evenWeight * compactAssetCount;
            uint16 remainder = SparkDaoTypes.BASIS_POINTS_DENOMINATOR - assignedTotal;

            for (uint256 i = 0; i < assetCount;) {
                normalized[i] = evenWeight;
                unchecked {
                    ++i;
                }
            }
            normalized[assetCount - 1] += remainder;
            return normalized;
        }

        uint256 weightCount = weights.length;
        if (weightCount != assetCount) revert SparkDaoErrors.InvalidResearchWeights();

        normalized = new uint16[](weightCount);
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < weightCount;) {
            normalized[i] = weights[i];
            totalWeight += weights[i];
            unchecked {
                ++i;
            }
        }
        if (totalWeight != SparkDaoTypes.BASIS_POINTS_DENOMINATOR) {
            revert SparkDaoErrors.InvalidResearchWeights();
        }
    }

    function _assertLinkedResearchAssetsReady(uint64[] calldata assetIds, uint16 researchShareBps)
        internal
        view
    {
        uint256 assetCount = assetIds.length;
        for (uint256 i = 0; i < assetCount;) {
            SparkDaoTypes.ResearchAsset storage asset = researchAssets[assetIds[i]];
            if (!asset.exists) revert SparkDaoErrors.AssetNotFound();
            if (researchShareBps > 0 && !asset.currentLayerSealed) {
                revert SparkDaoErrors.LinkedResearchLayerNotSealed();
            }
            unchecked {
                ++i;
            }
        }
    }

    function _packResearchLinks(uint64[] calldata assetIds, uint16[] memory weights)
        internal
        pure
        returns (uint80[] memory packedLinks)
    {
        uint256 assetCount = assetIds.length;
        packedLinks = new uint80[](assetCount);
        for (uint256 i = 0; i < assetCount;) {
            packedLinks[i] = uint80(assetIds[i]) | (uint80(weights[i]) << 64);
            unchecked {
                ++i;
            }
        }
    }

    function _discountedPriceUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return (session.listPriceUnits * session.customerDiscountBps)
            / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
    }

    function _teacherBondUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return session.teacherSalaryUnits * 2;
    }

    function _halfPriceUnits(uint256 priceUnits) internal pure returns (uint256) {
        return priceUnits / 2;
    }

    function _researchPoolUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return (_discountedPriceUnits(session) * session.researchShareBps)
            / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
    }

    function _teacherFaultResearchPoolUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return _researchPoolUnits(session) * 2;
    }

    function _daoResidualUnits(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return _discountedPriceUnits(session) - session.teacherSalaryUnits
            - _researchPoolUnits(session);
    }

    function _requiresResearchDistribution(SparkDaoTypes.TeachingSession storage session)
        internal
        view
        returns (bool)
    {
        return session.researchShareBps > 0 && session.linkedResearchLinks.length > 0
            && _discountedPriceUnits(session) > 0;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _requireTeachingCourseType(uint64 courseTypeId)
        internal
        view
        returns (SparkDaoTypes.TeachingCourseType storage courseType)
    {
        courseType = teachingCourseTypes[courseTypeId];
        if (!courseType.exists) revert SparkDaoErrors.InvalidCourseTypeId();
    }

    function _requireTeachingSession(uint64 teachingNftId)
        internal
        view
        returns (SparkDaoTypes.TeachingSession storage session)
    {
        session = teachingSessions[teachingNftId];
        if (!session.exists) revert SparkDaoErrors.InvalidTeachingNftId();
    }

    function _requireTeachingRewardDistributor() internal view returns (address distributor) {
        distributor = teachingRewardDistributor;
        if (distributor == address(0)) revert SparkDaoErrors.ZeroAddress();
    }
}
