// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC777/IERC777.sol";

interface IDG777 is IERC777 {
    function mint(
        address account,
        uint256 amount,
        bytes memory data
    ) external;
}
