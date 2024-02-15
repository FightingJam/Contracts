// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IDrifterUpdatedHandler.sol";
import "../interfaces/IDrifterRegistery.sol";
import "../interfaces/ITokenPoolTracker.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/IDG721.sol";
import "../library/MGPLib.sol";
import "../utils/OperatorGuard.sol";
import "../RandomBase.sol";
import "../interfaces/IDrifterOperations.sol";

contract PvE {
    event Expedition(address indexed account, uint256 tokenId, uint256 adventure);

    address private constant zeroAddress = address(0x0);

    struct PvERequirement {
        uint16 minRarity;
        uint16 minRank;
        uint16 minLevel;
    }

    IDG721 private immutable _drifter;
    IDrifterRegistery private immutable _drifterRegistery;
    ITokenPoolTracker private immutable _tokenTracker;

    uint16 private _tokenStamina = 5;
    uint16 private _tokenRechargeDelay = 7200;

    // token => block
    mapping(uint256 => uint256) public tokenRechargedBlock;

    PvERequirement[] public advRequirements;

    constructor(
        address drifter_,
        address drifterRegistery_,
        address tokenTracker_
    ) {
        _drifter = IDG721(drifter_);
        _drifterRegistery = IDrifterRegistery(drifterRegistery_);
        _tokenTracker = ITokenPoolTracker(tokenTracker_);
    }

    function _initDev() private {
        advRequirements.push(PvERequirement({minRarity: 1, minRank: 0, minLevel: 1}));
        advRequirements.push(PvERequirement({minRarity: 1, minRank: 1, minLevel: 1}));
    }

    function goHunt(uint256 tokenId, uint256 adventure) external ensureTokenOwner(tokenId) {
        _setTokenRechargeBlock(tokenId);
        (uint8 rarity, uint8 rank, uint8 level, , , , , , , , , ) = MGPLib.decodeDrifter(_drifterRegistery.drifterStats(tokenId));
        PvERequirement storage requirement = advRequirements[adventure];
        require(rarity >= requirement.minRarity && rank >= requirement.minRank && level >= requirement.minLevel, "not match the minimal requirements");
        emit Expedition(msg.sender, tokenId, adventure);
    }

    function _setTokenRechargeBlock(uint256 tokenId) private {
        uint256 defTokenStamina = _tokenStamina - 1;
        uint256 tokenRechargeDelay = _tokenRechargeDelay;

        uint256 tokenRechargedBlock_ = tokenRechargedBlock[tokenId];
        if (tokenRechargedBlock_ <= block.number) {
            tokenRechargedBlock_ = block.number;
        } else {
            require(tokenRechargedBlock_ <= block.number + defTokenStamina * tokenRechargeDelay, "token not recharged");
        }
        tokenRechargedBlock[tokenId] = tokenRechargedBlock_ + tokenRechargeDelay;
    }

    modifier ensureTokenOwner(uint256 tokenId) {
        (address contractAddress, uint256 poolId) = _tokenTracker.getTrace(address(_drifter), tokenId);
        if (contractAddress != zeroAddress) require(IDrifterUpdatedHandler(contractAddress).isTokenOwner(poolId, msg.sender, tokenId), "token not belongs to user");
        else require(_drifter.ownerOf(tokenId) == msg.sender);
        _;
    }
}
