// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";
import "../interfaces/ICharacterRegistry.sol";

contract TrainingDummy is ERC721A, Ownable {
    using Strings for uint256;
    using Address for address;

    ICharacterRegistry private _charaRegistry;

    constructor(
        address charaRegistry_ 
    ) ERC721A("Godland Training Dummy", "GDLTD") {
        _charaRegistry = ICharacterRegistry(charaRegistry_);
    }

    function mintTarget(uint256 count) external onlyOwner {
        uint256 startId = _currentIndex;
        _mint(msg.sender, count, "", false);
        for (uint256 index = 0; index < count; ++index) _charaRegistry.initAsCharacter("BSC", address(this), startId + index, 1, 0);
    }
}
