// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenPoolTracker {
    function setTrace(
        address tokenSource,
        uint96 poolId,
        uint256 tokenId
    ) external;

    function setTraceBatch(
        address tokenSource,
        uint96 poolId,
        uint256[] calldata tokenIds
    ) external;

    function clearTrace(address tokenSource, uint256 tokenId) external;

    function clearTraceBatch(address tokenSource, uint256[] calldata tokenIds) external;

    function getTrace(address tokenSource, uint256 tokenId) external view returns (address contractAddress, uint256 poolId);

    function getTraceBatch(address tokenSource, uint256[] calldata tokenIds) external view returns (address[] memory contractAddress, uint256[] memory poolId);
}
