// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";

contract TransferTest is IERC777Recipient {
    using SafeERC20 for IERC20;

    IERC1820Registry private constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant _TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    constructor() {
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), _TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    function pullERC20(address tokenAddress, uint256 amount) external {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    function tokensReceived(
        address,
        address from,
        address,
        uint256 payedAmount,
        bytes calldata userData,
        bytes calldata
    ) external override {}
}
