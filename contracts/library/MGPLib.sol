// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MGPLib {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    function toArray(EnumerableSet.AddressSet storage addressSet) internal view returns (address[] memory content) {
        uint256 count = addressSet.length();
        content = new address[](count);
        for (uint256 index = 0; index < count; ++index) content[index] = addressSet.at(index);
    }

    function toArray(EnumerableSet.UintSet storage uintSet) internal view returns (uint256[] memory content) {
        uint256 count = uintSet.length();
        content = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) content[index] = uintSet.at(index);
    }

    function toBytes(uint256 x) internal pure returns (bytes memory b) {
        b = new bytes(32);
        assembly {
            mstore(add(b, 32), x)
        }
    }

    function decodeDrifter(uint256 compositeData)
        internal
        pure
        returns (
            uint8 rarity,
            uint8 rank,
            uint8 level,
            uint8 class,
            uint16 strength,
            uint16 agility,
            uint16 intelligence,
            uint16 constitution,
            uint16 vitality,
            uint32 exp,
            uint32 remainingTime,
            uint32 totalTime
        )
    {
        rarity = uint8(compositeData);
        rank = uint8(compositeData >> 8);
        level = uint8(compositeData >> 16);
        class = uint8(compositeData >> 24);
        strength = uint16(compositeData >> 32);
        agility = uint16(compositeData >> 48);
        intelligence = uint16(compositeData >> 64);
        constitution = uint16(compositeData >> 80);
        vitality = uint16(compositeData >> 96);
        exp = uint32(compositeData >> 112);
        remainingTime = uint32(compositeData >> 144);
        totalTime = uint32(compositeData >> 176);
    }

    function decodeDrifterBasic(uint256 compositeData)
        internal
        pure
        returns (
            uint8 rarity,
            uint8 rank,
            uint8 class,
            uint32 remainingTime,
            uint32 totalTime
        )
    {
        rarity = uint8(compositeData);
        rank = uint8(compositeData >> 8);
        class = uint8(compositeData >> 24);
        remainingTime = uint32(compositeData >> 144);
        totalTime = uint32(compositeData >> 176);
    }

    function decodeDrifterLevel(uint256 compositeData)
        internal
        pure
        returns (
            uint8 rarity,
            uint8 rank,
            uint8 level,
            uint8 class,
            uint16 strength,
            uint16 agility,
            uint16 intelligence,
            uint16 constitution,
            uint16 vitality,
            uint32 exp
        )
    {
        rarity = uint8(compositeData);
        rank = uint8(compositeData >> 8);
        level = uint8(compositeData >> 16);
        class = uint8(compositeData >> 24);
        strength = uint16(compositeData >> 32);
        agility = uint16(compositeData >> 48);
        intelligence = uint16(compositeData >> 64);
        constitution = uint16(compositeData >> 80);
        vitality = uint16(compositeData >> 96);
        exp = uint32(compositeData >> 112);
    }

    function hashTokenId(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(chainPrefix, nftContract, tokenId)));
    }
}
