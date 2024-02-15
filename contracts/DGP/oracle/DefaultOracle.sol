// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../IDGPPointOracle.sol";

contract DefaultOracle is IDGPPointOracle {
    function getPoints(address, uint256) external pure override returns (uint256) {
        return 0;
    }
}
