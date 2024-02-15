// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC4610.sol";

interface IERC4610Mintable is IERC4610 {
    function mint(address to, uint256 amount) external returns (uint startTokenId);
}
