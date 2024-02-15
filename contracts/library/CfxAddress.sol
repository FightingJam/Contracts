// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library CfxAddress {
    /**
     * @dev Returns the largest of two numbers.
     */
    function isContract(address addr) internal pure returns (bool) {
        return (uint256(uint160(addr)) >> 159) == 1;
    }
}
