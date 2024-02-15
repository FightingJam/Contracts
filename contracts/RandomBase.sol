// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IRandomizer.sol";

abstract contract RandomBase {
    IRandomizer private _randomizer;

    constructor(address randomizer_) {
        _randomizer = IRandomizer(randomizer_);
    }

    function _genRandomNumber() internal returns (uint256) {
        return _randomizer.genRandomNumber();
    }
}
