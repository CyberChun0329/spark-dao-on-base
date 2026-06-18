// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoErrors } from "./SparkDaoErrors.sol";
import { SparkDaoTypes } from "./SparkDaoTypes.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

abstract contract SparkDaoConfig {
    SparkDaoTypes.DaoState internal daoState;
    mapping(address stableAsset => uint256 reservedUnits) internal reservedUnitsByStableAsset;

    event DaoInitialized(
        address indexed authority,
        address indexed coordinator,
        address indexed treasury,
        address stableAsset,
        uint64 rewardUnlockSeconds,
        uint64 buybackWaitSeconds
    );
    event CoordinatorUpdated(address indexed previousCoordinator, address indexed newCoordinator);
    event AuthorityUpdated(address indexed previousAuthority, address indexed newAuthority);
    event TreasuryUpdated(address indexed previousTreasury, address indexed newTreasury);
    event StableAssetUpdated(address indexed previousStableAsset, address indexed newStableAsset);
    event RewardUnlockUpdated(uint64 previousValue, uint64 newValue);
    event BuybackWaitUpdated(uint64 previousValue, uint64 newValue);

    constructor(
        address authority_,
        address coordinator_,
        address treasury_,
        address stableAsset_,
        uint64 rewardUnlockSeconds_,
        uint64 buybackWaitSeconds_
    ) {
        if (
            authority_ == address(0) || coordinator_ == address(0) || treasury_ == address(0)
                || stableAsset_ == address(0)
        ) {
            revert SparkDaoErrors.ZeroAddress();
        }
        _assertContract(stableAsset_);

        daoState = SparkDaoTypes.DaoState({
            authority: authority_,
            treasury: treasury_,
            coordinator: coordinator_,
            stableAsset: stableAsset_,
            nextAssetId: 0,
            rewardUnlockSeconds: rewardUnlockSeconds_,
            buybackWaitSeconds: buybackWaitSeconds_,
            nextCourseTypeId: 0,
            nextTeachingNftId: 0
        });

        emit DaoInitialized(
            authority_,
            coordinator_,
            treasury_,
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

    function getVaultReservedUnits(address stableAsset) external view returns (uint256) {
        if (stableAsset == address(0)) revert SparkDaoErrors.ZeroAddress();
        return reservedUnitsByStableAsset[stableAsset];
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

    function updateTreasury(address newTreasury) external onlyAuthority {
        if (newTreasury == address(0)) revert SparkDaoErrors.ZeroAddress();
        address previousTreasury = daoState.treasury;
        daoState.treasury = newTreasury;
        emit TreasuryUpdated(previousTreasury, newTreasury);
    }

    function updateStableAsset(address newStableAsset) external onlyAuthority {
        if (newStableAsset == address(0)) revert SparkDaoErrors.ZeroAddress();
        _assertContract(newStableAsset);
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

    function _reserveVaultUnits(address stableAsset, uint256 amount) internal {
        if (amount == 0) return;
        reservedUnitsByStableAsset[stableAsset] += amount;
    }

    function _releaseVaultUnits(address stableAsset, uint256 amount) internal {
        if (amount == 0) return;
        reservedUnitsByStableAsset[stableAsset] -= amount;
    }

    function _idleVaultUnits(address stableAsset) internal view returns (uint256) {
        return
            IERC20(stableAsset).balanceOf(address(this)) - reservedUnitsByStableAsset[stableAsset];
    }

    function _assertContract(address target) internal view {
        if (target.code.length == 0) revert SparkDaoErrors.InvalidContractAddress();
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        _callToken(token, abi.encodeCall(IERC20.transfer, (to, amount)));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        _callToken(token, abi.encodeCall(IERC20.transferFrom, (from, to, amount)));
    }

    /// @dev Minimal ERC-20 call wrapper for the configured stable assets.
    /// Stable assets are expected to move exactly the requested units and must not
    /// charge transfer fees, rebase balances, or invoke transfer callbacks.
    function _callToken(address token, bytes memory callData) private {
        if (token == address(0)) revert SparkDaoErrors.ZeroAddress();
        (bool ok, bytes memory returnData) = token.call(callData);
        if (!ok || (returnData.length != 0 && !abi.decode(returnData, (bool)))) {
            revert SparkDaoErrors.TokenTransferFailed();
        }
    }
}
