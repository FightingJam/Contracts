// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../RandomBase.sol";
import "../library/MGPLibV2.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/IERC1155Minter.sol";
import "../interfaces/ITokenPoolTrackerV2.sol";
import "../interfaces/ICharacterRegistry.sol";
import "../interfaces/ICharacterOperations.sol";
import "../interfaces/ICharacterUpdatedHandler.sol";

contract StakingLord is RandomBase, ICharacterUpdatedHandler, Ownable {
    using MGPLibV2 for uint256;

    event Deposit(uint256 pId, uint256[] globalTokenIds);
    event Withdraw(uint256 pId, uint256 globalTokenId);
    event PoolUpdated(address indexed owner, uint256 pId, uint256 level, uint256 minRarity, uint256 minRank, uint256 commissionRatio, uint256 materialCount, uint256 extraMaterial);
    event WithdrawPendingToken(address indexed account, uint256 pId, uint256 globalTokenId, uint256 ag, uint256[] extraMaterialIds, uint256[] extraMaterialAmount);
    event CollectCommission(address indexed account, uint256 pId, uint256 ag);

    uint256 private constant defMinRank = 1;
    uint256 private constant maxCommissionRatio = 50;
    uint256 public constant commissionRatioBase = 100;
    uint256 public constant agBonusRatioBase = 100;
    uint256 public constant uint8Mask = 0xff;
    // uint256 private constant pickMaterialBlockInterval = (60 / 3) * 60 * 23;
    uint256 private constant pickMaterialBlockInterval = 50;
    address private constant zeroAddress = address(0x0);

    struct RankUpData {
        uint96 spendAG;
        uint96 spendDGT;
        uint16 maxMiners;
        uint8 agBonusRatio;
        uint8 materialCount;
        uint8 materialRange;
    }

    struct Miner {
        uint32 agPoint; // ag point
        uint64 lastRewardBlock; // when user collect his rewards
        address owner; // for the rest place we put the owner for convenice
    }

    // Info of each pool.
    struct StakingPool {
        uint16 totalMiners; // total miners
        uint8 level;
        uint8 minRarity; // minimal rarity
        uint8 minRank; // minimal rank
        uint8 agBonusRatio; // bonus factor
        uint8 commissionRatio;
        uint8 materialCount;
        uint160 extraMaterial; // extra materials
    }

    struct Material {
        uint16 tokenId;
        uint16 dropRatio;
    }

    // abstraction pools
    // depens on inherition
    mapping(uint256 => StakingPool) public pools;

    mapping(uint256 => uint256) public poolCommission;

    uint256 public constant materialDropRateBase = 100;
    uint256 public constant totalDropFactorBase = 10000;

    RankUpData[] public rankUps;

    //uint256 public incomeDecrease = (432000 << 0) | (100 << 24) | (864000 << 32) | (80 << 56) | (1728000 << 64) | (40 << 88) | (0 << 96) | (10 << 120);
    uint256 public incomeDecrease = (432 << 0) | (100 << 24) | (864 << 32) | (80 << 56) | (1728 << 64) | (40 << 88) | (0 << 96) | (10 << 120);

    uint256 private _materials;

    uint256 public constant incomeDecreaseFactorBase = 100;
    uint256 public constant materialsMax = 10;

    uint256 public agPerBlock = 0.011 ether;
    uint256 public agPriceFactor = 10000;
    uint256 public constant agPriceFactorBase = 10000;

    mapping(uint256 => Miner) public miners;

    string public chainSymbol;
    ITokenPoolTrackerV2 private _tokenTracker;
    IERC721 internal immutable _drifter;
    IERC721 private immutable _mineOwner;
    IDG20 private immutable _AG;
    IDG20 private immutable _DGT;
    IERC1155Minter private _materialMinter;
    ICharacterRegistry private immutable _characterRegistry;
    ICharacterOperations public _characterOperations;

    constructor(
        address randomizer_,
        address tokenTracker_,
        address drifter_,
        address mineOwner_,
        address ag_,
        address dgt_,
        address materialMinter_,
        address drifterRegistry_,
        address drifterOperations_
    ) RandomBase(randomizer_) {
        _tokenTracker = ITokenPoolTrackerV2(tokenTracker_);
        _drifter = IERC721(drifter_);
        _mineOwner = IERC721(mineOwner_);
        _AG = IDG20(ag_);
        _DGT = IDG20(dgt_);
        _materialMinter = IERC1155Minter(materialMinter_);
        _characterRegistry = ICharacterRegistry(drifterRegistry_);
        _characterOperations = ICharacterOperations(drifterOperations_);
        _initDataDEV();
    }

    function setCharaOperations(address charaOperation_) external onlyOwner {
        _characterOperations = ICharacterOperations(charaOperation_);
    }

    function _initDataDEV() private {
        _materials = (10 << 0) | (80 << 16) | (11 << 24) | (40 << 40);

        _addRankups(1200000 ether, 0 ether, 500, 100, 1, 1);
        _addRankups(3000000 ether, 0 ether, 1000, 110, 1, 2);
        _addRankups(4000000 ether, 10000 ether, 2500, 120, 2, 3);
        _addRankups(8000000 ether, 30000 ether, 3500, 135, 2, 4);
        _addRankups(13000000 ether, 60000 ether, 5000, 155, 2, 5);
        _addRankups(0 ether, 0 ether, 8000, 180, 3, 5);
    }

    function _initData() private {
        _materials = (10 << 0) | (15 << 16) | (11 << 24) | (15 << 40);

        _addRankups(1200000 ether, 0 ether, 500, 100, 1, 1);
        _addRankups(3000000 ether, 0 ether, 1000, 110, 1, 2);
        _addRankups(4000000 ether, 10000 ether, 2500, 120, 2, 3);
        _addRankups(8000000 ether, 30000 ether, 3500, 135, 2, 4);
        _addRankups(13000000 ether, 60000 ether, 5000, 155, 2, 5);
        _addRankups(0 ether, 0 ether, 8000, 180, 3, 5);
    }

    function _updateAGPriceFactor(uint256 agPriceFactor_) internal {
        agPriceFactor = agPriceFactor_;
    }

    function _updateIncomeDecrease(uint256 incomeDecrease_) internal {
        incomeDecrease = incomeDecrease_;
    }

    function setChainSymbol(string calldata chainSymbol_) external onlyOwner {
        chainSymbol = chainSymbol_;
    }

    function updateMaterials(uint256[] calldata tokenIds, uint256[] calldata percentage) external onlyOwner {
        uint256 count = tokenIds.length;
        require(count <= materialsMax, "tokenIds count should <= materialsMax");
        uint256 data;
        for (uint256 index = 0; index < count; ++index) data |= (tokenIds[index] + (percentage[index] << 16)) << (index * 24);
        _materials = data;
    }

    function materials() external view returns (uint256[] memory tokenIds, uint256[] memory percentage) {
        tokenIds = new uint256[](materialsMax);
        percentage = new uint256[](materialsMax);
        uint256 data = _materials;
        for (uint256 index = 0; index < materialsMax; ++index) {
            data = data >> (index * 24);
            tokenIds[index] = uint16(data);
            percentage[index] = uint8(data >> 16);
        }
    }

    function _addRankups(
        uint96 spendAG,
        uint96 spendDGT,
        uint16 maxMiners,
        uint8 agBonusRatio,
        uint8 materialCount,
        uint8 materialRange
    ) internal {
        rankUps.push(RankUpData({spendAG: spendAG, spendDGT: spendDGT, agBonusRatio: agBonusRatio, maxMiners: maxMiners, materialCount: materialCount, materialRange: materialRange}));
    }

    function _updateRankups(
        uint256 level,
        uint96 spendAG,
        uint96 spendDGT,
        uint16 maxMiners,
        uint8 agBonusRatio,
        uint8 materialCount,
        uint8 materialRange
    ) internal {
        rankUps[level].spendAG = spendAG;
        rankUps[level].spendDGT = spendDGT;
        rankUps[level].maxMiners = maxMiners;
        rankUps[level].agBonusRatio = agBonusRatio;
        rankUps[level].materialCount = materialCount;
        rankUps[level].materialRange = materialRange;
    }

    function rankUpCount() external view returns (uint256 count) {
        count = rankUps.length;
    }

    function updatePool(
        uint256 pId,
        uint8 minRarity,
        uint8 minRank,
        uint8 commissionRatio,
        uint256[] calldata materialIds
    ) external onlyMineOwner(pId) {
        _updatePool(pId, minRarity, minRank, commissionRatio, materialIds);
    }

    function rankUp(
        uint256 pId,
        uint8 minRarity,
        uint8 minRank,
        uint8 commissionRatio,
        uint256[] calldata materialIds
    ) external onlyMineOwner(pId) poolAvalible(pId) {
        uint256 level = pools[pId].level;
        RankUpData storage rankUpData = rankUps[level];
        uint256 spendAG = rankUpData.spendAG;
        require(spendAG > 0, "already reach max level");
        _burnAG(msg.sender, spendAG);
        _burnDGT(msg.sender, rankUpData.spendDGT);
        pools[pId].level = uint8(level + 1);
        _updatePool(pId, minRarity, minRank, commissionRatio, materialIds);
    }

    function _updatePool(
        uint256 pId,
        uint8 minRarity,
        uint8 minRank,
        uint8 commissionRatio,
        uint256[] calldata materialIds
    ) private {
        require(minRank >= defMinRank, "min rank not valid");
        require(commissionRatio <= maxCommissionRatio, "commissionRatio not valid");
        uint256 level = pools[pId].level;
        uint256 materialCount = rankUps[level].materialCount;
        require(materialIds.length == materialCount, "material count not valid");
        pools[pId].minRarity = minRarity;
        pools[pId].minRank = minRank;
        pools[pId].agBonusRatio = rankUps[level].agBonusRatio;
        pools[pId].commissionRatio = commissionRatio;
        pools[pId].materialCount = uint8(materialCount);
        uint256 materialRange = rankUps[level].materialRange;
        uint256 extraMaterial;
        for (uint256 index = 0; index < materialCount; ++index) {
            uint256 materialId = materialIds[index];
            require(materialId < materialRange, "material Id not valid");
            extraMaterial |= (materialId << (index * 16));
        }
        pools[pId].extraMaterial = uint160(extraMaterial);
        emit PoolUpdated(msg.sender, pId, level, minRarity, minRank, commissionRatio, materialCount, extraMaterial);
    }

    function deposit(uint256 pId, uint256[] calldata tokenIds) external poolAvalible(pId) {
        address account = msg.sender;
        uint256[] memory globalTokenIds = _validOwnerAndEmptyPoolId(account, tokenIds);
        StakingPool storage pool = pools[pId];
        {
            uint256 totalMiners = pool.totalMiners + globalTokenIds.length;
            require(totalMiners <= rankUps[pool.level].maxMiners, "exceed max miners");
            unchecked {
                pool.totalMiners = uint16(totalMiners);
            }
        }
        uint256 minRarity = pool.minRarity;
        uint256 minRank = pool.minRank;
        for (uint256 index = 0; index < globalTokenIds.length; ++index) {
            uint256 globalTokenId = globalTokenIds[index];
            uint256 agPoint = _estimateAndCheckAvailble(globalTokenId, minRarity, minRank);
            miners[globalTokenId].agPoint = uint32(agPoint);
            miners[globalTokenId].lastRewardBlock = uint64(block.number);
        }
        _tokenTracker.setTraceBatch(globalTokenIds, uint96(pId));
        emit Deposit(pId, globalTokenIds);
    }

    function _validOwnerAndEmptyPoolId(address account, uint256[] calldata tokenIds) private view returns (uint256[] memory globalTokenIds) {
        globalTokenIds = _validateOwnerBatch(account, tokenIds);
        (address[] memory contractAddress, ) = _tokenTracker.getTraceBatch(globalTokenIds);
        for (uint256 index = 0; index < globalTokenIds.length; ++index) require(contractAddress[index] == zeroAddress, "token not staked");
    }

    function _validOwnerAndGetPoolId(address account, uint256 tokenId) private view returns (uint256 globalTokenId, uint256 pId) {
        require(_drifter.ownerOf(tokenId) == account, "token not belongs to account");
        globalTokenId = MGPLibV2.hashTokenId(chainSymbol, address(_drifter), tokenId);
        address contractAddress;
        (contractAddress, pId) = _tokenTracker.getTrace(globalTokenId);
        require(contractAddress == address(this), "token not staked");
    }

    /**
     * @dev deposit token into pool
     * any inherited contract should call this function to make a deposit
     */
    function _refreshToken(
        uint256 pId,
        address account,
        uint256 globalTokenId
    ) private {
        uint256 remainingTime = _withdrawPendingToken(pId, account, globalTokenId);
        if (remainingTime == 0) _quitPool(globalTokenId, pId);
        else {
            StakingPool storage pool = pools[pId];
            uint256 agPoint = _estimateAndCheckAvailble(globalTokenId, pool.minRarity, pool.minRank);
            miners[globalTokenId].agPoint = uint32(agPoint);
        }
    }

    function withdraw(uint256 tokenId) external {
        address account = msg.sender;
        (uint256 globalTokenId, uint256 pId) = _validOwnerAndGetPoolId(account, tokenId);
        _withdrawPendingToken(pId, account, globalTokenId);
        _quitPool(globalTokenId, pId);
    }

    /**
     * @dev implemtation of withdraw pending tokens
     */
    function withdrawPendingToken(uint256 tokenId) external {
        address account = msg.sender;
        (uint256 globalTokenId, uint256 pId) = _validOwnerAndGetPoolId(account, tokenId);
        uint256 remainingTime = _withdrawPendingToken(pId, account, globalTokenId);
        if (remainingTime == 0) _quitPool(globalTokenId, pId);
    }

    function collectCommission(uint256 pId) external poolAvalible(pId) onlyMineOwner(pId) {
        uint256 amount = poolCommission[pId];
        if (amount > 0) {
            _mintAG(msg.sender, amount);
            poolCommission[pId] = 0;
            emit CollectCommission(msg.sender, pId, amount);
        }
    }

    function _quitPool(uint256 globalTokenId, uint256 pId) private {
        --pools[pId].totalMiners;
        delete miners[globalTokenId];
        _tokenTracker.clearTrace(globalTokenId);
        emit Withdraw(pId, globalTokenId);
    }

    /**
     * @dev implemtation of withdraw pending tokens
     */
    function _withdrawPendingToken(
        uint256 pId,
        address account,
        uint256 globalTokenId
    ) private returns (uint256 remainingTime) {
        Miner storage miner = miners[globalTokenId];
        uint256 agPending;
        uint256 rank;
        {
            uint256 pending;
            uint256 commision;
            uint256 class;
            uint256 totalTime;
            (pending, commision, rank, class, remainingTime, totalTime) = _pendingAG(pId, globalTokenId);
            _characterRegistry.updateCharacterBasic(globalTokenId, uint8(rank), uint8(class), uint32(remainingTime), uint32(totalTime));
            agPending = pending;
            _mintAG(account, agPending);
            poolCommission[pId] += commision;
        }
        uint256[] memory extraDropsId;
        uint256[] memory extraDropsAmount;
        unchecked {
            if (block.number - miner.lastRewardBlock > pickMaterialBlockInterval) {
                (, , uint16 dropRateBounus, ) = _characterOperations.rankData(rank);
                uint256 materials_ = _materials;
                uint256 materialCount = pools[pId].materialCount;
                uint256 extraMaterial = pools[pId].extraMaterial;
                uint256 count;
                uint256[] memory tmpExtraDropsId = new uint256[](materialCount);
                uint256[] memory tmpExtraDropsAmount = new uint256[](materialCount);
                {
                    uint256 randBase = _genRandomNumber();
                    for (uint256 index = 0; index < materialCount; ++index) {
                        uint256 materialTokenIndex = uint16(extraMaterial >> (index * 16));
                        uint256 dropRate = (materials_ >> (materialTokenIndex * 24));
                        materialTokenIndex = uint16(dropRate);
                        dropRate = ((dropRate >> 16) & uint8Mask) * dropRateBounus;
                        uint256 amount = dropRate / totalDropFactorBase;
                        if (randBase % totalDropFactorBase < dropRate) ++amount;
                        if (amount > 0) {
                            tmpExtraDropsId[count] = materialTokenIndex;
                            tmpExtraDropsAmount[count] = amount;
                            ++count;
                        }
                        randBase ^= (randBase >> 1);
                    }
                }
                if (count > 0) {
                    extraDropsId = new uint256[](count);
                    extraDropsAmount = new uint256[](count);
                    for (uint256 index = 0; index < count; ++index) {
                        extraDropsId[index] = tmpExtraDropsId[index];
                        extraDropsAmount[index] = tmpExtraDropsAmount[index];
                    }
                    _mintMaterial(account, extraDropsId, extraDropsAmount);
                }
            }
        }
        miner.lastRewardBlock = uint64(block.number);
        emit WithdrawPendingToken(account, pId, globalTokenId, agPending, extraDropsId, extraDropsAmount);
    }

    /**
     * @dev get the pending balance for one pool
     */
    function pendingAG(uint256 tokenId) external view returns (uint256 pending) {
        uint256 globalTokenId = MGPLibV2.hashTokenId(chainSymbol, address(_drifter), tokenId);
        (address contractAddress, uint256 poolId) = _tokenTracker.getTrace(globalTokenId);
        if (contractAddress == address(this)) (pending, , , , , ) = _pendingAG(poolId, globalTokenId);
    }

    /**
     * @dev get the pending balance for one pool
     */
    function _pendingAG(uint256 pId, uint256 globalTokenId)
        private
        view
        returns (
            uint256 pending,
            uint256 commision,
            uint256 rank,
            uint256 class,
            uint256 remainingTime,
            uint256 totalTime
        )
    {
        Miner storage miner = miners[globalTokenId];
        uint256 agPoint = miner.agPoint;
        uint256 miningOffsetBlocks = block.number - miner.lastRewardBlock;
        (, rank, class, remainingTime, totalTime) = _characterRegistry.characterStats(globalTokenId).decodeCharacterBasic();
        if (miningOffsetBlocks > remainingTime) miningOffsetBlocks = remainingTime;
        remainingTime -= miningOffsetBlocks;
        {
            uint256 _incomeDecrease = incomeDecrease;
            uint256 accMiningOffsetBlockSum;
            for (uint256 index = 0; index < 8; ++index) {
                uint256 temp = uint32(_incomeDecrease >> (index * 32));
                uint256 cap = uint24(temp);
                if (miningOffsetBlocks <= cap || cap == 0) {
                    pending += (miningOffsetBlocks - accMiningOffsetBlockSum) * (agPoint * (temp >> 24));
                    break;
                } else {
                    pending += cap * agPoint * (temp >> 24);
                    accMiningOffsetBlockSum = cap;
                }
            }
        }
        pending = (agPerBlock * (pending * agPriceFactor) * pools[pId].agBonusRatio) / incomeDecreaseFactorBase / agPriceFactorBase / agBonusRatioBase;
        commision = (pending * pools[pId].commissionRatio) / commissionRatioBase;
        pending -= commision;
    }

    function estimatePoints(uint256 tokenId) external view returns (uint256 agPoint) {
        (agPoint, , , ) = _estimatePoints(tokenId);
    }

    function _estimatePoints(uint256 globalTokenId)
        private
        view
        returns (
            uint256 agPoint,
            uint256 rarity,
            uint256 rank,
            uint256 remainingTime
        )
    {
        (rarity, rank, , remainingTime, ) = _characterRegistry.characterStats(globalTokenId).decodeCharacterBasic();
        (uint256 incomeMultiplier, , , ) = _characterOperations.rankData(rank);
        agPoint = incomeMultiplier;
    }

    function _estimateAndCheckAvailble(
        uint256 globalTokenId,
        uint256 minRarity,
        uint256 minRank
    ) private view returns (uint256) {
        (uint256 agPoint, uint256 rarity, uint256 rank, uint256 remainingTime) = _estimatePoints(globalTokenId);
        require(remainingTime > 0, "not enought remaining time");
        require(minRarity <= rarity && minRank <= rank, "not meet minimal requirement");
        return agPoint;
    }

    function _mintMaterial(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) private {
        _materialMinter.mintBatch(account, ids, amounts, "");
    }

    function _mintAG(address account, uint256 amount) private {
        if (amount > 0) _AG.mint(account, (amount * 95) / 100);
    }

    function _burnAG(address account, uint256 amount) private {
        if (amount > 0) _AG.burnFrom(account, amount);
    }

    function _burnDGT(address account, uint256 amount) private {
        if (amount > 0) _DGT.burnFrom(account, amount);
    }

    function tokenUpdated(
        uint256 pId,
        address account,
        uint256 globalTokenId
    ) external override {
        require(msg.sender == address(_characterOperations), "only call from charaOperators");
        _refreshToken(pId, account, globalTokenId);
    }

    function _validateOwnerBatch(address account, uint256[] calldata tokenIds) private view returns (uint256[] memory globalTokenIds) {
        globalTokenIds = new uint256[](tokenIds.length);
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            require(_drifter.ownerOf(tokenIds[index]) == account, "token not belongs to account");
            globalTokenIds[index] = MGPLibV2.hashTokenId(chainSymbol, address(_drifter), tokenIds[index]);
        }
    }

    modifier poolAvalible(uint256 pId) {
        require(pools[pId].minRank >= defMinRank, "pool not availble");
        _;
    }

    modifier onlyMineOwner(uint256 pId) {
        require(_mineOwner.ownerOf(pId) == msg.sender, "require mine owner card");
        _;
    }
}
