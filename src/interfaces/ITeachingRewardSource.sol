// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

interface ITeachingRewardSource {
    function getResearchPosition(uint64 assetId, uint64 positionId)
        external
        view
        returns (SparkDaoTypes.ResearchPosition memory);

    function settleTeachingRewardClaim(
        address stableAsset,
        address recipient,
        uint64 assetId,
        uint64 positionId,
        uint256 claimAmount,
        uint256 dustUnits
    ) external;
}
