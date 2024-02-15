// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICharacterUpdatedHandler {
    function tokenUpdated(
        uint256 pId,
        address account,
        uint256 globalTokenId
    ) external;
}
