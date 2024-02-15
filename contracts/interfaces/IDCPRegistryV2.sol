// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCPRegistryV2 {
    function initTokenPropertiesBatch(
        string calldata chainPrefix,
        address tokenAddress,
        uint256[] calldata tokenIds
    ) external returns (uint256[] memory randomizers, uint256[] memory globalTokenIds);

    function fetchTokenProperties(
        string calldata chainPrefix,
        address tokenAddress,
        uint256 tokenId
    ) external view returns (uint256 randomizer, uint256 globalTokenId);

    function fetchTokenProperties(uint256 globalTokenId) external view returns (uint256 randomizer);

    function fetchOrInitTokenProperties(
        string calldata chainPrefix,
        address tokenAddress,
        uint256 tokenId
    ) external returns (uint256 randomizer, uint256 globalTokenId);

    function getAdditionalProperty(
        uint256 globalTokenId,
        address provider,
        bytes32 key
    ) external view returns (bytes memory data);

    function setAdditionalProperty(
        uint256 globalTokenId,
        bytes32 key,
        bytes calldata data
    ) external;

    function setAdditionalPropertyBatch(
        uint256[] calldata globalTokenIds,
        bytes32 key,
        bytes[] calldata data
    ) external;

    function hasAdditionalProperty(
        uint256 globalTokenId,
        address provider,
        bytes32 key
    ) external view returns (bool);
}
