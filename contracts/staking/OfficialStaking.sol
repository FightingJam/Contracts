// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDG721.sol";
import "../interfaces/IDG721BatchReceiver.sol";
import "./StakingBaseOfficial.sol";

contract OfficialStaking is Ownable, StakingBaseOfficial, IDG721BatchReceiver {
    using EnumerableSet for EnumerableSet.UintSet;

    constructor(
        address tokenTracker_,
        address drifter_,
        address ag_,
        address dgt_,
        address drifterRegistery_,
        address drifterOperations_
    ) StakingBaseOfficial(tokenTracker_, drifter_, ag_, dgt_, drifterRegistery_,drifterOperations_) {}

    function updateRTConsume(uint256 rtConsume_) external onlyOwner {
        _updateRTConsume(rtConsume_);
    }

    function updateAGPriceFactor(uint256 agPriceFactor_) external onlyOwner {
        _updateAGPriceFactor(agPriceFactor_);
    }

    function updateDGTRarityRatio(uint256 dgtRarityRatio_) external onlyOwner {
        _updateDGTRarityRatio(dgtRarityRatio_);
    }
 
    function updateIncomeDecrease(uint256 incomeDecrease_) external onlyOwner {
        _updateIncomeDecrease(incomeDecrease_);
    }

    function addPool(
        uint64 agPerBlock,
        uint64 dgtPerBlock,
        uint8 minRarity,
        uint8 minRank,
        uint8 initCount,
        address paidToken,
        uint256[] memory paidPrice
    ) external onlyOwner {
        _addPool(agPerBlock, dgtPerBlock, minRarity, minRank, initCount, paidToken, paidPrice);
    }

    function updatePool(
        uint256 pId,
        uint64 agPerBlock,
        uint64 dgtPerBlock,
        uint8 minRarity,
        uint8 minRank,
        uint8 initCount,
        address paidToken,
        uint256[] calldata paidPrice
    ) external onlyOwner {
        _updatePool(pId, agPerBlock, dgtPerBlock, minRarity, minRank, initCount, paidToken, paidPrice);
    }

    function withdraw(uint256 tokenId) external {
        _withdraw(tokenId);
        IDG721(_drifter).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function onERC721BatchReceived(
        address operator,
        address from,
        uint256[] calldata tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == _drifter, "only accept drifter transfer");
        require(tx.origin == from, "should call from owner only");
        require(operator == from, "should send from owner only");
        uint256 pId = abi.decode(data, (uint256));
        _deposit(pId, from, tokenId);
        return this.onERC721BatchReceived.selector;
    }

    modifier nonContractCaller() {
        require(tx.origin == msg.sender, "contract caller is not allowed");
        _;
    }
}
