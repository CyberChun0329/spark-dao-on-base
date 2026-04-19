// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {SparkDaoErrors} from "./SparkDaoErrors.sol";
import {SparkDaoTypes} from "./SparkDaoTypes.sol";

library SparkMath {
    function computeDecaySplit(
        uint16 layerShareBps,
        uint16 decayRateBps,
        uint64 decaySteps
    ) internal pure returns (uint16 retainedShareBps, uint16 releasedShareBps) {
        if (decayRateBps == 0 || decayRateBps > SparkDaoTypes.BASIS_POINTS_DENOMINATOR) {
            revert SparkDaoErrors.InvalidDecayRate();
        }

        uint256 retained = layerShareBps;
        uint256 base = SparkDaoTypes.BASIS_POINTS_DENOMINATOR - decayRateBps;

        for (uint64 i = 0; i < decaySteps; ++i) {
            retained = (retained * base) / SparkDaoTypes.BASIS_POINTS_DENOMINATOR;
        }

        // forge-lint: disable-next-line(unsafe-typecast)
        retainedShareBps = uint16(retained);
        releasedShareBps = layerShareBps - retainedShareBps;
    }

    function computeDecayStepCountFromNow(
        uint64 nowTs,
        uint64 decayStartAt,
        uint64 decayPeriodSeconds
    ) internal pure returns (uint64) {
        if (decayPeriodSeconds == 0) {
            revert SparkDaoErrors.InvalidDecayPeriod();
        }
        if (nowTs < decayStartAt) {
            revert SparkDaoErrors.DecayNotStarted();
        }

        return ((nowTs - decayStartAt) / decayPeriodSeconds) + 1;
    }
}
