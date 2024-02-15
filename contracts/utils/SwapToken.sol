// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SwapToken is Ownable {
    using SafeERC20 for IERC20;

    //address of the uniswap v2 router
    address private constant PANCAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    //address of WBNB token.  This is needed because some times it is better to trade through WBNB.
    //you might get a better price using WBNB.
    //example trading from token A to WBNB then WBNB to token B might result in a better price
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    uint256 private constant PERCENT_BASE = 100;
    uint256 public feePercent = 5;

    // set percentage of tx fee
    function setFeePercent(uint256 percent) external onlyOwner {
        require(percent < PERCENT_BASE, "percent should < 100");
        feePercent = percent;
    }

    //this swap function is used to trade from one token to another
    //the inputs are self explainatory
    //token in = the token address you want to trade out of
    //token out = the token address you want as the output of this trade
    //amount in = the amount of tokens you are sending in
    //amount out Min = the minimum amount of tokens you want out of the trade
    function swap(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) external {
        //first we need to transfer the amount in tokens from the msg.sender to this contract
        //this contract will have the amount of in tokens
        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        uint256 feeFreeAmountIn;
        if (feePercent > 0) {
            // calculate fee
            feeFreeAmountIn = _amountIn * PERCENT_BASE / (PERCENT_BASE + feePercent);
            uint256 fee = _amountIn  - feeFreeAmountIn;
            IERC20(_tokenIn).safeTransfer(owner(), fee);
        } else feeFreeAmountIn = _amountIn;

        //next we need to allow the uniswapv2 router to spend the token we just sent to this contract
        //by calling IERC20 approve you allow the uniswap contract to spend the tokens in this contract
        IERC20(_tokenIn).approve(PANCAKE_V2_ROUTER, feeFreeAmountIn);

        //path is an array of addresses.
        //this path array will have 3 addresses [tokenIn, WBNB, tokenOut]
        //the if statement below takes into account if token in or token out is WBNB.  then the path is only 2 addresses
        address[] memory path;
        if (_tokenIn == WBNB || _tokenOut == WBNB) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WBNB;
            path[2] = _tokenOut;
        }
        //then we will call swapExactTokensForTokens
        //for the deadline we will pass in block.timestamp
        //the deadline is the latest time the trade is valid for
        IUniswapV2Router(PANCAKE_V2_ROUTER).swapExactTokensForTokens(feeFreeAmountIn, _amountOutMin, path, msg.sender, block.timestamp);
    }

    //this function will return the minimum amount from a swap
    //input the 3 parameters below and it will return the minimum amount out
    //this is needed for the swap function above
    function getAmountOutMin(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) external view returns (uint256) {
        //path is an array of addresses.
        //this path array will have 3 addresses [tokenIn, WBNB, tokenOut]
        //the if statement below takes into account if token in or token out is WBNB.  then the path is only 2 addresses
        address[] memory path;
        if (_tokenIn == WBNB || _tokenOut == WBNB) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WBNB;
            path[2] = _tokenOut;
        }

        uint256[] memory amountOutMins = IUniswapV2Router(PANCAKE_V2_ROUTER).getAmountsOut(_amountIn, path);
        // add fees
        return (amountOutMins[path.length - 1] * (PERCENT_BASE + feePercent)) / PERCENT_BASE;
    }
}

//import the uniswap router
//the contract needs to use swapExactTokensForTokens
//this will allow us to import swapExactTokensForTokens into our contract

interface IUniswapV2Router {
    function getAmountsOut(uint256 amountIn, address[] memory path) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        //amount of tokens we are sending in
        uint256 amountIn,
        //the minimum amount of tokens we want out of the trade
        uint256 amountOutMin,
        //list of token addresses we are going to trade in.  this is necessary to calculate amounts
        address[] calldata path,
        //this is the address we are going to send the output tokens to
        address to,
        //the last time that the trade is valid for
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external returns (address);
}
