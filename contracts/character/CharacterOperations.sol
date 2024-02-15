// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDrifterUpdatedHandler.sol";
import "../interfaces/ICharacterRegistry.sol";
import "../interfaces/ITokenPoolTrackerV2.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/IDG721.sol";
import "../library/MGPLibV2.sol";
import "../utils/OperatorGuard.sol";
import "../RandomBase.sol";
import "../interfaces/IDrifterOperations.sol";

contract CharacterOperations is OperatorGuard, RandomBase {
    using MGPLibV2 for uint256;

    struct RankUpData {
        uint96 spendAG;
        uint96 spendDGT;
        uint16 failure;
    }

    struct RankData {
        uint16 incomeMultiplier;
        uint32 additionRT;
        uint16 dropRateBounus;
        uint32 staminaChargeBlocks;
    }

    address private constant zeroAddress = address(0x0);
    uint256 private constant failureBase = 1000;
    uint256 private constant blocksPerDay = (60 / 3) * 60 * 24;
    uint256 private constant rechargePerToken = blocksPerDay * 20;
    uint256 private constant normalRT = 35 * blocksPerDay;
    uint256 private constant genesisRT = 45 * blocksPerDay;

    mapping(uint256 => RankUpData) public rankupData;
    mapping(uint256 => RankData) public rankData;
    mapping(uint256 => uint256) public failureReduces;

    ITokenPoolTrackerV2 private immutable _tokenTracker;
    address private immutable _drifter;
    IDG20 private immutable _AG;
    IDG20 private immutable _DGT;
    ICharacterRegistry private immutable _charaRegistery;

    constructor(
        address randomizer_,
        address tokenTracker_,
        address drifter_,
        address ag_,
        address dgt_,
        address charaRegistery_
    ) RandomBase(randomizer_) {
        _tokenTracker = ITokenPoolTrackerV2(tokenTracker_);
        _drifter = drifter_;
        _AG = IDG20(ag_);
        _DGT = IDG20(dgt_);
        _charaRegistery = ICharacterRegistry(charaRegistery_);
        _initData();
    }

    function _initData() private {
        rankupData[0] = RankUpData({spendAG: 13000 ether, spendDGT: 0 ether, failure: 0});
        rankupData[1] = RankUpData({spendAG: 25000 ether, spendDGT: 0 ether, failure: 0});
        rankupData[2] = RankUpData({spendAG: 75000 ether, spendDGT: 0 ether, failure: 0});
        rankupData[3] = RankUpData({spendAG: 225000 ether, spendDGT: 250 ether, failure: 0});
        rankupData[4] = RankUpData({spendAG: 500000 ether, spendDGT: 2500 ether, failure: 200});
        rankupData[5] = RankUpData({spendAG: 1000000 ether, spendDGT: 5000 ether, failure: 250});
        rankupData[6] = RankUpData({spendAG: 2500000 ether, spendDGT: 25000 ether, failure: 300});
        rankupData[7] = RankUpData({spendAG: 5000000 ether, spendDGT: 50000 ether, failure: 400});
        rankupData[8] = RankUpData({spendAG: 10000000 ether, spendDGT: 60000 ether, failure: 500});
        rankupData[9] = RankUpData({spendAG: 2500000 ether, spendDGT: 150000 ether, failure: 500});

        rankData[0] = RankData({incomeMultiplier: 1, additionRT: uint32(0 * blocksPerDay), dropRateBounus: 100, staminaChargeBlocks: uint32(blocksPerDay / 3)});
        rankData[1] = RankData({incomeMultiplier: 2, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 110, staminaChargeBlocks: uint32(blocksPerDay / 3)});
        rankData[2] = RankData({incomeMultiplier: 3, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 125, staminaChargeBlocks: uint32(blocksPerDay / 3)});
        rankData[3] = RankData({incomeMultiplier: 5, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 145, staminaChargeBlocks: uint32(blocksPerDay / 3)});
        rankData[4] = RankData({incomeMultiplier: 14, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 170, staminaChargeBlocks: uint32(blocksPerDay / 4)});
        rankData[5] = RankData({incomeMultiplier: 24, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 200, staminaChargeBlocks: uint32(blocksPerDay / 5)});
        rankData[6] = RankData({incomeMultiplier: 48, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 240, staminaChargeBlocks: uint32(blocksPerDay / 6)});
        rankData[7] = RankData({incomeMultiplier: 75, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 290, staminaChargeBlocks: uint32(blocksPerDay / 7)});
        rankData[8] = RankData({incomeMultiplier: 100, additionRT: uint32(20 * blocksPerDay), dropRateBounus: 350, staminaChargeBlocks: uint32(blocksPerDay / 8)});
        rankData[9] = RankData({incomeMultiplier: 200, additionRT: uint32(1000 * blocksPerDay), dropRateBounus: 420, staminaChargeBlocks: uint32(blocksPerDay / 9)});
        rankData[10] = RankData({incomeMultiplier: 300, additionRT: uint32(1000 * blocksPerDay), dropRateBounus: 500, staminaChargeBlocks: uint32(blocksPerDay / 10)});

        failureReduces[0] = (776 << 0) | (485 << 16) | (334 << 32) | (242 << 48) | (186 << 64) | (149 << 80) | (124 << 96) | (110 << 112) | (100 << 128);
        failureReduces[1] = (543 << 0) | (340 << 16) | (234 << 32) | (170 << 48) | (131 << 64) | (104 << 80) | (87 << 96) | (77 << 112) | (70 << 128);
        failureReduces[2] = (388 << 0) | (243 << 16) | (167 << 32) | (121 << 48) | (93 << 64) | (75 << 80) | (62 << 96) | (55 << 112) | (50 << 128);
        failureReduces[3] = (233 << 0) | (146 << 16) | (100 << 32) | (73 << 48) | (56 << 64) | (45 << 80) | (37 << 96) | (33 << 112) | (30 << 128);
        failureReduces[4] = (155 << 0) | (97 << 16) | (67 << 32) | (48 << 48) | (37 << 64) | (30 << 80) | (25 << 96) | (22 << 112) | (20 << 128);
    }

    function _tryRankUp(
        uint256 targetTokenId,
        uint256[] calldata sacrificerTokenIds,
        bool isInStaking
    )
        private
        returns (
            bool isSuccess,
            uint256 rank,
            uint256 class,
            uint256 remainingTime,
            uint256 totalTime
        )
    {
        uint256 rarity;
        (rarity, rank, class, remainingTime, totalTime) = _charaRegistery.characterStats(targetTokenId).decodeCharacterBasic();
        uint256 failure = rankupData[rank].failure;
        {
            uint256 spendAG = rankupData[rank].spendAG;
            uint256 spendDGT = rankupData[rank].spendDGT;
            require(spendAG != 0, "cannot rank up");
            _burnAG(msg.sender, spendAG);
            if (spendDGT > 0) _burnDGT(msg.sender, spendDGT);
        }
        isSuccess = true;
        if (failure > 0) {
            for (uint256 index = 0; index < sacrificerTokenIds.length; ++index) {
                uint256 sacrificerTokenId = sacrificerTokenIds[index];
                if (failure > 0) {
                    (uint256 sacrificerRarity, uint256 sacrificerRank, , , ) = _charaRegistery.characterStats(sacrificerTokenId).decodeCharacterBasic();
                    uint256 reduces = uint16(failureReduces[rarity <= sacrificerRarity ? 0 : rarity - sacrificerRarity] >> ((rank <= sacrificerRank ? 0 : rank - sacrificerRank) * 16));
                    if (failure > reduces) failure -= reduces;
                    else failure = 0;
                }
            }
            if (failure > 0) {
                require(!isInStaking, "cannot perform in staking");
                if (_genRandomNumber() % failureBase < failure) isSuccess = false;
            }
        }
        if (isSuccess) {
            ++rank;
            uint256 additionalTime = rankData[rank].additionRT;
            remainingTime += additionalTime;
            totalTime += additionalTime;
        }
    }

    function _burnDrifter(uint256 tokenId) private {
        IDG721(_drifter).burn(tokenId);
    }

    function _burnDrifterBatch(address account, uint256[] calldata tokenIds) private {
        IDG721(_drifter).burnFromBatch(account, tokenIds);
    }

    function _burnAG(address account, uint256 amount) private {
        _AG.burnFrom(account, amount);
    }

    function _burnDGT(address account, uint256 amount) private {
        _DGT.burnFrom(account, amount);
    } 

    function decodeCharacter(uint256 globalTokenId)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 compositeData = _charaRegistery.characterStats(globalTokenId);
        return compositeData.decodeCharacter();
    }

    // function dischargeRemainingTime(uint256 globalTokenId, uint256 amount) external {
    //     (address contractAddress, ) = _tokenTracker.getTrace(_drifter, targetTokenId);
    //     require(contractAddress == msg.sender, "only staking pool can discharge remaining times");
    //     uint256 globalTokenId = MGPLib.hashTokenId(_chainSymbol, _drifter, targetTokenId);
    //     (, uint8 rank, uint8 class, uint256 remainingTime, uint32 totalTime) = _charaRegistery.charactorStats(globalTokenId).decodeDrifterBasic();
    //     if (remainingTime > amount) remainingTime -= amount;
    //     else remainingTime = 0;
    //     _updateBasic(globalTokenId, rank, class, uint32(remainingTime), totalTime);
    // }
}
