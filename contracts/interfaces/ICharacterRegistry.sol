// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICharacterRegistry {
    function initAsCharacter(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId,
        uint256 rarity,
        uint32 totalTime
    ) external returns (uint256 randomizer, uint256 globalTokenId);

    function initAsCharacterBatch(
        string calldata chainPrefix,
        address nftContract,
        uint256[] calldata tokenIds,
        uint256[] calldata rarities,
        uint32 totalTime
    ) external returns (uint256[] memory randomizers, uint256[] memory globalTokenIds);

    function characterStats(uint256 globalTokenId) external view returns (uint256 compositeData);

    function isTokenRegistred(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId
    ) external view returns (bool);

    function updateCharacterBasic(
        uint256 globalTokenId,
        uint8 rank,
        uint8 class,
        uint32 remainingTime,
        uint32 totalTime
    ) external;

    function updateCharacterLevel(
        uint256 globalTokenId,
        uint8 level,
        uint16 strength,
        uint16 agility,
        uint16 intelligence,
        uint16 constitution,
        uint16 vitality,
        uint32 exp
    ) external;
}
