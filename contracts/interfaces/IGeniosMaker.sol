// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IGeniosMaker {
    function geniosInfo(uint256 genios)
        external
        pure
        returns (
            uint256 season,
            uint256 rarity,
            uint256[] memory parts
        );
}
