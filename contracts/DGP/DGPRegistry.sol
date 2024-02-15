// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../library/MGPLib.sol";
import "../interfaces/IDGPRegistry.sol";

contract DGPRegistry is IDGPRegistry {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using MGPLib for EnumerableSet.AddressSet;

    event ProjectCreated(address indexed owner);
    event AddOperator(uint256 indexed projectId, address indexed operator);
    event RemoveOperator(uint256 indexed projectId, address indexed operator);
    event TransferProjectOwner(uint256 indexed projectId, address indexed newOwner);
    event BeParent(uint256 indexed projectId, address target, address parent);

    struct Project {
        string name;
        EnumerableSet.AddressSet operators;
    }

    address public constant addressZero = address(0);

    uint256 private _projectCounter;
    // account => projectIds;
    mapping(address => EnumerableSet.UintSet) private _ownedProjects;
    // project id => project
    mapping(uint256 => Project) private _projects;
    // project id => address => parent
    mapping(uint256 => mapping(address => address)) private _ancestorRegistry;
    mapping(uint256 => mapping(address => EnumerableSet.AddressSet)) private _childrenRegistry;

    constructor() {}

    /**
     * @dev Create a project
     * @param name name of the project
     */
    function createProject(string calldata name) external override {
        // get next project Id
        uint256 projectId = _projectCounter;
        // add to user's owned project id
        _ownedProjects[msg.sender].add(projectId);
        // set project name
        _projects[projectId].name = name;
        // update project counter
        _projectCounter = projectId + 1;
        emit ProjectCreated(msg.sender);
    }

    /**
     * @dev Update the name of a owned project
     * @param projectId the id of the project
     * @param name new name of the project
     */
    function updateProject(uint256 projectId, string calldata name) external override onlyProjectOwner(projectId) {
        _projects[projectId].name = name;
    }

    /**
     * @dev Transfer owner ship of a project
     * @param projectId the id of the project
     * @param newOwner new owner of the project
     */
    function transferProjectOwner(uint256 projectId, address newOwner) external override onlyProjectOwner(projectId) {
        // remove project form current owner
        _ownedProjects[msg.sender].remove(projectId);
        // add project to new owner
        _ownedProjects[newOwner].add(projectId);
        emit TransferProjectOwner(projectId, newOwner);
    }

    /**
     * @dev Add an operator to a owned project, operator can create or update parent relationship
     * @param projectId the id of the project
     * @param operator new operator for the project
     */
    function addProjectOperator(uint256 projectId, address operator) external override onlyProjectOwner(projectId) {
        require(_projects[projectId].operators.add(operator), "already an operator");
        emit AddOperator(projectId, operator);
    }

    /**
     * @dev Remove an operator from a owned project
     * @param projectId the id of the project
     * @param operator the operator to be removed
     */
    function removeProjectOperator(uint256 projectId, address operator) external override onlyProjectOwner(projectId) {
        require(_projects[projectId].operators.remove(operator), "not an operator");
        emit RemoveOperator(projectId, operator);
    }

    /**
     * @dev Get operators of a project
     * @param projectId the id of the project
     * @return operators
     */
    function projectOperators(uint256 projectId) external view override returns (address[] memory operators) {
        operators = _projects[projectId].operators.toArray();
    }

    /**
     * @dev Get the name of a project
     * @param projectId the id of the project
     * @return name of the project
     */
    function projectName(uint256 projectId) external view returns (string memory name) {
        name = _projects[projectId].name;
    }

    /**
     * @dev Set relationship through operators
     * @param projectId the id of the project
     * @param target the one will be set parent
     * @param parent parent of 'target'
     */
    function setParent(
        uint256 projectId,
        address target,
        address parent
    ) external override onlyProjectOperator(projectId) {
        // get old parent
        address oldParent = _ancestorRegistry[projectId][target];
        // if old parent is not 0x0, means it has parent before.
        // remove target from parent at first
        if (oldParent != addressZero) _childrenRegistry[projectId][oldParent].remove(target);
        // set new parent
        _ancestorRegistry[projectId][target] = parent;
        // add to parent's children
        _childrenRegistry[projectId][parent].add(target);
        emit BeParent(projectId, target, parent);
    }

    /**
     * @dev Get children count of a account
     * @param projectId the id of the project
     * @param target the target to query
     */
    function childrenCount(uint256 projectId, address target) public view returns (uint256 count) {
        count = _childrenRegistry[projectId][target].length();
    }

    /**
     * @dev Get children of a account
     * @param projectId the id of the project
     * @param target the target to query
     * @param offset the offset to query
     * @param limit the limit to query
     */
    function children(
        uint256 projectId,
        address target,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256 count, address[] memory children_) {
        EnumerableSet.AddressSet storage _children = _childrenRegistry[projectId][target];
        count = childrenCount(projectId, target);
        if (offset + limit > count) limit = count - offset;
        children_ = new address[](limit);
        for (uint256 index = 0; index < limit; ++index) children_[index] = _children.at(offset + index);
    }

    /**
     * @dev Get count of the project owned
     * @param target the target to query
     */
    function projectCount(address target) public view returns (uint256 count) {
        count = _ownedProjects[target].length();
    }

    /**
     * @dev Get owned id of one user
     * @param target the target to query
     * @param offset the offset to query
     * @param limit the limit to query
     */
    function projectIds(
        address target,
        uint256 offset,
        uint256 limit
    ) external view returns (uint256 count, uint256[] memory projectIds_) {
        count = projectCount(target);
        if (offset + limit > count) limit = count - offset;
        projectIds_ = new uint256[](limit);
        for (uint256 index = 0; index < limit; ++index) projectIds_[index] = _ownedProjects[target].at(offset + index);
    }

    /**
     * @dev Get direct ancestor of one account(parent)
     * @param projectId the id of the project
     * @param target the target to query
     */
    function ancestor(uint256 projectId, address target) external view override returns (address _ancestor) {
        _ancestor = _ancestorRegistry[projectId][target];
    }

    /**
     * @dev Get multi level ancestor of one account
     * @param projectId the id of the project
     * @param target the target to query
     * @param level the levels to query
     */
    function ancestors(
        uint256 projectId,
        address target,
        uint256 level
    ) external view override returns (uint256 count, address[] memory _ancestors) {
        address parent = target;
        _ancestors = new address[](level);
        for (count = 0; count < level; ++count) {
            parent = _ancestorRegistry[projectId][parent];
            if (parent == addressZero) break;
            _ancestors[count] = parent;
        }
    }

    modifier onlyProjectOwner(uint256 projectId) {
        require(_ownedProjects[msg.sender].contains(projectId), "require owner");
        _;
    }
    modifier onlyProjectOperator(uint256 projectId) {
        require(_projects[projectId].operators.contains(msg.sender), "require operator");
        _;
    }
}
