// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2RouterPartial {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract SwapTokenFull is Ownable, IUniswapV2RouterPartial {
    using SafeERC20 for IERC20;

    //address of the uniswap v2 router
    address private constant PANCAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    uint256 private constant PERCENT_BASE = 100;
    uint256 public feePercent = 5;

    // set percentage of tx fee
    function setFeePercent(uint256 percent) external onlyOwner {
        require(percent < PERCENT_BASE, "percent should < 100");
        feePercent = percent;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(amountIn);
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountIn);
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapExactTokensForTokens(feeFreeAmountIn, amountOutMin, path, to, deadline);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountInMax);
        uint256 feeFreeAmountInMax = calculateFeeFreeAmountIn(amountInMax);
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountInMax);
        amounts = IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapTokensForExactTokens(amountOut, feeFreeAmountInMax, path, to, deadline);
        uint256 fee = feeForAmountIn(amounts[0]);
        uint256 fractions = amountInMax - fee - amounts[0];
        if (fractions > 0) IERC20(path[0]).safeTransfer(msg.sender, fractions);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(msg.value); 
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapExactETHForTokens{value: feeFreeAmountIn}(amountOutMin, path, to, deadline);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountInMax);
        uint256 feeFreeAmountInMax = calculateFeeFreeAmountIn(amountInMax);
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountInMax);
        amounts = IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapTokensForExactETH(amountOut, feeFreeAmountInMax, path, to, deadline);
        uint256 fee = feeForAmountIn(amounts[0]);
        uint256 fractions = amountInMax - fee - amounts[0];
        if (fractions > 0) IERC20(path[0]).safeTransfer(msg.sender, fractions);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(amountIn);
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountIn);
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapTokensForExactETH(feeFreeAmountIn, amountOutMin, path, to, deadline);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        uint256 feeFreeAmountInMax = calculateFeeFreeAmountIn(msg.value);
        amounts = IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapETHForExactTokens{value: feeFreeAmountInMax}(amountOut, path, to, deadline);
        uint256 fee = feeForAmountIn(amounts[0]);
        uint256 fractions = msg.value - fee - amounts[0];
        if (fractions > 0) payable(msg.sender).transfer(fractions);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(amountIn);
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountIn);
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapExactTokensForTokensSupportingFeeOnTransferTokens(feeFreeAmountIn, amountOutMin, path, to, deadline);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(msg.value);
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapExactETHForTokensSupportingFeeOnTransferTokens{value: feeFreeAmountIn}(amountOutMin, path, to, deadline);
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        uint256 feeFreeAmountIn = calculateFeeFreeAmountIn(amountIn); 
        IERC20(path[0]).approve(PANCAKE_V2_ROUTER, feeFreeAmountIn);
        return IUniswapV2RouterPartial(PANCAKE_V2_ROUTER).swapExactTokensForETHSupportingFeeOnTransferTokens(feeFreeAmountIn, amountOutMin, path, to, deadline);
    }

    function withdrawFees(address[] calldata tokenAddr) external {
        address _owner = owner();
        {
            uint256 ethers = address(this).balance;
            if (ethers > 0) payable(_owner).transfer(ethers);
        }
        unchecked {
            for (uint256 index = 0; index < tokenAddr.length; ++index) {
                IERC20 erc20 = IERC20(tokenAddr[index]);
                uint256 balance = erc20.balanceOf(address(this));
                if (balance > 0) erc20.safeTransfer(_owner, balance);
            }
        }
    }

    function feeForAmountIn(uint256 amountIn) public view returns (uint256 fee) {
        fee = (amountIn * feePercent) / PERCENT_BASE;
    }

    function calculateAmountIn(uint256 feeFreeAmountIn) public view returns (uint256 amountIn) {
        amountIn = (feeFreeAmountIn * (feePercent + PERCENT_BASE)) / PERCENT_BASE;
    }

    function calculateFeeFreeAmountIn(uint256 amountIn) public view returns (uint256 feeFreeAmountIn) {
        feeFreeAmountIn = (amountIn * PERCENT_BASE) / (feePercent + PERCENT_BASE);
    }

    receive() external payable {}
}
