// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/ICharacterRegistry.sol";
import "../library/MGPLibV2.sol";

contract CharacterAddition {
    using MGPLibV2 for uint256;

    ICharacterRegistry private immutable _charaRegistery;

    constructor(address charaRegistery_) {
        _charaRegistery = ICharacterRegistry(charaRegistery_);
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
}
