// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenPoolTrackerV2 {
    function setTrace(uint256 globalTokenId, uint96 poolId) external;

    function setTraceBatch(uint256[] calldata globalTokenIds, uint96 poolId) external;

    function clearTrace(uint256 globalTokenId) external;

    function clearTraceBatch(uint256[] calldata globalTokenIds) external;

    function getTrace(uint256 globalTokenId) external view returns (address contractAddress, uint256 poolId);

    function getTraceBatch(uint256[] calldata globalTokenIds) external view returns (address[] memory contractAddress, uint256[] memory poolId);
}
