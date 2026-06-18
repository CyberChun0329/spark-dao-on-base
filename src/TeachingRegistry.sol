// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoConfig } from "./SparkDaoConfig.sol";
import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { IResearchRegistryForTeaching } from "./interfaces/IResearchRegistryForTeaching.sol";
import { ITeachingEconomicsPolicyGuard } from "./interfaces/ITeachingEconomicsPolicyGuard.sol";
import { ITeachingFaultPolicyGuard } from "./interfaces/ITeachingFaultPolicyGuard.sol";
import { ITeachingRewardDistributor } from "./interfaces/ITeachingRewardDistributor.sol";
import { ITeachingNftToken } from "./interfaces/ITeachingNftToken.sol";

contract TeachingRegistry is SparkDaoConfig {
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

    address public immutable RESEARCH_REGISTRY;
    address internal immutable TEACHING_NFT_TOKEN;
    address internal immutable TEACHING_POLICY_GUARD;
    address internal defaultTeachingEconomicsPolicy;
    address internal defaultTeachingFaultPolicy;
    uint8 internal defaultTeachingFaultPolicyVersion;
    address internal teachingRewardDistributor;
    mapping(uint64 courseTypeId => SparkDaoTypes.TeachingCourseType) internal teachingCourseTypes;
    mapping(uint64 teachingNftId => SparkDaoTypes.TeachingSession) internal teachingSessions;
    mapping(uint64 teachingNftId => SparkDaoTypes.FrozenTeachingFaultQuotes) internal
        frozenTeachingFaultQuotes;

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
        uint256 teacherImmediatePayoutUnits,
        uint256 remedialTeacherPayoutUnits,
        uint256 researchRewardUnits,
        uint256 serviceReserveUnits,
        uint8 remedialLessonCount
    );
    event TeachingRedeemed(uint64 indexed teachingNftId, address indexed teacher, uint256 amount);
    event TeachingRemedialWageSettled(
        uint64 indexed teachingNftId, address indexed teacher, uint256 amount
    );
    event TeachingRewardDistributorSet(address indexed distributor);
    event TeachingEconomicsPolicyUpdated(address indexed previousPolicy, address indexed newPolicy);
    event TeachingFaultPolicyUpdated(
        address indexed previousPolicy, address indexed newPolicy, uint8 version
    );

    constructor(
        address authority_,
        address coordinator_,
        address treasury_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_,
        address researchRegistry_,
        address teachingNftToken_,
        address teachingPolicyGuard_,
        address teachingEconomicsPolicy_,
        address teachingFaultPolicy_
    )
        SparkDaoConfig(
            authority_,
            coordinator_,
            treasury_,
            stableAsset_,
            rewardUnlockSeconds_,
            buybackWaitSeconds_
        )
    {
        if (researchRegistry_ == address(0) || researchRegistry_.code.length == 0) {
            revert SparkDaoErrors.InvalidResearchRegistry();
        }
        if (teachingNftToken_ == address(0) || teachingPolicyGuard_ == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }
        _assertContract(teachingNftToken_);
        _assertContract(teachingPolicyGuard_);
        RESEARCH_REGISTRY = researchRegistry_;
        TEACHING_NFT_TOKEN = teachingNftToken_;
        TEACHING_POLICY_GUARD = teachingPolicyGuard_;
        _setDefaultTeachingEconomicsPolicy(teachingEconomicsPolicy_);
        _setDefaultTeachingFaultPolicy(teachingFaultPolicy_);
    }

    function updateDefaultTeachingEconomicsPolicy(address newPolicy) external onlyAuthority {
        _setDefaultTeachingEconomicsPolicy(newPolicy);
    }

    function updateDefaultTeachingFaultPolicy(address newPolicy) external onlyAuthority {
        _setDefaultTeachingFaultPolicy(newPolicy);
    }

    function setTeachingRewardDistributor(address distributor) external onlyAuthority {
        if (teachingRewardDistributor != address(0)) {
            revert SparkDaoErrors.TeachingRewardDistributorAlreadySet();
        }
        if (distributor == address(0) || distributor.code.length == 0) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
        address configuredTeachingRegistry;
        address configuredResearchRegistry;
        try ITeachingRewardDistributor(distributor).TEACHING_REGISTRY() returns (address value) {
            configuredTeachingRegistry = value;
        } catch {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
        try ITeachingRewardDistributor(distributor).RESEARCH_REGISTRY() returns (address value) {
            configuredResearchRegistry = value;
        } catch {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
        if (
            configuredTeachingRegistry != address(this)
                || configuredResearchRegistry != RESEARCH_REGISTRY
        ) {
            revert SparkDaoErrors.UnauthorizedTeachingRewardDistributor();
        }
        teachingRewardDistributor = distributor;
        emit TeachingRewardDistributorSet(distributor);
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

        IResearchRegistryForTeaching(RESEARCH_REGISTRY)
            .recordTeachingRewardClaim(assetId, positionId, claimAmount);
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
                || statusValue == TEACHING_STATUS_TEACHER_FAULT_REMEDIATION,
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
            uint256 teacherImmediatePayoutUnits,
            uint256 remedialTeacherPayoutUnits,
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
            session.faultRemedialTeacherPayoutUnits,
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

    function getTeachingRemedialWageSettlement(uint64 teachingNftId)
        external
        view
        returns (uint256 remedialTeacherPayoutUnits, uint64 remedialWageSettledAt)
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        return (session.faultRemedialTeacherPayoutUnits, session.remedialWageSettledAt);
    }

    function getTeachingModuleState()
        external
        view
        returns (
            address researchRegistry,
            address teachingNftToken,
            address policyGuard,
            address economicsPolicy,
            address faultPolicy,
            uint8 faultPolicyVersion,
            address rewardDistributor
        )
    {
        return (
            RESEARCH_REGISTRY,
            TEACHING_NFT_TOKEN,
            TEACHING_POLICY_GUARD,
            defaultTeachingEconomicsPolicy,
            defaultTeachingFaultPolicy,
            defaultTeachingFaultPolicyVersion,
            teachingRewardDistributor
        );
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
        address economicsPolicy = defaultTeachingEconomicsPolicy;
        SparkDaoTypes.TeachingEconomicsQuote memory economics = _quoteCourseEconomics(
            economicsPolicy, listPriceUnits, teacherSalaryUnits, researchShareBps
        );

        address faultPolicy = defaultTeachingFaultPolicy;
        uint8 faultPolicyVersion = defaultTeachingFaultPolicyVersion;
        _quoteCustomerFault(faultPolicy, economics.lessonPriceUnits, economics.teacherSalaryUnits);
        _quoteTeacherFault(
            faultPolicy,
            economics.lessonPriceUnits,
            economics.teacherSalaryUnits,
            economics.teacherFaultResearchRewardUnits
        );

        courseTypeId = daoState.nextCourseTypeId;
        daoState.nextCourseTypeId += 1;

        SparkDaoTypes.TeachingCourseType storage courseType = teachingCourseTypes[courseTypeId];
        courseType.exists = true;
        courseType.courseTypeId = courseTypeId;
        courseType.economicsPolicy = economicsPolicy;
        courseType.faultPolicy = faultPolicy;
        courseType.faultPolicyVersion = faultPolicyVersion;
        courseType.name = name;
        courseType.stableAsset = daoState.stableAsset;
        courseType.listPriceUnits = economics.lessonPriceUnits;
        courseType.teacherSalaryUnits = economics.teacherSalaryUnits;
        courseType.researchShareBps = researchShareBps;

        emit TeachingCourseTypeCreated(
            courseTypeId,
            name,
            economics.lessonPriceUnits,
            economics.teacherSalaryUnits,
            researchShareBps
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
        if (params.linkedResearchAssetIds.length > SparkDaoTypes.MAX_TEACHING_RESEARCH_LINKS) {
            revert SparkDaoErrors.TooManyResearchLinks();
        }
        if (params.scheduledAt <= block.timestamp) revert SparkDaoErrors.InvalidScheduledAt();

        SparkDaoTypes.TeachingCourseType storage courseType =
            _requireTeachingCourseType(params.courseTypeId);
        SparkDaoTypes.TeachingEconomicsQuote memory economics =
            _quoteSessionEconomics(courseType, params.customerDiscountBps);
        SparkDaoTypes.TeachingFaultQuote memory customerFaultQuote = _quoteCustomerFault(
            courseType.faultPolicy, economics.lessonPriceUnits, economics.teacherSalaryUnits
        );
        SparkDaoTypes.TeachingFaultQuote memory teacherFaultQuote = _quoteTeacherFault(
            courseType.faultPolicy,
            economics.lessonPriceUnits,
            economics.teacherSalaryUnits,
            economics.teacherFaultResearchRewardUnits
        );
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
        session.lessonPriceUnits = economics.lessonPriceUnits;
        session.teacherSalaryUnits = economics.teacherSalaryUnits;
        session.teacherBondUnits = economics.teacherBondUnits;
        session.researchRewardUnits = economics.researchRewardUnits;
        session.teacherFaultResearchRewardUnits = economics.teacherFaultResearchRewardUnits;
        session.serviceReserveUnits = economics.serviceReserveUnits;
        session.customerDiscountBps = params.customerDiscountBps;
        session.researchShareBps = courseType.researchShareBps;
        session.faultPolicy = courseType.faultPolicy;
        session.faultPolicyVersion = courseType.faultPolicyVersion;
        session.linkedResearchLinks =
            _packResearchLinks(params.linkedResearchAssetIds, normalizedWeights);
        session.secondRoundDeadlineAt =
            params.scheduledAt + SparkDaoTypes.TEACHING_SECOND_ROUND_TIMEOUT_SECONDS;
        session.redeemableAt = params.scheduledAt + SparkDaoTypes.TEACHING_REDEEM_DELAY_SECONDS;
        session.status = TEACHING_STATUS_SCHEDULED;
        SparkDaoTypes.FrozenTeachingFaultQuotes storage frozenQuotes =
            frozenTeachingFaultQuotes[teachingNftId];
        frozenQuotes.customerFaultQuote = customerFaultQuote;
        frozenQuotes.teacherFaultQuote = teacherFaultQuote;
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

    function withdrawUnmatchedTeachingCollateral(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _withdrawUnmatchedTeachingCollateral(session, teacherSide);
    }

    /// @notice Records the caller's completion signature and settles when both sides have signed.
    /// @dev This is the second-round entrypoint that can execute ordinary settlement, including
    /// reward-pool recording, reserve releases, and stable-asset transfers.
    function confirmTeachingCompletion(uint64 teachingNftId, bool teacherSide) external {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        _confirmTeachingCompletion(session, teacherSide);
    }

    /// @notice Records only the first completion signature without attempting settlement.
    /// @dev This helper is for first-mover UX. If the counterparty has already signed, callers
    /// must use confirmTeachingCompletion so the second signature cannot bypass settlement.
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

        address stableAsset = session.stableAsset;
        address teacher = session.teacher;
        uint256 teacherSalaryUnits = session.teacherSalaryUnits;
        session.redeemedAt = uint64(block.timestamp);
        session.status = TEACHING_STATUS_REDEEMED;
        _releaseVaultUnits(stableAsset, teacherSalaryUnits);

        _safeTransfer(stableAsset, teacher, teacherSalaryUnits);

        emit TeachingRedeemed(teachingNftId, teacher, teacherSalaryUnits);
    }

    function coordinatorSettleTeacherFaultRemedialWage(uint64 teachingNftId)
        external
        onlyCoordinator
    {
        SparkDaoTypes.TeachingSession storage session = _requireTeachingSession(teachingNftId);
        if (
            session.status != TEACHING_STATUS_TEACHER_FAULT_REMEDIATION
                || session.faultRemedialTeacherPayoutUnits == 0
                || session.remedialWageSettledAt != 0
        ) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint256 amount = session.faultRemedialTeacherPayoutUnits;
        address stableAsset = session.stableAsset;
        address teacher = session.teacher;
        session.remedialWageSettledAt = uint64(block.timestamp);
        _releaseVaultUnits(stableAsset, amount);
        _safeTransfer(stableAsset, teacher, amount);

        emit TeachingRemedialWageSettled(teachingNftId, teacher, amount);
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
            amount = session.teacherBondUnits;
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (session.customerPaymentLocked) {
                revert SparkDaoErrors.TeachingCollateralAlreadyLocked();
            }
            session.customerPaymentLocked = true;
            amount = session.lessonPriceUnits;
        }

        if (!session.firstRoundFrozen || session.status != TEACHING_STATUS_CONFIRMED) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        _safeTransferFrom(session.stableAsset, msg.sender, address(this), amount);

        _updateCollateralState(session);
        _reserveVaultUnits(session.stableAsset, amount);
    }

    function _withdrawUnmatchedTeachingCollateral(
        SparkDaoTypes.TeachingSession storage session,
        bool teacherSide
    ) internal {
        if (
            !session.firstRoundFrozen || session.status != TEACHING_STATUS_CONFIRMED
                || session.collateralLocked
        ) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        address participant;
        uint256 amount;
        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (!session.teacherBondLocked) revert SparkDaoErrors.TeachingCollateralNotLocked();
            session.teacherBondLocked = false;
            participant = session.teacher;
            amount = session.teacherBondUnits;
        } else {
            if (session.customer != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
            if (!session.customerPaymentLocked) {
                revert SparkDaoErrors.TeachingCollateralNotLocked();
            }
            session.customerPaymentLocked = false;
            participant = session.customer;
            amount = session.lessonPriceUnits;
        }

        _releaseVaultUnits(session.stableAsset, amount);
        _safeTransfer(session.stableAsset, participant, amount);
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

        address stableAsset = session.stableAsset;
        uint256 distributedResearchUnits = _recordSettlementRewards(session);
        uint256 teacherBondUnits = session.teacherBondUnits;
        uint256 undistributedResearchUnits = session.researchRewardUnits - distributedResearchUnits;
        _releaseVaultUnits(
            stableAsset, teacherBondUnits + session.serviceReserveUnits + undistributedResearchUnits
        );

        uint64 resolvedAt = uint64(block.timestamp);
        session.teacherBondReleasedAt = resolvedAt;
        session.resolvedAt = resolvedAt;
        session.status = finalStatus;

        _safeTransfer(stableAsset, session.teacher, teacherBondUnits);

        emit TeachingResolved(session.teachingNftId, finalStatus, reasonCode, resolver);
    }

    function _settleTeachingAsCustomerFault(
        SparkDaoTypes.TeachingSession storage session,
        address resolver,
        uint8 reasonCode
    ) internal {
        if (session.teacherBondReleasedAt != 0) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint64 teachingNftId = session.teachingNftId;
        address stableAsset = session.stableAsset;
        uint256 customerPaymentUnits = session.lessonPriceUnits;
        SparkDaoTypes.TeachingFaultQuote memory quote =
        frozenTeachingFaultQuotes[teachingNftId].customerFaultQuote;
        uint256 teacherBondUnits = session.teacherBondUnits;

        _releaseVaultUnits(stableAsset, teacherBondUnits + customerPaymentUnits);
        uint64 resolvedAt = uint64(block.timestamp);
        session.teacherBondReleasedAt = resolvedAt;
        _recordFaultSettlement(
            session, TEACHING_STATUS_CUSTOMER_FAULT_SETTLED, reasonCode, quote, resolvedAt
        );

        _safeTransfer(
            stableAsset, session.teacher, teacherBondUnits + quote.teacherImmediatePayoutUnits
        );
        if (quote.customerRefundUnits != 0) {
            _safeTransfer(stableAsset, session.customer, quote.customerRefundUnits);
        }

        emit TeachingResolved(
            teachingNftId, TEACHING_STATUS_CUSTOMER_FAULT_SETTLED, reasonCode, resolver
        );
    }

    function _settleTeachingAsTeacherFault(
        SparkDaoTypes.TeachingSession storage session,
        address resolver,
        uint8 reasonCode
    ) internal {
        if (session.teacherBondReleasedAt != 0) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint64 teachingNftId = session.teachingNftId;
        address stableAsset = session.stableAsset;
        uint256 customerPaymentUnits = session.lessonPriceUnits;
        uint256 teacherBondUnits = session.teacherBondUnits;
        SparkDaoTypes.TeachingFaultQuote memory quote =
        frozenTeachingFaultQuotes[teachingNftId].teacherFaultQuote;

        uint256 distributedResearchUnits =
            _recordSettlementRewardsWithPool(session, quote.researchRewardUnits);
        quote.serviceReserveUnits += quote.researchRewardUnits - distributedResearchUnits;
        quote.researchRewardUnits = distributedResearchUnits;
        _releaseVaultUnits(
            stableAsset,
            teacherBondUnits + customerPaymentUnits - distributedResearchUnits
                - quote.remedialTeacherPayoutUnits
        );
        uint64 resolvedAt = uint64(block.timestamp);
        session.teacherBondReleasedAt = resolvedAt;
        _recordFaultSettlement(
            session, TEACHING_STATUS_TEACHER_FAULT_REMEDIATION, reasonCode, quote, resolvedAt
        );

        _safeTransfer(stableAsset, session.teacher, teacherBondUnits);
        if (quote.customerRefundUnits != 0) {
            _safeTransfer(stableAsset, session.customer, quote.customerRefundUnits);
        }

        emit TeachingResolved(
            teachingNftId, TEACHING_STATUS_TEACHER_FAULT_REMEDIATION, reasonCode, resolver
        );
    }

    function _recordFaultSettlement(
        SparkDaoTypes.TeachingSession storage session,
        uint8 status,
        uint8 reasonCode,
        SparkDaoTypes.TeachingFaultQuote memory quote,
        uint64 resolvedAt
    ) internal {
        session.resolvedAt = resolvedAt;
        session.status = status;
        session.remedialLessonCount = quote.remedialLessonCount;
        session.faultCustomerChargeUnits = quote.customerChargeUnits;
        session.faultCustomerRefundUnits = quote.customerRefundUnits;
        session.faultTeacherPayoutUnits = quote.teacherImmediatePayoutUnits;
        session.faultRemedialTeacherPayoutUnits = quote.remedialTeacherPayoutUnits;
        session.faultResearchRewardUnits = quote.researchRewardUnits;
        session.faultServiceReserveUnits = quote.serviceReserveUnits;

        emit TeachingFaultSettlement(
            session.teachingNftId,
            reasonCode,
            quote.customerChargeUnits,
            quote.customerRefundUnits,
            quote.teacherImmediatePayoutUnits,
            quote.remedialTeacherPayoutUnits,
            quote.researchRewardUnits,
            quote.serviceReserveUnits,
            quote.remedialLessonCount
        );
    }

    function _setDefaultTeachingEconomicsPolicy(address newPolicy) internal {
        _validateTeachingEconomicsPolicy(newPolicy);
        address previousPolicy = defaultTeachingEconomicsPolicy;
        defaultTeachingEconomicsPolicy = newPolicy;
        emit TeachingEconomicsPolicyUpdated(previousPolicy, newPolicy);
    }

    function _validateTeachingEconomicsPolicy(address policy) internal view {
        ITeachingEconomicsPolicyGuard(TEACHING_POLICY_GUARD).validateEconomicsPolicy(policy);
    }

    function _quoteCourseEconomics(
        address economicsPolicy,
        uint256 listPriceUnits,
        uint256 teacherSalaryUnits,
        uint16 researchShareBps
    ) internal view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote) {
        quote = ITeachingEconomicsPolicyGuard(TEACHING_POLICY_GUARD)
            .quoteCourseType(economicsPolicy, listPriceUnits, teacherSalaryUnits, researchShareBps);
    }

    function _quoteSessionEconomics(
        SparkDaoTypes.TeachingCourseType storage courseType,
        uint16 customerDiscountBps
    ) internal view returns (SparkDaoTypes.TeachingEconomicsQuote memory quote) {
        quote = ITeachingEconomicsPolicyGuard(TEACHING_POLICY_GUARD)
            .quoteSession(
                courseType.economicsPolicy,
                courseType.listPriceUnits,
                courseType.teacherSalaryUnits,
                courseType.researchShareBps,
                customerDiscountBps
            );
    }

    function _setDefaultTeachingFaultPolicy(address newPolicy) internal {
        uint8 version = _validateTeachingFaultPolicy(newPolicy);
        address previousPolicy = defaultTeachingFaultPolicy;
        defaultTeachingFaultPolicy = newPolicy;
        defaultTeachingFaultPolicyVersion = version;
        emit TeachingFaultPolicyUpdated(previousPolicy, newPolicy, version);
    }

    function _validateTeachingFaultPolicy(address policy) internal view returns (uint8 version) {
        version = ITeachingFaultPolicyGuard(TEACHING_POLICY_GUARD).validatePolicy(policy);
    }

    function _quoteCustomerFault(
        address faultPolicy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits
    ) internal view returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        quote = ITeachingFaultPolicyGuard(TEACHING_POLICY_GUARD)
            .quoteCustomerFault(faultPolicy, customerPaymentUnits, teacherSalaryUnits);
    }

    function _quoteTeacherFault(
        address faultPolicy,
        uint256 customerPaymentUnits,
        uint256 teacherSalaryUnits,
        uint256 requestedResearchRewardUnits
    ) internal view returns (SparkDaoTypes.TeachingFaultQuote memory quote) {
        quote = ITeachingFaultPolicyGuard(TEACHING_POLICY_GUARD)
            .quoteTeacherFault(
                faultPolicy, customerPaymentUnits, teacherSalaryUnits, requestedResearchRewardUnits
            );
    }

    function _recordSettlementRewards(SparkDaoTypes.TeachingSession storage session)
        internal
        returns (uint256 distributedUnits)
    {
        return _recordSettlementRewardsWithPool(session, session.researchRewardUnits);
    }

    function _recordSettlementRewardsWithPool(
        SparkDaoTypes.TeachingSession storage session,
        uint256 researchPoolUnits
    ) internal returns (uint256 distributedUnits) {
        if (session.researchShareBps == 0 || researchPoolUnits == 0) {
            _clearSettlementResearchLayers(session);
            return 0;
        }
        uint256 linkCount = session.linkedResearchLinks.length;
        if (linkCount == 0) {
            _clearSettlementResearchLayers(session);
            return 0;
        }

        address distributor = _requireTeachingRewardDistributor();
        uint64 snapshotAt = session.scheduledAt;
        uint64 rewardUnlockSeconds = daoState.rewardUnlockSeconds;
        uint64 unlockAt = _normalizeTeachingUnlockBucket(
            uint64(block.timestamp) + rewardUnlockSeconds, rewardUnlockSeconds
        );
        uint64 teachingNftId = session.teachingNftId;
        address stableAsset = session.stableAsset;

        _clearSettlementResearchLayers(session);
        for (uint256 assetIndex = 0; assetIndex < linkCount;) {
            (uint64 assetId, uint16 assetWeightBps) =
                _unpackResearchLink(session.linkedResearchLinks[assetIndex]);
            (uint16 snapshotActiveLayer, uint256 assetDistributedUnits) = _recordAssetRewardPool(
                distributor,
                teachingNftId,
                stableAsset,
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
        uint64 teachingNftId,
        address stableAsset,
        uint64 assetId,
        uint16 assetWeightBps,
        uint256 researchPoolUnits,
        uint64 snapshotAt,
        uint64 unlockAt
    ) internal returns (uint16 snapshotActiveLayer, uint256 distributedUnits) {
        uint16 totalEffectiveShareBps;
        (snapshotActiveLayer, totalEffectiveShareBps) = IResearchRegistryForTeaching(
                RESEARCH_REGISTRY
            ).getTeachingResearchSnapshot(assetId, snapshotAt);

        uint256 assetPoolUnits = _computeWeightedAmount(researchPoolUnits, assetWeightBps);
        if (assetPoolUnits == 0 || snapshotActiveLayer == 0) {
            return (snapshotActiveLayer, 0);
        }

        distributedUnits = _computeWeightedAmount(assetPoolUnits, totalEffectiveShareBps);
        if (distributedUnits == 0) return (snapshotActiveLayer, 0);

        ITeachingRewardDistributor(distributor)
            .recordTeachingRewardPool(
                teachingNftId,
                assetId,
                stableAsset,
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
            IResearchRegistryForTeaching(RESEARCH_REGISTRY)
                .requireTeachingResearchAssetReady(assetIds[i], researchShareBps);
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
