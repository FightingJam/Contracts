// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVersusImpl {
    function versus(
        address account,
        uint256 fighterId,
        uint256 opponentId
    ) external returns (uint256 roundRandomBase, bool isWin);
}
