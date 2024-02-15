// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EncodeTest {
    uint256 public sum;

    DrifterInfo[] drifters;

    struct DrifterInfo {
        uint8 rarity;
        uint8 ascension;
        uint16 strength;
        uint16 dexterity;
        uint16 intelligent;
        uint16 constitution;
        uint16 speed;
    }

    function addAndSave(uint256 a) external returns (uint256, uint256) {
        uint256 oldSum = sum;
        sum = oldSum + a;
        return (oldSum, sum);
    }

    function inputStructTest(DrifterInfo memory drifter) external returns (DrifterInfo memory) {
        drifters.push(drifter);
        return drifter;
    }

    function inputStructTest2(DrifterInfo[] memory drifters_) external returns (DrifterInfo[] memory) {
        for (uint256 index = 0; index < drifters_.length; ++index) drifters.push(drifters_[index]);
        return drifters_;
    }

    function encode() external pure returns (uint256 length, bytes memory data) {
        DrifterInfo memory drifterInfo = DrifterInfo({rarity: 1, ascension: 2, strength: 3, dexterity: 4, intelligent: 5, constitution: 6, speed: 7});
        data = encodeDrifter(drifterInfo);
        length = data.length;
    }

    function encodeDrifter(DrifterInfo memory drifter) private pure returns (bytes memory data) {
        uint256 compositeData = drifter.rarity;
        compositeData |= (uint256(drifter.ascension) << 8);
        compositeData |= (uint256(drifter.strength) << 16);
        compositeData |= (uint256(drifter.dexterity) << 32);
        compositeData |= (uint256(drifter.intelligent) << 48);
        compositeData |= (uint256(drifter.constitution) << 64);
        compositeData |= (uint256(drifter.speed) << 80);
        data = abi.encode(compositeData);
    }

    function decodeDrifter(bytes memory data)
        public
        pure
        returns (
            uint8 rarity,
            uint8 ascension,
            uint16 strength,
            uint16 dexterity,
            uint16 intelligent,
            uint16 constitution,
            uint16 speed
        )
    {
        uint256 compositeData = abi.decode(data, (uint256));
        rarity = uint8(compositeData);
        ascension = uint8(compositeData) >> 8;
        strength = uint16(compositeData >> 16);
        dexterity = uint16(compositeData >> 32);
        intelligent = uint16(compositeData >> 48);
        constitution = uint16(compositeData >> 64);
        speed = uint16(compositeData >> 80);
    }
}
