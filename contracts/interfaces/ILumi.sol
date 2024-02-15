// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILumi is IERC20 {
    function mint(address account, uint256 amount) external;

    function mintBatch(address[] calldata accounts, uint256[] calldata amounts) external;

    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}
