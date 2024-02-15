// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingBase {
    function estimateAndCheckAvailble(
        uint256 tokenId,
        uint256 minRarity,
        uint256 minRank
    ) external view returns (uint256 agPoint, uint256 dgtPoint);
}
