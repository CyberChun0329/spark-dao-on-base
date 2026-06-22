// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoConfig } from "./SparkDaoConfig.sol";
import { SparkTeachingTypes } from "./SparkTeachingTypes.sol";
import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { ITeachingPricingPolicy } from "./interfaces/ITeachingPricingPolicy.sol";
import { ITeachingRewardDistributor } from "./interfaces/ITeachingRewardDistributor.sol";
import { IResearchRegistryForTeaching } from "./interfaces/IResearchRegistryForTeaching.sol";
import { ITeachingNftToken } from "./interfaces/ITeachingNftToken.sol";

contract TeachingRegistry is SparkDaoConfig {
    uint8 internal constant TEACHING_STATUS_OPEN = 0;
    uint8 internal constant TEACHING_STATUS_CLOSED_VALID = 1;
    uint8 internal constant TEACHING_STATUS_CLOSED_TEACHER_FAULT = 2;
    uint8 internal constant TEACHING_RESOLUTION_SUCCESSFUL_COMPLETION = 1;
    uint8 internal constant TEACHING_RESOLUTION_CUSTOMER_FAULT = 2;
    uint8 internal constant TEACHING_RESOLUTION_COORDINATOR_FORCED_VALID = 3;
    uint8 internal constant TEACHING_RESOLUTION_TEACHER_FAULT = 4;
    uint8 internal constant TEACHING_RESOLUTION_MUTUAL_DISPUTE = 5;
    uint8 internal constant TEACHING_RESOLUTION_EXTERNAL_EXCEPTION = 6;

    address public immutable RESEARCH_REGISTRY;
    address public immutable TEACHING_PRICING_POLICY;
    address public immutable TEACHING_NFT_TOKEN;
    address internal teachingRewardDistributor;
    uint64 internal nextTeachingCourseTypeId;
    uint64 internal nextTeachingNftId;

    mapping(uint64 courseTypeId => SparkTeachingTypes.TeachingCourseType) internal
        teachingCourseTypes;
    mapping(uint64 teachingNftId => SparkTeachingTypes.TeachingSession) internal teachingSessions;

    event TeachingCourseTypeCreated(
        uint64 indexed courseTypeId,
        string name,
        uint256 baseSeatPriceUnits,
        uint256 baseTeacherSalaryUnits,
        uint16 researchShareBps
    );
    event TeachingSessionCreated(
        uint64 indexed teachingNftId,
        uint64 indexed courseTypeId,
        address indexed teacher,
        uint16 classSize,
        uint64 scheduledAt
    );
    event TeachingScheduleConfirmed(
        uint64 indexed teachingNftId, address indexed signer, bool teacherSide
    );
    event TeachingSeatPaid(uint64 indexed teachingNftId, uint16 indexed seatIndex, address student);
    event TeachingTeacherBondLocked(uint64 indexed teachingNftId, address indexed teacher);
    event TeachingSeatPaymentWithdrawn(
        uint64 indexed teachingNftId,
        uint16 indexed seatIndex,
        address indexed student,
        uint256 amount
    );
    event TeachingTeacherBondWithdrawn(
        uint64 indexed teachingNftId, address indexed teacher, uint256 amount
    );
    event TeachingSeatCustomerFault(uint64 indexed teachingNftId, uint16 indexed seatIndex);
    event TeachingResolved(
        uint64 indexed teachingNftId,
        uint8 status,
        uint8 reasonCode,
        uint256 teacherPayoutUnits,
        uint256 remedialWageUnits,
        uint256 researchRewardUnits,
        uint256 serviceReserveUnits
    );
    event TeachingSeatRefundClaimed(
        uint64 indexed teachingNftId,
        uint16 indexed seatIndex,
        address indexed student,
        uint256 amount
    );
    event TeachingTeacherPayoutRedeemed(
        uint64 indexed teachingNftId, address indexed teacher, uint256 amount
    );
    event TeachingRemedialWageSettled(
        uint64 indexed teachingNftId, address indexed teacher, uint256 amount
    );
    event TeachingRewardDistributorSet(address indexed distributor);

    constructor(
        address authority_,
        address coordinator_,
        address treasury_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_,
        address researchRegistry_,
        address teachingPricingPolicy_,
        address teachingNftToken_
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
        if (teachingPricingPolicy_ == address(0) || teachingNftToken_ == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }
        _assertContract(teachingPricingPolicy_);
        _assertContract(teachingNftToken_);
        RESEARCH_REGISTRY = researchRegistry_;
        TEACHING_PRICING_POLICY = teachingPricingPolicy_;
        TEACHING_NFT_TOKEN = teachingNftToken_;
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

    function createTeachingCourseType(
        string calldata name,
        uint256 baseSeatPriceUnits,
        uint256 baseTeacherSalaryUnits,
        uint16 researchShareBps
    ) external onlyCoordinator returns (uint64 courseTypeId) {
        if (bytes(name).length == 0 || bytes(name).length > SparkDaoTypes.MAX_COURSE_TYPE_NAME_LEN)
        {
            revert SparkDaoErrors.InvalidCourseTypeName();
        }
        ITeachingPricingPolicy(TEACHING_PRICING_POLICY)
            .quoteTeachingSession(
                baseSeatPriceUnits, baseTeacherSalaryUnits, researchShareBps, 1, 10_000
            );

        courseTypeId = nextTeachingCourseTypeId;
        nextTeachingCourseTypeId += 1;

        SparkTeachingTypes.TeachingCourseType storage courseType = teachingCourseTypes[courseTypeId];
        courseType.exists = true;
        courseType.courseTypeId = courseTypeId;
        courseType.pricingPolicy = TEACHING_PRICING_POLICY;
        courseType.stableAsset = daoState.stableAsset;
        courseType.baseSeatPriceUnits = baseSeatPriceUnits;
        courseType.baseTeacherSalaryUnits = baseTeacherSalaryUnits;
        courseType.researchShareBps = researchShareBps;
        courseType.name = name;

        emit TeachingCourseTypeCreated(
            courseTypeId, name, baseSeatPriceUnits, baseTeacherSalaryUnits, researchShareBps
        );
    }

    function createTeachingSession(SparkTeachingTypes.CreateTeachingSessionParams calldata params)
        external
        onlyCoordinator
        returns (uint64 teachingNftId)
    {
        if (params.teacher == address(0)) revert SparkDaoErrors.ZeroAddress();
        uint256 classSize = params.students.length;
        if (classSize == 0 || classSize > SparkTeachingTypes.MAX_CLASS_SIZE) {
            revert SparkDaoErrors.InvalidAmount();
        }
        if (params.linkedResearchAssetIds.length > SparkDaoTypes.MAX_TEACHING_RESEARCH_LINKS) {
            revert SparkDaoErrors.TooManyResearchLinks();
        }
        if (params.scheduledAt <= block.timestamp) revert SparkDaoErrors.InvalidScheduledAt();

        SparkTeachingTypes.TeachingCourseType storage courseType =
            _requireTeachingCourseType(params.courseTypeId);
        SparkTeachingTypes.TeachingQuote memory quote = ITeachingPricingPolicy(
                courseType.pricingPolicy
            )
            .quoteTeachingSession(
                courseType.baseSeatPriceUnits,
                courseType.baseTeacherSalaryUnits,
                courseType.researchShareBps,
                // forge-lint: disable-next-line(unsafe-typecast)
                uint16(classSize),
                params.customerDiscountBps
            );
        uint16[] memory normalizedWeights = _normalizeResearchWeights(
            params.linkedResearchAssetIds, params.linkedResearchWeightBps
        );
        _assertUniqueStudents(params.students);
        _assertLinkedResearchAssetsReady(params.linkedResearchAssetIds, courseType.researchShareBps);

        teachingNftId = nextTeachingNftId;
        nextTeachingNftId += 1;

        SparkTeachingTypes.TeachingSession storage session = teachingSessions[teachingNftId];
        session.exists = true;
        session.teachingNftId = teachingNftId;
        session.courseTypeId = params.courseTypeId;
        session.pricingPolicy = courseType.pricingPolicy;
        session.teacher = params.teacher;
        session.stableAsset = courseType.stableAsset;
        session.scheduledAt = params.scheduledAt;
        session.seatPriceUnits = quote.seatPriceUnits;
        session.classTeacherSalaryUnits = quote.classTeacherSalaryUnits;
        session.seatTeacherSalaryUnits = quote.seatTeacherSalaryUnits;
        session.teacherBondUnits = quote.teacherBondUnits;
        session.seatResearchRewardUnits = quote.seatResearchRewardUnits;
        session.seatTeacherFaultResearchRewardUnits = quote.seatTeacherFaultResearchRewardUnits;
        session.seatServiceReserveUnits = quote.seatServiceReserveUnits;
        session.classSize = quote.classSize;
        session.researchShareBps = courseType.researchShareBps;
        session.customerDiscountBps = params.customerDiscountBps;
        session.linkedResearchLinks =
            _packResearchLinks(params.linkedResearchAssetIds, normalizedWeights);

        for (uint256 i = 0; i < classSize;) {
            session.seats
                .push(
                    SparkTeachingTypes.TeachingSeat({
                        student: params.students[i],
                        refundOwedUnits: 0,
                        paid: false,
                        attendanceConfirmed: false,
                        customerFault: false,
                        refundClaimed: false
                    })
                );
            unchecked {
                ++i;
            }
        }

        ITeachingNftToken(TEACHING_NFT_TOKEN).mint(params.teacher, teachingNftId);
        emit TeachingSessionCreated(
            teachingNftId, params.courseTypeId, params.teacher, quote.classSize, params.scheduledAt
        );
    }

    function getTeachingSessionState(uint64 teachingNftId)
        external
        view
        returns (
            uint8 status,
            address stableAsset,
            address teacher,
            uint16 classSize,
            uint256 seatPriceUnits,
            uint256 seatTeacherSalaryUnits,
            uint256 teacherBondUnits,
            uint256 teacherPayoutOwedUnits,
            uint256 remedialWageOwedUnits,
            uint256 researchRewardUnits,
            uint256 serviceReserveUnits,
            uint64 closedAt
        )
    {
        SparkTeachingTypes.TeachingSession storage session = _requireTeaching(teachingNftId);
        return (
            session.status,
            session.stableAsset,
            session.teacher,
            session.classSize,
            session.seatPriceUnits,
            session.seatTeacherSalaryUnits,
            session.teacherBondUnits,
            session.teacherPayoutOwedUnits,
            session.remedialWageOwedUnits,
            session.researchRewardUnits,
            session.serviceReserveUnits,
            session.closedAt
        );
    }

    function getTeachingSeat(uint64 teachingNftId, uint16 seatIndex)
        external
        view
        returns (
            address student,
            bool paid,
            bool attendanceConfirmed,
            bool customerFault,
            uint256 refundOwedUnits,
            bool refundClaimed
        )
    {
        SparkTeachingTypes.TeachingSeat storage seat =
            _requireTeachingSeat(teachingNftId, seatIndex);
        return (
            seat.student,
            seat.paid,
            seat.attendanceConfirmed,
            seat.customerFault,
            seat.refundOwedUnits,
            seat.refundClaimed
        );
    }

    function getTeachingScheduleState(uint64 teachingNftId)
        external
        view
        returns (
            bool teacherScheduleConfirmed,
            bool coordinatorScheduleConfirmed,
            bool scheduleConfirmed
        )
    {
        SparkTeachingTypes.TeachingSession storage session = _requireTeaching(teachingNftId);
        teacherScheduleConfirmed = session.teacherScheduleConfirmed;
        coordinatorScheduleConfirmed = session.coordinatorScheduleConfirmed;
        scheduleConfirmed = _teachingScheduleConfirmed(session);
    }

    function getTeachingModuleState()
        external
        view
        returns (address researchRegistry, address pricingPolicy, address rewardDistributor)
    {
        return (RESEARCH_REGISTRY, TEACHING_PRICING_POLICY, teachingRewardDistributor);
    }

    function getTeachingSettlementResearchLayers(uint64 teachingNftId)
        external
        view
        returns (uint16[] memory)
    {
        SparkTeachingTypes.TeachingSession storage session = _requireTeaching(teachingNftId);
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

    function confirmTeachingSchedule(uint64 teachingNftId, bool teacherSide) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        if (teacherSide) {
            if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
            if (session.teacherScheduleConfirmed) {
                revert SparkDaoErrors.TeachingAlreadySigned();
            }
            session.teacherScheduleConfirmed = true;
        } else {
            if (msg.sender != daoState.coordinator) {
                revert SparkDaoErrors.UnauthorizedCoordinator();
            }
            if (session.coordinatorScheduleConfirmed) {
                revert SparkDaoErrors.TeachingAlreadySigned();
            }
            session.coordinatorScheduleConfirmed = true;
        }

        emit TeachingScheduleConfirmed(teachingNftId, msg.sender, teacherSide);
        _autoCloseTeachingValidIfReady(session);
    }

    function payTeachingSeat(uint64 teachingNftId, uint16 seatIndex) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        SparkTeachingTypes.TeachingSeat storage seat = _requireSeat(session, seatIndex);
        if (seat.student != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
        if (seat.paid) revert SparkDaoErrors.TeachingSeatAlreadyPaid();

        seat.paid = true;
        _safeTransferFrom(session.stableAsset, msg.sender, address(this), session.seatPriceUnits);
        _reserveVaultUnits(session.stableAsset, session.seatPriceUnits);

        emit TeachingSeatPaid(teachingNftId, seatIndex, msg.sender);
        _autoCloseTeachingValidIfReady(session);
    }

    function lockTeachingTeacherBond(uint64 teachingNftId) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
        if (session.teacherBondLocked) {
            revert SparkDaoErrors.TeachingCollateralAlreadyLocked();
        }

        session.teacherBondLocked = true;
        _safeTransferFrom(session.stableAsset, msg.sender, address(this), session.teacherBondUnits);
        _reserveVaultUnits(session.stableAsset, session.teacherBondUnits);

        emit TeachingTeacherBondLocked(teachingNftId, msg.sender);
        _autoCloseTeachingValidIfReady(session);
    }

    function withdrawUnmatchedTeachingSeatPayment(uint64 teachingNftId, uint16 seatIndex) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        SparkTeachingTypes.TeachingSeat storage seat = _requireSeat(session, seatIndex);
        if (seat.student != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
        if (!seat.paid) revert SparkDaoErrors.TeachingSeatNotPaid();
        if (session.teacherBondLocked || seat.customerFault) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }

        uint256 amount = session.seatPriceUnits;
        seat.paid = false;
        seat.attendanceConfirmed = false;
        _releaseVaultUnits(session.stableAsset, amount);
        _safeTransfer(session.stableAsset, msg.sender, amount);

        emit TeachingSeatPaymentWithdrawn(teachingNftId, seatIndex, msg.sender, amount);
    }

    function withdrawUnmatchedTeachingTeacherBond(uint64 teachingNftId) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
        if (!session.teacherBondLocked) revert SparkDaoErrors.TeachingCollateralNotLocked();
        if (_hasPaidSeat(session)) revert SparkDaoErrors.InvalidTeachingStatus();

        uint256 amount = session.teacherBondUnits;
        session.teacherBondLocked = false;
        session.teacherDeliveryConfirmed = false;
        _releaseVaultUnits(session.stableAsset, amount);
        _safeTransfer(session.stableAsset, msg.sender, amount);

        emit TeachingTeacherBondWithdrawn(teachingNftId, msg.sender, amount);
    }

    function confirmTeachingAttendance(uint64 teachingNftId, uint16 seatIndex) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        SparkTeachingTypes.TeachingSeat storage seat = _requireSeat(session, seatIndex);
        if (seat.student != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
        if (!seat.paid) revert SparkDaoErrors.TeachingSeatNotPaid();
        seat.attendanceConfirmed = true;
        _autoCloseTeachingValidIfReady(session);
    }

    function confirmTeachingDelivery(uint64 teachingNftId) external {
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
        session.teacherDeliveryConfirmed = true;
        _autoCloseTeachingValidIfReady(session);
    }

    function markTeachingCustomerFault(uint64 teachingNftId, uint16 seatIndex, uint8 reasonCode)
        external
        onlyCoordinator
    {
        _assertCustomerFaultTeachingResolutionCode(reasonCode);
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        SparkTeachingTypes.TeachingSeat storage seat = _requireSeat(session, seatIndex);
        if (!seat.paid) revert SparkDaoErrors.TeachingSeatNotPaid();
        if (seat.customerFault) revert SparkDaoErrors.TeachingSeatAlreadyMarked();
        seat.customerFault = true;
        emit TeachingSeatCustomerFault(teachingNftId, seatIndex);
    }

    function coordinatorCloseTeachingValid(uint64 teachingNftId, uint8 reasonCode)
        external
        onlyCoordinator
    {
        _assertValidTeachingResolutionCode(reasonCode);
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        _assertCoordinatorTeachingResolutionWindow(session);
        _settleTeaching(session, TEACHING_STATUS_CLOSED_VALID, reasonCode);
    }

    function coordinatorCloseTeachingTeacherFault(uint64 teachingNftId, uint8 reasonCode)
        external
        onlyCoordinator
    {
        _assertTeacherFaultTeachingResolutionCode(reasonCode);
        SparkTeachingTypes.TeachingSession storage session = _requireOpenTeaching(teachingNftId);
        _assertTeachingScheduleConfirmed(session);
        _assertCoordinatorTeachingResolutionWindow(session);
        _settleTeaching(session, TEACHING_STATUS_CLOSED_TEACHER_FAULT, reasonCode);
    }

    function claimTeachingSeatRefund(uint64 teachingNftId, uint16 seatIndex) external {
        SparkTeachingTypes.TeachingSession storage session = _requireClosedTeaching(teachingNftId);
        SparkTeachingTypes.TeachingSeat storage seat = _requireSeat(session, seatIndex);
        if (seat.student != msg.sender) revert SparkDaoErrors.UnauthorizedCustomer();
        if (seat.refundClaimed) revert SparkDaoErrors.TeachingRefundAlreadyClaimed();
        uint256 amount = seat.refundOwedUnits;
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();

        seat.refundClaimed = true;
        _releaseVaultUnits(session.stableAsset, amount);
        _safeTransfer(session.stableAsset, msg.sender, amount);

        emit TeachingSeatRefundClaimed(teachingNftId, seatIndex, msg.sender, amount);
    }

    function redeemTeachingTeacherPayout(uint64 teachingNftId) external {
        SparkTeachingTypes.TeachingSession storage session = _requireClosedTeaching(teachingNftId);
        if (session.teacher != msg.sender) revert SparkDaoErrors.UnauthorizedTeacher();
        if (session.teacherPayoutRedeemedAt != 0) {
            revert SparkDaoErrors.TeachingTeacherPayoutAlreadyRedeemed();
        }
        if (block.timestamp < _teachingRedeemableAt(session)) {
            revert SparkDaoErrors.TeachingNotRedeemableYet();
        }

        uint256 amount = session.teacherPayoutOwedUnits;
        session.teacherPayoutRedeemedAt = uint64(block.timestamp);
        if (amount != 0) {
            _releaseVaultUnits(session.stableAsset, amount);
            _safeTransfer(session.stableAsset, msg.sender, amount);
        }

        emit TeachingTeacherPayoutRedeemed(teachingNftId, msg.sender, amount);
    }

    function coordinatorSettleTeachingRemedialWage(uint64 teachingNftId) external onlyCoordinator {
        SparkTeachingTypes.TeachingSession storage session = _requireClosedTeaching(teachingNftId);
        if (session.status != TEACHING_STATUS_CLOSED_TEACHER_FAULT) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
        if (session.remedialWageSettledAt != 0) {
            revert SparkDaoErrors.TeachingRemedialWageAlreadySettled();
        }
        uint256 amount = session.remedialWageOwedUnits;
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();

        session.remedialWageSettledAt = uint64(block.timestamp);
        _releaseVaultUnits(session.stableAsset, amount);
        _safeTransfer(session.stableAsset, session.teacher, amount);

        emit TeachingRemedialWageSettled(teachingNftId, session.teacher, amount);
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

    function withdrawTeachingIdleFor(address stableAsset, uint256 amount) external onlyAuthority {
        if (stableAsset == address(0)) revert SparkDaoErrors.ZeroAddress();
        _assertContract(stableAsset);
        if (amount == 0) revert SparkDaoErrors.InvalidAmount();
        uint256 idleVaultUnits = _idleVaultUnits(stableAsset);
        if (amount > idleVaultUnits) revert SparkDaoErrors.VaultFundsReserved();
        _safeTransfer(stableAsset, msg.sender, amount);
    }

    function _settleTeaching(
        SparkTeachingTypes.TeachingSession storage session,
        uint8 finalStatus,
        uint8 reasonCode
    ) internal {
        if (!session.teacherBondLocked) {
            revert SparkDaoErrors.TeachingCollateralNotLocked();
        }
        if (block.timestamp < session.scheduledAt) {
            revert SparkDaoErrors.TeachingCompletionTooEarly();
        }

        uint256 paidSeatCount;
        uint256 teacherPayoutUnits;
        uint256 remedialWageUnits;
        uint256 refundUnits;
        uint256 requestedResearchUnits;
        uint256 serviceReserveUnits;
        uint256 seatCount = session.seats.length;
        for (uint256 i = 0; i < seatCount;) {
            SparkTeachingTypes.TeachingSeat storage seat = session.seats[i];
            if (seat.paid) {
                paidSeatCount += 1;
                if (seat.customerFault) {
                    (uint256 refund, uint256 teacherPayout, uint256 serviceReserve) =
                        _settleCustomerFaultSeat(session, seat);
                    refundUnits += refund;
                    teacherPayoutUnits += teacherPayout;
                    serviceReserveUnits += serviceReserve;
                } else if (finalStatus == TEACHING_STATUS_CLOSED_TEACHER_FAULT) {
                    (
                        uint256 refund,
                        uint256 remedialWage,
                        uint256 researchReward,
                        uint256 serviceReserve
                    ) = _settleTeacherFaultSeat(session, seat);
                    refundUnits += refund;
                    remedialWageUnits += remedialWage;
                    requestedResearchUnits += researchReward;
                    serviceReserveUnits += serviceReserve;
                } else {
                    teacherPayoutUnits += session.seatTeacherSalaryUnits;
                    requestedResearchUnits += session.seatResearchRewardUnits;
                    serviceReserveUnits += session.seatServiceReserveUnits;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (paidSeatCount == 0) revert SparkDaoErrors.InvalidAmount();

        uint256 distributedResearchUnits =
            _recordTeachingRewardsWithPool(session, requestedResearchUnits);
        serviceReserveUnits += requestedResearchUnits - distributedResearchUnits;
        uint256 reservedBeforeSettlement =
            (paidSeatCount * session.seatPriceUnits) + session.teacherBondUnits;
        uint256 owedUnits =
            refundUnits + teacherPayoutUnits + remedialWageUnits + distributedResearchUnits;
        uint256 releaseUnits = reservedBeforeSettlement - owedUnits;
        uint256 releasedServiceReserveUnits = releaseUnits - session.teacherBondUnits;

        session.status = finalStatus;
        session.closedAt = uint64(block.timestamp);
        session.teacherPayoutOwedUnits = teacherPayoutUnits;
        session.remedialWageOwedUnits = remedialWageUnits;
        session.refundOwedUnits = refundUnits;
        session.researchRewardUnits = distributedResearchUnits;
        session.serviceReserveUnits = releasedServiceReserveUnits;
        _releaseVaultUnits(session.stableAsset, releaseUnits);
        _safeTransfer(session.stableAsset, session.teacher, session.teacherBondUnits);

        emit TeachingResolved(
            session.teachingNftId,
            finalStatus,
            reasonCode,
            teacherPayoutUnits,
            remedialWageUnits,
            distributedResearchUnits,
            releasedServiceReserveUnits
        );
    }

    function _autoCloseTeachingValidIfReady(SparkTeachingTypes.TeachingSession storage session)
        internal
    {
        if (session.status != TEACHING_STATUS_OPEN) return;
        if (!_teachingScheduleConfirmed(session)) return;
        if (!session.teacherBondLocked || !session.teacherDeliveryConfirmed) return;
        if (block.timestamp < session.scheduledAt) return;
        if (!_teachingSettlementModulesReady(session)) return;
        if (!_hasPaidAttendanceMajority(session)) return;

        _settleTeaching(
            session, TEACHING_STATUS_CLOSED_VALID, TEACHING_RESOLUTION_SUCCESSFUL_COMPLETION
        );
    }

    function _assertTeachingScheduleConfirmed(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
    {
        if (!_teachingScheduleConfirmed(session)) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
    }

    function _teachingScheduleConfirmed(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (bool)
    {
        return session.teacherScheduleConfirmed && session.coordinatorScheduleConfirmed;
    }

    function _teachingSettlementModulesReady(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (bool)
    {
        if (session.researchShareBps == 0 || session.linkedResearchLinks.length == 0) {
            return true;
        }
        return teachingRewardDistributor != address(0);
    }

    function _assertCoordinatorTeachingResolutionWindow(
        SparkTeachingTypes.TeachingSession storage session
    ) internal view {
        if (!session.teacherBondLocked) {
            revert SparkDaoErrors.TeachingCollateralNotLocked();
        }
        if (block.timestamp < session.scheduledAt) {
            revert SparkDaoErrors.TeachingCompletionTooEarly();
        }
        if (block.timestamp < _teachingCoordinatorResolutionAt(session)) {
            revert SparkDaoErrors.TeachingCoordinatorTooEarly();
        }
    }

    function _teachingCoordinatorResolutionAt(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return session.scheduledAt + SparkDaoTypes.TEACHING_SECOND_ROUND_TIMEOUT_SECONDS;
    }

    function _teachingRedeemableAt(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (uint256)
    {
        return session.scheduledAt + SparkDaoTypes.TEACHING_REDEEM_DELAY_SECONDS;
    }

    function _hasPaidAttendanceMajority(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (bool)
    {
        uint256 confirmedPaidSeats;
        uint256 seatCount = session.seats.length;
        for (uint256 i = 0; i < seatCount;) {
            SparkTeachingTypes.TeachingSeat storage seat = session.seats[i];
            if (seat.paid && seat.attendanceConfirmed && !seat.customerFault) {
                confirmedPaidSeats += 1;
                if (confirmedPaidSeats * 2 > session.classSize) return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function _hasPaidSeat(SparkTeachingTypes.TeachingSession storage session)
        internal
        view
        returns (bool)
    {
        uint256 seatCount = session.seats.length;
        for (uint256 i = 0; i < seatCount;) {
            if (session.seats[i].paid) return true;
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function _assertValidTeachingResolutionCode(uint8 reasonCode) internal pure {
        if (
            reasonCode != TEACHING_RESOLUTION_SUCCESSFUL_COMPLETION
                && reasonCode != TEACHING_RESOLUTION_COORDINATOR_FORCED_VALID
                && reasonCode != TEACHING_RESOLUTION_MUTUAL_DISPUTE
                && reasonCode != TEACHING_RESOLUTION_EXTERNAL_EXCEPTION
        ) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _assertCustomerFaultTeachingResolutionCode(uint8 reasonCode) internal pure {
        if (reasonCode != TEACHING_RESOLUTION_CUSTOMER_FAULT) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _assertTeacherFaultTeachingResolutionCode(uint8 reasonCode) internal pure {
        if (reasonCode != TEACHING_RESOLUTION_TEACHER_FAULT) {
            revert SparkDaoErrors.InvalidTeachingResolutionCode();
        }
    }

    function _settleCustomerFaultSeat(
        SparkTeachingTypes.TeachingSession storage session,
        SparkTeachingTypes.TeachingSeat storage seat
    ) internal returns (uint256 refund, uint256 teacherPayout, uint256 serviceReserve) {
        refund = session.seatPriceUnits - session.seatPriceUnits / 2;
        teacherPayout = session.seatTeacherSalaryUnits / 2;
        seat.refundOwedUnits = refund;
        serviceReserve = session.seatPriceUnits - refund - teacherPayout;
    }

    function _settleTeacherFaultSeat(
        SparkTeachingTypes.TeachingSession storage session,
        SparkTeachingTypes.TeachingSeat storage seat
    )
        internal
        returns (
            uint256 refund,
            uint256 remedialWage,
            uint256 researchReward,
            uint256 serviceReserve
        )
    {
        refund = session.seatPriceUnits - session.seatPriceUnits / 2;
        remedialWage = session.seatTeacherSalaryUnits / 2;
        researchReward = session.seatTeacherFaultResearchRewardUnits;
        seat.refundOwedUnits = refund;
        serviceReserve = session.seatPriceUnits - refund - remedialWage - researchReward;
    }

    function _recordTeachingRewardsWithPool(
        SparkTeachingTypes.TeachingSession storage session,
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

        _clearSettlementResearchLayers(session);
        for (uint256 assetIndex = 0; assetIndex < linkCount;) {
            (uint64 assetId, uint16 assetWeightBps) =
                _unpackResearchLink(session.linkedResearchLinks[assetIndex]);
            (uint16 snapshotActiveLayer, uint256 assetDistributedUnits) = _recordTeachingAssetRewardPool(
                distributor,
                session.teachingNftId,
                session.stableAsset,
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

    function _recordTeachingAssetRewardPool(
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

    function _assertUniqueStudents(address[] calldata students) internal pure {
        uint256 studentCount = students.length;
        for (uint256 i = 0; i < studentCount;) {
            if (students[i] == address(0)) revert SparkDaoErrors.ZeroAddress();
            for (uint256 j = i + 1; j < studentCount;) {
                if (students[i] == students[j]) revert SparkDaoErrors.AccountMismatch();
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
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

    function _clearSettlementResearchLayers(SparkTeachingTypes.TeachingSession storage session)
        internal
    {
        session.settlementResearchActiveLayersPacked = 0;
        session.settlementResearchLayerCount = 0;
    }

    function _pushSettlementResearchLayer(
        SparkTeachingTypes.TeachingSession storage session,
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

    function _requireTeachingCourseType(uint64 courseTypeId)
        internal
        view
        returns (SparkTeachingTypes.TeachingCourseType storage courseType)
    {
        courseType = teachingCourseTypes[courseTypeId];
        if (!courseType.exists) revert SparkDaoErrors.InvalidCourseTypeId();
    }

    function _requireTeaching(uint64 teachingNftId)
        internal
        view
        returns (SparkTeachingTypes.TeachingSession storage session)
    {
        session = teachingSessions[teachingNftId];
        if (!session.exists) revert SparkDaoErrors.InvalidTeachingSessionId();
    }

    function _requireOpenTeaching(uint64 teachingNftId)
        internal
        view
        returns (SparkTeachingTypes.TeachingSession storage session)
    {
        session = _requireTeaching(teachingNftId);
        if (session.status != TEACHING_STATUS_OPEN) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
    }

    function _requireClosedTeaching(uint64 teachingNftId)
        internal
        view
        returns (SparkTeachingTypes.TeachingSession storage session)
    {
        session = _requireTeaching(teachingNftId);
        if (session.status == TEACHING_STATUS_OPEN) {
            revert SparkDaoErrors.InvalidTeachingStatus();
        }
    }

    function _requireTeachingSeat(uint64 teachingNftId, uint16 seatIndex)
        internal
        view
        returns (SparkTeachingTypes.TeachingSeat storage seat)
    {
        return _requireSeat(_requireTeaching(teachingNftId), seatIndex);
    }

    function _requireSeat(SparkTeachingTypes.TeachingSession storage session, uint16 seatIndex)
        internal
        view
        returns (SparkTeachingTypes.TeachingSeat storage seat)
    {
        if (seatIndex >= session.seats.length) revert SparkDaoErrors.InvalidTeachingSeat();
        seat = session.seats[seatIndex];
    }

    function _requireTeachingRewardDistributor() internal view returns (address distributor) {
        distributor = teachingRewardDistributor;
        if (distributor == address(0)) revert SparkDaoErrors.ZeroAddress();
    }
}
