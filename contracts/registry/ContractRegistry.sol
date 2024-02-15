// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@confluxfans/contracts/InternalContracts/InternalContractsHandler.sol";
import "../interfaces/ICentralRoleControl.sol";
import "../library/CfxAddress.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ContractRegistry is InternalContractsHandler {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    struct ContractInfo {
        address addr;
        string name;
    }

    string public constant contractName = "ContractRegistry";
    ICentralRoleControl private _centralAccess;
    EnumerableSet.UintSet private _nameSet;
    mapping(address => uint256) private _addressMapping;
    mapping(uint256 => ContractInfo) private _nameMapping;

    constructor(address roleControl_) {
        _centralAccess = ICentralRoleControl(roleControl_);
        uint256 id = hashString(contractName);
        _nameSet.add(id);
        _addressMapping[address(this)] = id;
        ContractInfo storage cInfo = _nameMapping[id];
        cInfo.addr = address(this);
        cInfo.name = contractName;
    }

    function registerSelf(string calldata contractName_) external ensureCallFromContractConstructor {
        require(_centralAccess.hasRole(_centralAccess.adminRoleName(), tx.origin), "ContractRegistry: need admin role");
        _register(msg.sender, contractName_);
    }

    function register(address contractAddr, string calldata contractName_) external ensureContract(contractAddr) {
        require(_centralAccess.hasRole(_centralAccess.adminRoleName(), msg.sender), "ContractRegistry: need admin role");
        _register(contractAddr, contractName_);
    }

    function _register(address contractAddr, string memory contractName_) private {
        uint256 id = hashString(contractName_);
        _nameSet.add(id);
        _addressMapping[contractAddr] = id;
        ContractInfo storage cInfo = _nameMapping[id];
        cInfo.addr = contractAddr;
        cInfo.name = contractName_;
    }

    function unregister(address contractAddr) external ensureContract(contractAddr) {
        require(_centralAccess.hasRole(_centralAccess.adminRoleName(), msg.sender), "ContractRegistry: need admin role");
        uint256 id = _addressMapping[contractAddr];
        require(id > 0, "ContractRegistry: contract not found");
        _nameSet.remove(id);
        delete _nameMapping[id];
        delete _addressMapping[contractAddr];
    }

    function unregister(string calldata contractName_) external {
        require(_centralAccess.hasRole(_centralAccess.adminRoleName(), msg.sender), "ContractRegistry: need admin role");
        uint256 id = hashString(contractName_);
        require(_nameSet.remove(id), "ContractRegistry: contract name not found");
        address contractAddr = _nameMapping[id].addr;
        delete _nameMapping[id];
        delete _addressMapping[contractAddr];
    }

    function isAddressRegisted(address contractAddr) external view returns (bool) {
        return _addressMapping[contractAddr] > 0;
    }

    function isNameRegisted(string calldata contractName_) external view returns (bool) {
        return _nameSet.contains(hashString(contractName_));
    }

    function getByAddress(address contractAddr) external view ensureContract(contractAddr) returns (string memory contractName_) {
        contractName_ = _nameMapping[_addressMapping[contractAddr]].name;
    }

    function getByNameHash(uint256 hashCode) external view returns (address) {
        require(_nameSet.contains(hashCode), string(abi.encodePacked("ContractRegistry: hash <", hashCode, "> not found")));
        return _nameMapping[hashCode].addr;
    }

    function getByName(string calldata contractName_) external view returns (address) {
        uint256 id = hashString(contractName_);
        require(_nameSet.contains(id), string(abi.encodePacked("ContractRegistry: contract <", contractName_, "> not found")));
        return _nameMapping[id].addr;
    }

    function getRegistedCount() external view returns (uint256 count) {
        count = _nameSet.length();
    }

    function getByIndex(uint256 index) external view returns (address addr, string memory name) {
        ContractInfo storage info = _nameMapping[_nameSet.at(index)];
        (addr, name) = (info.addr, info.name);
    }

    function hashString(string memory data) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(data)));
    }

    /**
     * @dev determine call is a contract or not on cfx
     */
    function isContract(address addr) public pure returns (bool) {
        return (uint160(addr) >> 159) > 0;
    }

    modifier ensureContract(address contractAddr) {
        require(contractAddr.isContract(), "ContractRegistry: need a contract address");
        _;
    }

    modifier ensureCallFromContractConstructor() {
        uint256 size;
        address account = msg.sender;
        assembly {
            size := extcodesize(account)
        }
        require(isContract(account) && size == 0 && tx.origin != account);
        _;
    }
}
