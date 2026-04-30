// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SparkDaoErrors} from "./SparkDaoErrors.sol";
import {SparkDaoTypes} from "./SparkDaoTypes.sol";

abstract contract SparkDaoConfig {
    SparkDaoTypes.DaoState internal daoState;

    event DaoInitialized(
        address indexed authority,
        address indexed coordinator,
        address indexed stableAsset,
        uint64 rewardUnlockSeconds,
        uint64 buybackWaitSeconds
    );
    event CoordinatorUpdated(address indexed previousCoordinator, address indexed newCoordinator);
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
    event StableAssetUpdated(address indexed previousStableAsset, address indexed newStableAsset);
    event RewardUnlockUpdated(uint64 previousValue, uint64 newValue);
    event BuybackWaitUpdated(uint64 previousValue, uint64 newValue);

    constructor(
        address authority_,
        address coordinator_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_
    ) {
        if (authority_ == address(0) || coordinator_ == address(0) || stableAsset_ == address(0)) {
            revert SparkDaoErrors.ZeroAddress();
        }

        daoState = SparkDaoTypes.DaoState({
            authority: authority_,
            coordinator: coordinator_,
            stableAsset: stableAsset_,
            nextAssetId: 0,
            rewardUnlockSeconds: rewardUnlockSeconds_,
            buybackWaitSeconds: buybackWaitSeconds_,
            nextCourseTypeId: 0,
            nextTeachingNftId: 0,
            vaultReservedUnits: 0
        });

        emit DaoInitialized(
            authority_,
            coordinator_,
            stableAsset_,
            rewardUnlockSeconds_,
            buybackWaitSeconds_
        );
    }

    modifier onlyAuthority() {
        _onlyAuthority();
        _;
    }

    modifier onlyCoordinator() {
        _onlyCoordinator();
        _;
    }

    function getDaoState() external view returns (SparkDaoTypes.DaoState memory) {
        return daoState;
    }

    function updateCoordinator(address newCoordinator) external onlyAuthority {
        if (newCoordinator == address(0)) revert SparkDaoErrors.ZeroAddress();
        address previousCoordinator = daoState.coordinator;
        daoState.coordinator = newCoordinator;
        emit CoordinatorUpdated(previousCoordinator, newCoordinator);
    }

    function updateAuthority(address newAuthority) external onlyAuthority {
        if (newAuthority == address(0)) revert SparkDaoErrors.ZeroAddress();
        address previousAuthority = daoState.authority;
        daoState.authority = newAuthority;
        emit AuthorityUpdated(previousAuthority, newAuthority);
    }

    function updateStableAsset(address newStableAsset) external onlyAuthority {
        if (newStableAsset == address(0)) revert SparkDaoErrors.ZeroAddress();
        address previousStableAsset = daoState.stableAsset;
        daoState.stableAsset = newStableAsset;
        emit StableAssetUpdated(previousStableAsset, newStableAsset);
    }

    function updateRewardUnlockSeconds(uint64 newRewardUnlockSeconds) external onlyAuthority {
        uint64 previousValue = daoState.rewardUnlockSeconds;
        daoState.rewardUnlockSeconds = newRewardUnlockSeconds;
        emit RewardUnlockUpdated(previousValue, newRewardUnlockSeconds);
    }

    function updateBuybackWaitSeconds(uint64 newBuybackWaitSeconds) external onlyAuthority {
        uint64 previousValue = daoState.buybackWaitSeconds;
        daoState.buybackWaitSeconds = newBuybackWaitSeconds;
        emit BuybackWaitUpdated(previousValue, newBuybackWaitSeconds);
    }

    function _onlyAuthority() internal view {
        if (msg.sender != daoState.authority) revert SparkDaoErrors.UnauthorizedAuthority();
    }

    function _onlyCoordinator() internal view {
        if (msg.sender != daoState.coordinator) revert SparkDaoErrors.UnauthorizedCoordinator();
    }
}
