// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IERC1155Minter.sol";
import "../../interfaces/ICharacterRegistry.sol";
import "../../library/MGPLibV2.sol";
import "../../RandomBase.sol";
import "../IVersusImpl.sol";

contract VersusImplV1 is RandomBase, IVersusImpl {
    uint256 public constant newYearGGId = 200;

    ICharacterRegistry private immutable _characterRegistry;
    IERC1155Minter private immutable _godGadget;

    event VersusDBG(uint256 fighterATK, uint256 opponentATK, uint256 fighterHP, uint256 opponentHP, uint256 fBase, uint256 oBase);

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
        uint256 mainPropertyIdx = roundRandomBase % 3;
        uint256 fighterATK;
        uint256 opponentATK;
        uint256 fighterHP;
        uint256 opponentHP;
        {
            uint256 fBase;
            uint256 oBase;
            (fighterATK, fighterHP) = _getVersusStats(fighterId, mainPropertyIdx);
            (opponentATK, opponentHP) = _getVersusStats(opponentId, mainPropertyIdx);
            uint256 roundRandom = _hashUint(roundRandomBase);
            if (_godGadget.balanceOf(account, newYearGGId) > 0) {
                fBase = ((roundRandom % 100) + 10) / 20;
                if (fBase > 4) fBase = 4;
                fighterATK = (fBase * 50 * fighterATK) / 100 + 1;
            } else {
                fBase = roundRandom % 5;
                fighterATK = (fBase * 50 * fighterATK) / 100 + 1;
            }
            roundRandom = _hashUint(roundRandom);
            oBase = roundRandom % 5;
            opponentATK = (oBase * 50 * opponentATK) / 100 + 1;
            emit VersusDBG(fighterATK, opponentATK, fighterHP, opponentHP, fBase, oBase);
        }
        uint256 fighterRounds = opponentHP / fighterATK;
        uint256 opponentRounds = fighterHP / opponentATK;
        isWin = fighterRounds <= opponentRounds;
    }

    function _hashUint(uint256 seed) private pure returns (uint256) {
        bytes memory data = new bytes(32);
        assembly {
            mstore(add(data, 32), seed)
        }
        return uint256(keccak256(data));
    }

    function _getVersusStats(uint256 globalTokenId, uint256 mainPropertyIdx) private view returns (uint256 atk, uint256 hp) {
        uint256 str;
        uint256 agi;
        uint256 intl;
        uint256 vit;
        (, , , , str, agi, intl, hp, vit, ) = MGPLibV2.decodeCharacterLevel(_characterRegistry.characterStats(globalTokenId));
        hp = hp * 15 + (str + agi + intl + vit) * 3;
        if (mainPropertyIdx == 0) atk = str;
        else if (mainPropertyIdx == 1) atk = agi;
        else atk = intl;
    }
}
