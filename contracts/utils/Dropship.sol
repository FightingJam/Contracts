// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Dropship {
    using SafeERC20 for IERC20;

    function mainnetCurrencyBombardment(address[] calldata accounts, uint256[] calldata amounts) external payable {
        require(accounts.length == amounts.length, "accounts != amounts");
        uint256 sum;
        for (uint256 index = 0; index < accounts.length; ++index) {
            uint256 amount = amounts[index];
            payable(accounts[index]).transfer(amount);
            sum += amount;
        }
        if (msg.value > sum) payable(msg.sender).transfer(msg.value - sum);
    }

    function erc20bombardment(
        address tokenAddress,
        address[] calldata accounts,
        uint256[] calldata amounts
    ) external {
        require(accounts.length == amounts.length, "accounts != amounts");
        IERC20 token = IERC20(tokenAddress);
        uint256 transferIn;
        for (uint256 index = 0; index < accounts.length; ++index) {
            uint256 amount = amounts[index];
            transferIn += amount;
        }
        if (transferIn > 0) {
            token.safeTransferFrom(msg.sender, address(this), transferIn);
            for (uint256 index = 0; index < accounts.length; ++index) {
                uint256 amount = amounts[index];
                token.safeTransfer(accounts[index], amount);
            }
        }
    }

    function erc20bombardmentV2(
        address tokenAddress,
        address[] calldata accounts,
        uint256[] calldata amounts,
        uint256 totalAmount
    ) external {
        uint256 length = accounts.length;
        require(length == amounts.length, "accounts != amounts");
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), totalAmount);
        for (uint256 index = 0; index < length; ++index) 
            token.safeTransfer(accounts[index], amounts[index]);  
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) token.safeTransfer(msg.sender, balance);
    }

    function erc721bombardment(
        address tokenAddress,
        address[] calldata accounts,
        uint256[] calldata ids
    ) external {
        require(accounts.length == ids.length, "accounts != ids");
        IERC721 token = IERC721(tokenAddress);
        for (uint256 index = 0; index < accounts.length; ++index) {
            token.safeTransferFrom(msg.sender, accounts[index], ids[index]);
        }
    }

    function erc1155bombardment(
        address tokenAddress,
        address[] calldata accounts,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        require(accounts.length == ids.length, "accounts != ids");
        require(accounts.length == ids.length, "accounts != amounts");
        IERC1155 token = IERC1155(tokenAddress);
        for (uint256 index = 0; index < accounts.length; ++index) {
            token.safeTransferFrom(msg.sender, accounts[index], ids[index], amounts[index], "");
        }
    }
}
