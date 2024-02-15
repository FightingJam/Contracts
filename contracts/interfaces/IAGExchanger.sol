// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAGExchanger {
    function estimateBNB2AG(uint256 amount) external pure returns (uint256 exchanged);

    function exchangeAG(address to) external payable returns (uint256 exchanged);

    function estimateAG2BNB(uint256 amount) external pure returns (uint256 exchanged);

    function exchangeBNB(uint256 amount) external returns (uint256 exchanged);
}
