// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/OperatorGuard.sol";
import "../interfaces/ITokenAuxiliary.sol";

contract TokenAuxiliary is OperatorGuard, ITokenAuxiliary {
    IUsefulPorts private immutable _previousGame;
    IUsefulPorts private immutable _dgtProvider;

    mapping(address => uint256) _consumedDGT;
    mapping(address => uint256) _addedDGT;
    mapping(address => uint256) _userRunes;

    constructor(address previousVersion_, address dgtProvider_) {
        _previousGame = IUsefulPorts(previousVersion_);
        _dgtProvider = IUsefulPorts(dgtProvider_);
    }

    function userRunes(address account) external view override returns (uint256[] memory amounts) {
        uint256 runes = _userRunes[account];
        amounts = new uint256[](9);
        if (runes > 0) {
            for (uint256 index = 0; index < 9; ++index) amounts[index] = uint24(runes >> (index * 24));
        } else {
            uint256[] memory frags = _previousGame.userFragments(account);
            for (uint256 index = 0; index < 9; ++index) amounts[index] = frags[index];
        }
    }

    function consumeRune(
        address account,
        uint256[] calldata runeIdx,
        uint256[] calldata amounts
    ) external override onlyOperator {
        uint256 runes = _userRunes[account];
        if (runes == 0) {
            // sync
            runes = 1 << 255;
            uint256[] memory runeAmounts = _previousGame.userFragments(account);
            for (uint256 index = 0; index < 9; ++index) runes += (runeAmounts[index] << (index * 24));
        }
        for (uint256 index = 0; index < runeIdx.length; ++index) {
            uint256 runeIdOffset = runeIdx[index] * 24;
            uint256 oneRune = uint24(runes >> runeIdOffset);
            require(oneRune >= amounts[index], "not enought runes");
            unchecked {
                runes -= (amounts[index]  << runeIdOffset);
            }
        }
        _userRunes[account] = runes;
    }

    function addRune(
        address account,
        uint256[] calldata runeIdx,
        uint256[] calldata amounts
    ) external override onlyOperator {
        uint256 runes = _userRunes[account];
        if (runes == 0) {
            // sync
            runes = 1 << 255;
            uint256[] memory runeAmounts = _previousGame.userFragments(account);
            for (uint256 index = 0; index < 9; ++index) runes += (runeAmounts[index] << (index * 24));
        }
        for (uint256 index = 0; index < runeIdx.length; ++index) {
            uint256 runeIdOffset = runeIdx[index] * 24;
            uint256 amount = amounts[index];
            uint256 oneRune = uint24(runes >> runeIdOffset);
            if (oneRune + amount > type(uint24).max) amount = type(uint24).max - oneRune;
            runes += (amount << runeIdOffset);
        }
        _userRunes[account] = runes;
    }

    function userDGT(address account) public view override returns (uint256 amount) {
        amount = _dgtProvider.userPendingDGTRest(account) + _addedDGT[account] - _consumedDGT[account];
    }

    function consumeDGT(address account, uint256 amount) external override onlyOperator {
        uint256 currentDGT = userDGT(account);
        require(currentDGT >= amount, "not enought DGT");
        _consumedDGT[account] += amount;
    }

    function addDGT(address account, uint256 amount) external override onlyOperator {
        _addedDGT[account] += amount;
    }
}

interface IUsefulPorts {
    function userFragments(address account) external view returns (uint256[] memory amounts);

    function userPendingDGTRest(address account) external view returns (uint256);
}
