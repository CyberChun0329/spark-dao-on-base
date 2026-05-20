// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

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
