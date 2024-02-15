// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract MinterGuard is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    EnumerableSet.AddressSet private _minters;

    function addMinter(address minter) external onlyOwner {
        require(_minters.add(minter), "already a minter");
    }

    function removeMinter(address minter) external onlyOwner {
        require(_minters.remove(minter), "not a minter");
    }

    function minters() external view returns (address[] memory minters_) {
        uint256 count = _minters.length();
        minters_ = new address[](count);
        for (uint256 index = 0; index < count; ++index) minters_[index] = _minters.at(index);
    }
 
    modifier onlyMinter() { 
        require(_minters.contains(msg.sender), "require minter");
        _;
    }
}
