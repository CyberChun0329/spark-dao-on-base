// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Registry callback surface used by the teaching reward distributor.
/// @dev Implementations should accept calls only from their configured distributor.
/// The callback releases reserve units, records research claim totals, and transfers
/// the frozen stable asset for non-zero claim amounts.
interface ITeachingRewardSource {
    function settleTeachingRewardClaim(
        address stableAsset,
        address recipient,
        uint64 assetId,
        uint64 positionId,
        uint256 claimAmount,
        uint256 dustUnits
    ) external;
}
