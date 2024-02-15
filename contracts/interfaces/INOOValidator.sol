// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INOOValidator {
    function tokenNonce(uint256 globalTokenId) external returns (uint256);

    function validateOwner(
        address account,
        uint256 tokenId,
        uint256 blockNumber,
        bytes calldata signature
    ) external;

    function validateOwner(address account, bytes calldata compositeData) external returns (uint256 globalTokenId);

    function validateOwnerBatch(address account, bytes calldata compositeData) external returns (uint256[] memory globalTokenIds);
}
