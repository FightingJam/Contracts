// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../library/MGPLibV2.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/ITokenPoolTrackerV2.sol";
import "../interfaces/ICharacterRegistry.sol";
import "../interfaces/ICharacterOperations.sol";
import "../interfaces/ICharacterUpdatedHandler.sol";

contract StakingOfficial is ICharacterUpdatedHandler, Ownable {
    using MGPLibV2 for uint256;

    event Deposit(uint256 pId, uint256[] globalTokenIds);
    event Withdraw(uint256 pId, uint256[] globalTokenIds);
    event PoolUpdated(uint256 pId, uint256 minRarity, uint256 minRank, uint256 agPerBlock, uint256 dgtPerBlock);
    event WithdrawPendingTokens(address indexed account, uint256 pId, uint256[] globalTokenIds, uint256 ag, uint256 dgt);

    uint256 private constant acc1e12 = 1e12;
    address private constant zeroAddress = address(0x0);

    struct Miner {
        uint32 agPoint; // ag point
        uint32 dgtPoint; // dg point
        uint64 lastRewardBlock; // when user collect his rewards
        uint128 rewardDebt; // reward Debut
    }

    // Info of each pool.
    struct StakingPool {
        uint96 totalDGPPoints; // total points that staked
        uint32 totalMiners; // total miners
        uint64 agPerBlock; // token per block
        uint64 dgtPerBlock; // token per block
        //***********256bit****************/
        uint192 accTokenPerShare; // Accumulated token per share, times 1e12.
        uint64 lastRewardBlock; // Last block number that token distribution occurs.
        //***********256bit****************/
        uint8 minRarity; // minimal rarity
        uint8 minRank; // minimal rank
    }

    uint256 public dgtRarityRatio = (0 << 0) | (0 << 16) | (0 << 32) | (100 << 48) | (200 << 64) | (500 << 80);
    uint256 public incomeDecrease = (432 << 0) | (100 << 24) | (864 << 32) | (80 << 56) | (1728 << 64) | (40 << 88) | (0 << 96) | (10 << 120);
    uint256 public constant incomeDecreaseFactorBase = 100;

    uint256 public rtConsume = 60;
    uint256 public constant rtConsumeFactorBase = 100;

    uint256 public agPriceFactor = 10000;
    uint256 public constant agPriceFactorBase = 10000;

    mapping(uint256 => Miner) public miners;

    address public tokenUpdater;

    StakingPool[] public pools;

    //ITokenPoolTracker private _tokenTracker;
    // address internal immutable _drifter;
    string public chainSymbol;
    IERC721 private immutable _drifter;
    IDG20 private immutable _AG;
    IDG20 private immutable _DGT;
    ITokenPoolTrackerV2 private immutable _tokenTracker;
    ICharacterRegistry private immutable _characterRegistry;
    ICharacterOperations public _characterOperations;

    //IDrifterOperations private immutable _drifterOperations;

    constructor(
        string memory chainSymbol_,
        address drifter_,
        address ag_,
        address dgt_,
        address tokenTracker_,
        address characterRegistry_,
        address characterOperations_
    ) {
        chainSymbol = chainSymbol_;
        _drifter = IERC721(drifter_);
        _AG = IDG20(ag_);
        _DGT = IDG20(dgt_);
        _tokenTracker = ITokenPoolTrackerV2(tokenTracker_);
        _characterRegistry = ICharacterRegistry(characterRegistry_);
        _characterOperations = ICharacterOperations(characterOperations_);
        _initDataDEV();
    }

    function setCharaOperations(address charaOperation_) external onlyOwner {
        _characterOperations = ICharacterOperations(charaOperation_);
    }

    function addTokenUpdater(address tokenUpdater_) external onlyOwner {
        tokenUpdater = tokenUpdater_;
    }

    function updateRTConsume(uint256 rtConsume_) external onlyOwner {
        rtConsume = rtConsume_;
    }

    function updateAGPriceFactor(uint256 agPriceFactor_) external onlyOwner {
        agPriceFactor = agPriceFactor_;
    }

    function updateDGTRarityRatio(uint256 dgtRarityRatio_) external onlyOwner {
        dgtRarityRatio = dgtRarityRatio_;
    }

    function updateIncomeDecrease(uint256 incomeDecrease_) external onlyOwner {
        incomeDecrease = incomeDecrease_;
    }

    function poolCount() external view returns (uint256) {
        return pools.length;
    }

    function _initDataDEV() private {
        uint256[] memory paidPrice;
        addPool(0.005 ether, 0, 1, 0);
        addPool(0.01 ether, 0.01 ether, 1, 1);
        paidPrice = new uint256[](9);
        paidPrice[0] = 0.001 ether;
        paidPrice[1] = 0.002 ether;
        paidPrice[2] = 0.003 ether;
        paidPrice[3] = 0.004 ether;
        paidPrice[4] = 0.005 ether;
        paidPrice[5] = 0.006 ether;
        paidPrice[6] = 0.007 ether;
        paidPrice[7] = 0.008 ether;
        paidPrice[8] = 0.009 ether;
        addPool(0.025 ether, 0.01 ether, 2, 2);
        addPool(0.035 ether, 0.01 ether, 3, 3);
        addPool(0.06 ether, 0.01 ether, 4, 4);
        addPool(0.08 ether, 0.01 ether, 5, 5);
    }

    function addPool(
        uint64 agPerBlock,
        uint64 dgtPerBlock,
        uint8 minRarity,
        uint8 minRank
    ) public onlyOwner {
        uint256 pId = pools.length;
        pools.push(StakingPool({totalDGPPoints: 0, totalMiners: 0, agPerBlock: agPerBlock, dgtPerBlock: dgtPerBlock, accTokenPerShare: 0, lastRewardBlock: uint64(block.number), minRarity: minRarity, minRank: minRank}));
        emit PoolUpdated(pId, minRarity, minRank, agPerBlock, dgtPerBlock);
    }

    function updatePool(
        uint256 pId,
        uint64 agPerBlock,
        uint64 dgtPerBlock,
        uint8 minRarity,
        uint8 minRank
    ) external onlyOwner {
        _updatePool(pId);
        pools[pId].agPerBlock = agPerBlock;
        pools[pId].dgtPerBlock = dgtPerBlock;
        pools[pId].minRarity = minRarity;
        pools[pId].minRank = minRank;
        emit PoolUpdated(pId, minRarity, minRank, agPerBlock, dgtPerBlock);
    }

    /**
     * @dev deposit token into pool
     * any inherited contract should call this function to make a deposit
     */
    function deposit(uint256 pId, uint256[] calldata tokenIds) external {
        uint256[] memory globalTokenIds = _validOwnerAndEmptyPoolId(tokenIds);
        _updatePool(pId);
        StakingPool storage pool = pools[pId];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 totalDGPPoints = pool.totalDGPPoints;
        uint256 minRarity = pool.minRarity;
        uint256 minRank = pool.minRank;
        for (uint256 index = 0; index < globalTokenIds.length; ++index) {
            uint256 globalTokenId = globalTokenIds[index];
            (uint256 agPoint, uint256 dgtPoint) = _estimateAndCheckAvailble(globalTokenId, minRarity, minRank);
            miners[globalTokenId].agPoint = uint32(agPoint);
            miners[globalTokenId].dgtPoint = uint32(dgtPoint);
            miners[globalTokenId].lastRewardBlock = uint64(block.number);
            if (dgtPoint > 0) {
                miners[globalTokenId].rewardDebt = uint128((dgtPoint * accTokenPerShare) / acc1e12);
                totalDGPPoints += dgtPoint;
            }
        }
        pool.totalMiners += uint32(globalTokenIds.length);
        pool.totalDGPPoints = uint96(totalDGPPoints);
        _tokenTracker.setTraceBatch(globalTokenIds, uint96(pId));
        emit Deposit(pId, globalTokenIds);
    }

    function _validOwnerAndEmptyPoolId(uint256[] calldata tokenIds) private view returns (uint256[] memory globalTokenIds) {
        address account = msg.sender;
        globalTokenIds = _validateOwnerBatch(account, tokenIds);
        (address[] memory contractAddress, ) = _tokenTracker.getTraceBatch(globalTokenIds);
        for (uint256 index = 0; index < globalTokenIds.length; ++index) require(contractAddress[index] == zeroAddress, "token not staked");
    }

    function _validOwnerAndGetPoolId(uint256[] calldata tokenIds) private view returns (uint256[] memory globalTokenIds, uint256 pId) {
        address account = msg.sender;
        globalTokenIds = _validateOwnerBatch(account, tokenIds);
        (address[] memory contractAddress, uint256[] memory poolId) = _tokenTracker.getTraceBatch(globalTokenIds);
        pId = poolId[0];
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            require(contractAddress[index] == address(this), "token not staked");
            require(pId == poolId[0], "not in same pool");
        }
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
        uint256[] memory globalTokenIds = new uint256[](1);
        globalTokenIds[0] = globalTokenId;
        _withdrawPendingTokenBatch(pId, account, globalTokenIds);
        StakingPool storage pool = pools[pId];
        Miner storage miner = miners[globalTokenId];
        (uint256 agPoint, uint256 dgtPoint) = _estimateAndCheckAvailble(globalTokenId, pool.minRarity, pool.minRank);
        pool.totalDGPPoints = uint96(pool.totalDGPPoints - miner.dgtPoint + dgtPoint);
        miner.agPoint = uint32(agPoint);
        miner.dgtPoint = uint32(dgtPoint);
        miner.rewardDebt = uint128((dgtPoint * pool.accTokenPerShare) / acc1e12);
    }

    function estimatePoints(uint256 globalTokenId) external view returns (uint256 agPoint, uint256 dgtPoint) {
        (agPoint, dgtPoint, , , ) = _estimatePoints(globalTokenId);
    }

    function _estimatePoints(uint256 globalTokenId)
        private
        view
        returns (
            uint256 agPoint,
            uint256 dgtPoint,
            uint256 rarity,
            uint256 rank,
            uint256 remainingTime
        )
    {
        (rarity, rank, , remainingTime, ) = _characterRegistry.characterStats(globalTokenId).decodeCharacterBasic();
        (uint256 incomeMultiplier, , , ) = _characterOperations.rankData(rank);
        agPoint = incomeMultiplier;
        dgtPoint = agPoint * uint16(dgtRarityRatio >> (rarity * 16));
    }

    function _estimateAndCheckAvailble(
        uint256 globalTokenId,
        uint256 minRarity,
        uint256 minRank
    ) private view returns (uint256, uint256) {
        (uint256 agPoint, uint256 dgtPoint, uint256 rarity, uint256 rank, uint256 remainingTime) = _estimatePoints(globalTokenId);
        require(remainingTime > 0, "not enought remaining time");
        require(minRarity <= rarity && minRank <= rank, "not meet minimal requirement");
        return (agPoint, dgtPoint);
    }

    /**
     * @dev withdraw staking token from pool
     * any inherited contract should call this function to make a withdraw
     */
    function withdraw(uint256[] calldata tokenIds) external {
        (uint256[] memory globalTokenIds, uint256 pId) = _validOwnerAndGetPoolId(tokenIds);
        _withdrawPendingTokenBatch(pId, msg.sender, globalTokenIds);
        _tokenTracker.clearTraceBatch(globalTokenIds);
        uint256 dgtPoints = pools[pId].totalDGPPoints;
        for (uint256 index = 0; index < globalTokenIds.length; ++index) {
            uint256 globalTokenId = globalTokenIds[index];
            dgtPoints -= miners[globalTokenId].dgtPoint;
            delete miners[globalTokenId];
        }
        pools[pId].totalDGPPoints = uint96(dgtPoints);
        pools[pId].totalMiners -= uint32(globalTokenIds.length);
        emit Withdraw(pId, globalTokenIds);
    }

    /**
     * @dev implemtation of withdraw pending tokens
     */
    function withdrawPendingTokenBatch(uint256[] calldata tokenIds) external {
        (uint256[] memory globalTokenIds, uint256 pId) = _validOwnerAndGetPoolId(tokenIds);
        _withdrawPendingTokenBatch(pId, msg.sender, globalTokenIds);
    }

    /**
     * @dev implemtation of withdraw pending tokens
     */
    function _withdrawPendingTokenBatch(
        uint256 pId,
        address account,
        uint256[] memory globalTokenIds
    ) private {
        uint256 accTokenPerShare = _updatePool(pId);
        uint256 agPending;
        uint256 dgtPending;
        for (uint256 index = 0; index < globalTokenIds.length; ++index) {
            uint256 globalTokenId = globalTokenIds[index];
            Miner storage miner = miners[globalTokenId];
            {
                (uint256 pending, uint256 rank, uint256 class, uint256 remainingTime, uint256 totalTime) = _pendingAG(pId, globalTokenId);
                _characterRegistry.updateCharacterBasic(globalTokenId, uint8(rank), uint8(class), uint32(remainingTime), uint32(totalTime));
                agPending += pending;
                miner.lastRewardBlock = uint64(block.number);
            }
            {
                // calculate pending tokens
                uint256 dgtPoint = miner.dgtPoint;
                if (dgtPoint > 0) {
                    // update pool for new accTokenPerShare
                    dgtPending += (dgtPoint * accTokenPerShare) / acc1e12 - miner.rewardDebt;
                    // update user reward debut
                    miner.rewardDebt = uint128((dgtPoint * accTokenPerShare) / acc1e12);
                }
            }
        }
        _mintAG(account, agPending);
        _mintDGT(account, dgtPending);
        emit WithdrawPendingTokens(account, pId, globalTokenIds, agPending, dgtPending);
    }

    /**
     * @dev Update reward variables of the given pool to be up-to-date.
     */

    function _updatePool(uint256 pId) private returns (uint256) {
        StakingPool storage pool = pools[pId];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lastRewardBlock = pool.lastRewardBlock;
        uint256 tokenPerBlock = pool.dgtPerBlock;
        uint256 totalDGPPoints = pool.totalDGPPoints;
        // if the mining is not started there is no needs to update
        if (block.number <= lastRewardBlock) {
            return accTokenPerShare;
        }
        // if there is nothing in this pool
        if (totalDGPPoints == 0) {
            pool.lastRewardBlock = uint32(block.number);
            return accTokenPerShare;
        }
        // get reward
        uint256 tokenReward = _getPoolReward(tokenPerBlock, lastRewardBlock);
        // calcult accumulate token per share
        accTokenPerShare += (tokenReward * acc1e12) / totalDGPPoints;
        pool.accTokenPerShare = uint192(accTokenPerShare);
        // update pool last reward block
        pool.lastRewardBlock = uint64(block.number);
        return accTokenPerShare;
    }

    /**
     * @dev get pool reward
     */
    function _getPoolReward(uint256 tokenPerBlock, uint256 poolLastRewardBlock) private view returns (uint256) {
        return tokenPerBlock * (block.number - poolLastRewardBlock);
    }

    /**
     * @dev get the pending balance for one pool
     */
    function pendingAG(uint256 tokenId) external view returns (uint256 pending) {
        uint256 globalTokenId = MGPLibV2.hashTokenId(chainSymbol, address(_drifter), tokenId);
        (address contractAddress, uint256 poolId) = _tokenTracker.getTrace(globalTokenId);
        if (contractAddress == address(this)) (pending, , , , ) = _pendingAG(poolId, globalTokenId);
    }

    /**
     * @dev get the pending balance for one pool
     */
    function _pendingAG(uint256 pId, uint256 globalTokenId)
        private
        view
        returns (
            uint256 pending,
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
        if (pId == 0) miningOffsetBlocks = (miningOffsetBlocks * rtConsume) / rtConsumeFactorBase;
        if (miningOffsetBlocks >= remainingTime) miningOffsetBlocks = remainingTime;
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
        pending = ((pending * agPriceFactor) * pools[pId].agPerBlock) / incomeDecreaseFactorBase / agPriceFactorBase;
    }

    /**
     * @dev pending token of a token
     */
    function pendingDGT(uint256 tokenId) external view returns (uint256 pending) {
        uint256 globalTokenId = MGPLibV2.hashTokenId(chainSymbol, address(_drifter), tokenId);
        (address contractAddress, uint256 poolId) = _tokenTracker.getTrace(globalTokenId);
        if (contractAddress == address(this)) {
            Miner storage miner = miners[globalTokenId];
            StakingPool storage pool = pools[poolId];
            uint256 accTokenPerShare = pool.accTokenPerShare;
            if (pool.totalDGPPoints > 0) {
                uint256 tokenReward = _getPoolReward(pool.dgtPerBlock, pool.lastRewardBlock);
                accTokenPerShare += (tokenReward * acc1e12) / pool.totalDGPPoints;
            }
            pending = (miner.dgtPoint * accTokenPerShare) / acc1e12 - miner.rewardDebt;
        }
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

    function _mintAG(address account, uint256 amount) private {
        if (amount > 0) _AG.mint(account, (amount * 95) / 100);
    }

    function _mintDGT(address account, uint256 amount) private {
        if (amount > 0) _DGT.transfer(account, amount);
    }
}
