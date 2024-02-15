// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDGPRegistry {
    function createProject(string calldata name) external;

    function updateProject(uint256 projectId, string calldata name) external;

    function transferProjectOwner(uint256 projectId, address newOwner) external;

    function addProjectOperator(uint256 projectId, address operator) external;

    function removeProjectOperator(uint256 projectId, address operator) external;

    function projectOperators(uint256 projectId) external view returns (address[] memory operators);

    function setParent(
        uint256 projectId,
        address target,
        address parent
    ) external;
    
    function ancestor(uint256 projectId, address target) external view returns (address _ancestor);

    function ancestors(
        uint256 projectId,
        address target,
        uint256 level
    ) external view returns (uint256 count, address[] memory _ancestors);
    
}
