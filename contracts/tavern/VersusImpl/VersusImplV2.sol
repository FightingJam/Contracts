// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IERC1155Minter.sol";
import "../../interfaces/ICharacterRegistry.sol";
import "../../library/MGPLibV2.sol";
import "../../RandomBase.sol";
import "../IVersusImpl.sol";

contract VersusImplV2 is RandomBase, IVersusImpl {
    uint256 public constant newYearGGId = 200;
    uint256 public constant totalPercentage = 100;
    uint256 public constant fighterWinPercentage = 55;
    uint256 public constant rankDiff = 2;
    uint256 public constant newYearGGAddition = 6;

    ICharacterRegistry private immutable _characterRegistry;
    IERC1155Minter private immutable _godGadget;

    event VersusDBG(uint256 fRarity, uint256 oRarity, uint256 winPercentage, uint256 ranBase);

    constructor(
        address randomizer_,
        address godGadget_,
        address characterRegistry_
    ) RandomBase(randomizer_) {
        _characterRegistry = ICharacterRegistry(characterRegistry_);
        _godGadget = IERC1155Minter(godGadget_);
    }

    function versus(
        address account,
        uint256 fighterId,
        uint256 opponentId
    ) external override returns (uint256 roundRandomBase, bool isWin) {
        roundRandomBase = _genRandomNumber();
        (uint256 fRarity, , , , ) = MGPLibV2.decodeCharacterBasic(_characterRegistry.characterStats(fighterId));
        (uint256 oRarity, , , , ) = MGPLibV2.decodeCharacterBasic(_characterRegistry.characterStats(opponentId));
        uint256 winPercentage = fighterWinPercentage;
        if (fRarity >= oRarity) winPercentage += (fRarity - oRarity) * rankDiff;
        else winPercentage -= (oRarity - fRarity) * rankDiff;
        if (_godGadget.balanceOf(account, newYearGGId) > 0) winPercentage += newYearGGAddition;
        isWin = roundRandomBase % totalPercentage < winPercentage;
        emit VersusDBG(fRarity, oRarity, winPercentage, roundRandomBase % totalPercentage);
    }
}
