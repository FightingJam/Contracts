// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGrowthHackingRegistry {
    function getParent(address target) external view returns (address parent);

    function getParents(address target, uint256 level) external view returns (uint256 count, address[] memory parents);

    function setParent(
        address account,
        address parent,
        bytes calldata signature
    ) external;
}
