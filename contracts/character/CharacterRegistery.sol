// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../interfaces/IDCPRegistryV2.sol";
import "../interfaces/IGeniosMaker.sol";
import "../interfaces/ICharacterRegistry.sol";
import "../interfaces/ICharacterUpdatedHandler.sol";
import "../utils/OperatorGuard.sol";

contract CharacterRegistry is ICharacterRegistry, OperatorGuard {
    bytes32 public constant GDL_STATS = keccak256("GDL_STATS");

    event CharacterUpdated(uint256 indexed globalTokenId, bytes characterData);

    uint256 private constant uin8Mask = 0xff;
    uint256 private constant uin16Mask = 0xffff;
    uint256 private constant uin32Mask = 0xffffffff;
    uint256 private constant _basicStatusMask = (uin8Mask << 8) | (uin8Mask << 24) | (uin32Mask << 144) | (uin32Mask << 176);
    uint256 private constant _basicStatusMaskInv = ~_basicStatusMask;
    uint256 private constant _levelMask = (uin8Mask << 16) | (uin16Mask << 32) | (uin16Mask << 48) | (uin16Mask << 64) | (uin16Mask << 80) | (uin16Mask << 96) | (uin32Mask << 112);
    uint256 private constant _levelMaskInv = ~_levelMask;

    uint256 private constant _rarityLevels = (80 << 32) | (15 << 48) | (95 << 64) | (17 << 80) | (133 << 96) | (19 << 112) | (213 << 128) | (21 << 144) | (426 << 160) | (26 << 176);

    struct CharaInfo {
        uint8 rarity; // 0-8
        uint8 rank; // 8-16
        uint8 level; // 16-24
        uint8 class; // 24-32
        uint16 strength; // 32-48
        uint16 agility; // 48-64
        uint16 intelligence; // 64-80
        uint16 constitution; // 80-96
        uint16 vitality; // 96-112
        uint32 exp; // 112-144
        uint32 remainingTime; // 144-176
        uint32 totalTime; // 176-208
    }

    IDCPRegistryV2 private immutable _dcpResistry;

    mapping(uint256 => ICharacterUpdatedHandler) public charaUpdateHandlers;

    constructor(address dcpResistry_) {
        _dcpResistry = IDCPRegistryV2(dcpResistry_);
    }

    function characterStats(uint256 globalTokenId) public view override returns (uint256 compositeData) {
        bytes memory data = _dcpResistry.getAdditionalProperty(globalTokenId, address(this), GDL_STATS);
        compositeData = abi.decode(data, (uint256));
    }

    function _getRariryPack(uint256 rarity) private pure returns (uint256 initValue, uint256 pointPerLevel) {
        uint256 temp = uint16(_rarityLevels >> (rarity << 5));
        initValue = uint16(temp);
        pointPerLevel = uint16(temp >> 16);
    }

    function _initAsCharacterBatch(
        string calldata networkPrefix,
        address nftContract,
        uint256[] memory tokenIds,
        uint256[] memory rarites,
        uint32 totalTime
    ) private onlyOperator returns (uint256[] memory randomizers, uint256[] memory globalTokenIds) {
        (randomizers, globalTokenIds) = _dcpResistry.initTokenPropertiesBatch(networkPrefix, nftContract, tokenIds);
        uint256[] memory chara = new uint256[](4);
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            if (!_dcpResistry.hasAdditionalProperty(globalTokenIds[index], address(this), GDL_STATS)) {
                uint256 randomizer = randomizers[index];
                uint256 rarity = rarites[index];
                (uint256 initValue, ) = _getRariryPack(rarity);
                uint256 baseCount = initValue / 20;
                uint256 initValueAlter = initValue - baseCount * 5;
                for (uint256 charIdx = 0; charIdx < chara.length; ++charIdx) chara[charIdx] = uint32(randomizer >> (charIdx << 5)) % initValueAlter;
                chara = sort(chara);
                _updateCharacter(
                    CharaInfo({
                        rarity: uint8(rarity),
                        rank: 0,
                        level: 1,
                        class: 0,
                        strength: uint16(chara[0] + baseCount),
                        agility: uint16(chara[1] - chara[0] + baseCount),
                        intelligence: uint16(chara[2] - chara[1] + baseCount),
                        constitution: uint16(chara[3] - chara[2] + baseCount),
                        vitality: uint16(initValueAlter - chara[3] + baseCount),
                        exp: 0,
                        remainingTime: totalTime,
                        totalTime: totalTime
                    }),
                    globalTokenIds[index]
                );
            }
        }
    }

    function initAsCharacter(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId,
        uint256 rarity,
        uint32 totalTime
    ) external override onlyOperator returns (uint256 randomizer, uint256 globalTokenId) {
        (uint256[] memory randomizers, uint256[] memory globalTokenIds) = _initAsCharacterBatch(chainPrefix, nftContract, _makeArray(tokenId, 1), _makeArray(rarity, 1), totalTime);
        return (randomizers[0], globalTokenIds[0]);
    }

    function initAsCharacterBatch(
        string calldata chainPrefix,
        address nftContract,
        uint256[] calldata tokenIds,
        uint256[] calldata rarities,
        uint32 totalTime
    ) external override onlyOperator returns (uint256[] memory randomizers, uint256[] memory globalTokenIds) {
        return _initAsCharacterBatch(chainPrefix, nftContract, tokenIds, rarities, totalTime);
    }

    function updateCharacterBasic(
        uint256 globalTokenId,
        uint8 rank,
        uint8 class,
        uint32 remainingTime,
        uint32 totalTime
    ) external override onlyOperator {
        uint256 compositeData = characterStats(globalTokenId);
        compositeData &= _basicStatusMaskInv;
        compositeData |= (uint256(rank) << 8);
        compositeData |= (uint256(class) << 24);
        compositeData |= (uint256(remainingTime) << 144);
        compositeData |= (uint256(totalTime) << 176);
        _updateCharacter(compositeData, globalTokenId);
    }

    function updateCharacterLevel(
        uint256 globalTokenId,
        uint8 level,
        uint16 strength,
        uint16 agility,
        uint16 intelligence,
        uint16 constitution,
        uint16 vitality,
        uint32 exp
    ) external override onlyOperator {
        uint256 compositeData = characterStats(globalTokenId);
        compositeData &= _levelMaskInv;
        compositeData |= (uint256(level) << 16);
        compositeData |= (uint256(strength) << 32);
        compositeData |= (uint256(agility) << 48);
        compositeData |= (uint256(intelligence) << 64);
        compositeData |= (uint256(constitution) << 80);
        compositeData |= (uint256(vitality) << 96);
        compositeData |= (uint256(exp) << 112);
        _updateCharacter(compositeData, globalTokenId);
    }

    function _updateCharacter(CharaInfo memory character, uint256 globalTokenId) private {
        bytes memory data = encodeCharacter(character);
        _dcpResistry.setAdditionalProperty(globalTokenId, GDL_STATS, data);
        emit CharacterUpdated(globalTokenId, data);
    }

    function _updateCharacter(uint256 compositeData, uint256 globalTokenId) private {
        bytes memory data = abi.encode(compositeData);
        _dcpResistry.setAdditionalProperty(globalTokenId, GDL_STATS, data);
        emit CharacterUpdated(globalTokenId, data);
    }

    function encodeCharacter(CharaInfo memory character) private pure returns (bytes memory data) {
        uint256 compositeData = character.rarity;
        compositeData |= (uint256(character.rank) << 8);
        compositeData |= (uint256(character.level) << 16);
        compositeData |= (uint256(character.class) << 24);
        compositeData |= (uint256(character.strength) << 32);
        compositeData |= (uint256(character.agility) << 48);
        compositeData |= (uint256(character.intelligence) << 64);
        compositeData |= (uint256(character.constitution) << 80);
        compositeData |= (uint256(character.vitality) << 96);
        compositeData |= (uint256(character.exp) << 112);
        compositeData |= (uint256(character.remainingTime) << 144);
        compositeData |= (uint256(character.totalTime) << 176);
        data = abi.encode(compositeData);
    }

    function isTokenRegistred(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId
    ) external view override returns (bool) {
        return _dcpResistry.hasAdditionalProperty(hashTokenId(chainPrefix, nftContract, tokenId), address(this), GDL_STATS);
    }

    function hashTokenId(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(chainPrefix, nftContract, tokenId)));
    }

    function _makeArray(uint256 src, uint256 count) private pure returns (uint256[] memory results) {
        results = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) results[index] = src;
    }

    function sort(uint256[] memory data) public pure returns (uint256[] memory) {
        uint256 size = data.length;
        for (uint256 i = 1; i < size; i++) {
            uint256 key = data[i];
            uint256 j = i;
            for (; j > 0 && data[j - 1] > key; j--) {
                data[j] = data[j - 1];
            }
            data[j] = key;
        }
        return data;
    }
}
