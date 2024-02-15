// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IExperienceStrategy.sol";
import "../../access/DGPAccessable.sol";

contract CommonExpStrategy is IExperienceStrategy {
    function getExperience(uint256 level) external pure override returns (uint256) {
        return (level + 1) * 1 ether;
    }
}
