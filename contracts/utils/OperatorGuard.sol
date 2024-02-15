// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract OperatorGuard is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _operators;

    function addOperator(address operator) external onlyOwner {
        require(_operators.add(operator), "already an operator");
    }

    function removeOperator(address operator) external onlyOwner {
        require(_operators.remove(operator), "not an operator");
    }

    function operators() external view returns (address[] memory operators_) {
        uint256 count = _operators.length();
        operators_ = new address[](count);
        for (uint256 index = 0; index < count; ++index) operators_[index] = _operators.at(index);
    }

    modifier onlyOperator() {
        require(_operators.contains(msg.sender), "require registred operator");
        _;
    }
}
