// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCPRegistry {
    function initTokenPropertiesBatch(address tokenAddress, uint256[] calldata tokenIds) external returns (uint256[] memory randomizers);

    function fetchTokenProperties(address tokenAddress, uint256 tokenId)
        external
        view
        returns (
            uint256 randomizer,
            uint96 id,
            uint128 birth,
            uint16 chainId
        );

    function fetchOrInitTokenProperties(address tokenAddress, uint256 tokenId)
        external
        returns (
            uint256 randomizer,
            uint96 id,
            uint128 birth,
            uint16 chainId
        );

    function getAdditionalProperty(
        address tokenAddress,
        uint256 tokenId,
        address provider,
        bytes32 key
    ) external view returns (bytes memory data);

    function setAdditionalProperty(
        address tokenAddress,
        uint256 tokenId,
        bytes32 key,
        bytes calldata data
    ) external;

    function setAdditionalPropertyBatch(
        address tokenAddress,
        uint256[] calldata tokenIds,
        bytes32 key,
        bytes[] calldata data
    ) external;
}
