// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDrifterOperations {
    function rankData(uint256 rank)
        external
        view
        returns (
            uint16 incomeMultiplier,
            uint32 additionRT,
            uint16 dropRateBounus,
            uint32 staminaChargeBlocks
        );
}
