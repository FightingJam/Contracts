// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDrifterRegistery { 

    function initAsDrifter(
        uint256 tokenId,
        uint256 rarity,
        uint256 season
    ) external;

    function initAsDrifterBatch(
        uint256[] calldata tokenIds,
        uint256[] calldata rarites,
        uint256 season
    ) external;

    function drifterStats(uint256 tokenId) external view returns (uint256 compositeData);

    function updateDrifterBasic(
        uint256 tokenId,
        uint8 rank,
        uint8 class,
        uint32 remainingTime,
        uint32 totalTime
    ) external;

    function updateDrifterLevel(
        uint256 tokenId,
        uint8 level,
        uint16 strength,
        uint16 agility,
        uint16 intelligence,
        uint16 constitution,
        uint16 vitality,
        uint32 exp
    ) external;
}
