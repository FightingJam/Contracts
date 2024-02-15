// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library VersusAux {
    uint256 constant uint16mask = (2**16) - 1;

    function encodeRoundData(
        uint96 roundFee,
        uint96 p0Fee,
        uint96 p0Mining,
        uint96 p1Fee,
        uint96 p1Mining,
        uint256 roundBase,
        uint256 encodedResult
    ) internal pure returns (bytes memory) {
        return abi.encode(roundFee, p0Fee, p0Mining, p1Fee, p1Mining, roundBase, encodedResult);
    }

    function decodeRoundData(bytes calldata encodedData)
        internal
        pure
        returns (
            uint256 roundFee,
            uint256 p0Fee,
            uint256 p0Mining,
            uint256 p1Fee,
            uint256 p1Mining,
            uint256 roundBase,
            uint256 encodedResult
        )
    {
        (roundFee, p0Fee, p0Mining, p1Fee, p1Mining, roundBase, encodedResult) = abi.decode(encodedData, (uint96, uint96, uint96, uint96, uint96, uint256, uint256));
    }

    function makeArray(address source, uint256 count) internal pure returns (address[] memory results) {
        results = new address[](count);
        for (uint256 index = 0; index < count; ++index) results[index] = source;
    }

    function makeArray(uint256 source, uint256 count) internal pure returns (uint256[] memory results) {
        results = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) results[index] = source;
    }

    function compose(uint16 levelMax, uint16 levelInit) internal pure returns (uint256) {
        return (uint256(levelMax) << 16) | levelInit;
    }

    function decompose(uint256 input) internal pure returns (uint16 levelMax, uint16 levelInit) {
        levelMax = uint16(input >> 16);
        levelInit = uint16(input);
    }

    function composeWuxing(
        uint256 metal, //16
        uint256 wood, //16
        uint256 water, //16
        uint256 fire, //16
        uint256 earth, //16
        uint256 souls, //8
        uint256 eqSouls //8
    ) internal pure returns (uint256 compositeData) {
        compositeData |= metal << 0;
        compositeData |= wood << 16;
        compositeData |= water << 32;
        compositeData |= fire << 48;
        compositeData |= earth << 64;
        compositeData |= souls << 80;
        compositeData |= eqSouls << 88;
    }

    function decomposeWuxing(uint256 compositeData)
        internal
        pure
        returns (
            uint256 metal,
            uint256 wood,
            uint256 water,
            uint256 fire,
            uint256 earth,
            uint256 souls,
            uint256 eqSouls
        )
    {
        metal = uint16(compositeData >> 0);
        wood = uint16(compositeData >> 16);
        water = uint16(compositeData >> 32);
        fire = uint16(compositeData >> 48);
        earth = uint16(compositeData >> 64);
        souls = uint8(compositeData >> 80);
        eqSouls = uint8(compositeData >> 88);
    }

    function encode4Uint64(
        uint256 u0,
        uint256 u1,
        uint256 u2,
        uint256 u3
    ) internal pure returns (uint256 encoded) {
        encoded |= (u0);
        encoded |= (u1 << 64);
        encoded |= (u2 << 128);
        encoded |= (u3 << 192);
    }

    function decode4Uint64(uint256 encoded)
        internal
        pure
        returns (
            uint256 u0,
            uint256 u1,
            uint256 u2,
            uint256 u3
        )
    {
        u0 = uint64(encoded);
        u1 = uint64(encoded >> 64);
        u2 = uint64(encoded >> 128);
        u3 = uint64(encoded >> 192);
    }

    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }
}
