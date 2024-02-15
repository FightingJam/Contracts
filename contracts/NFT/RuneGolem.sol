// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./DG4610Simple.sol";
import "../interfaces/ITokenAuxiliary.sol";

contract RuneGolem is DG4610Simple {
    ITokenAuxiliary private immutable _tokenProvider;
    uint256 public runesRequirement = 10;
    uint256 public maxCountId = 500;
    mapping(address => uint256) public userMinted;

    constructor(address tokenProvider_) DG4610Simple("Godland Rune Golem", "GDLRG") {
        _tokenProvider = ITokenAuxiliary(tokenProvider_);
        tokenIdCounter = 1;
    }

    function setRunesRequirement(uint256 runesRequirement_) external onlyOwner {
        runesRequirement = runesRequirement_;
    }

    function setMaxCountId(uint256 maxCounterId_) external onlyOwner {
        maxCountId = maxCounterId_;
    }

    function makeGolem() external {
        require(userMinted[msg.sender] == 0, "already minted");
        require(tokenIdCounter < maxCountId, "cannot mint anymore");
        uint256 runeSum;
        uint256[] memory runes = _tokenProvider.userRunes(msg.sender);
        for (uint256 index = 9; index > 0; ) {
            runeSum += runes[--index];
            if (runeSum >= runesRequirement) {
                userMinted[msg.sender] = tokenIdCounter;
                _mint(msg.sender);
                return;
            }
        }
        revert("not enought runes");
    }
}
