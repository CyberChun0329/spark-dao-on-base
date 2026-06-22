// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { SparkDaoTypes } from "../SparkDaoTypes.sol";

interface IResearchRegistryForTeaching {
    function getResearchPosition(uint64 assetId, uint64 positionId)
        external
        view
        returns (SparkDaoTypes.ResearchPosition memory);

    function requireTeachingResearchAssetReady(uint64 assetId, uint16 researchShareBps)
        external
        view;

    function getTeachingResearchSnapshot(uint64 assetId, uint64 snapshotAt)
        external
        view
        returns (uint16 snapshotActiveLayer, uint16 totalEffectiveShareBps);

    function recordTeachingRewardClaim(uint64 assetId, uint64 positionId, uint256 claimAmount)
        external;
}
