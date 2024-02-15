// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDrifterUpdatedHandler {
    function isTokenOwner(
        uint256 pId,
        address account,
        uint256 tokenId
    ) external view returns (bool);

    function tokenUpdate(
        uint256 pId,
        address account,
        uint256 tokenId
    ) external;
}
