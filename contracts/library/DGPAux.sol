// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library DGPAux {
    uint256 constant uint16mask = (2**16) - 1;

    function compose(uint16 levelMax, uint16 levelInit) internal pure returns (uint256) {
        return (uint256(levelMax) << 16) | levelInit;
    }

    function decompose(uint256 input) internal pure returns (uint16 levelMax, uint16 levelInit) {
        levelMax = uint16(input >> 16);
        levelInit = uint16(input);
    }

    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }
}
