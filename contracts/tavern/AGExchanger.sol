// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/OperatorGuard.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/IAGExchanger.sol";

contract AGExchanger is OperatorGuard, IAGExchanger {
    using SafeERC20 for IERC20;

    // Emit when an operator exchange BNB to AG
    event ExchangeAG(address indexed to, address indexed operator, uint256 agAmount);
    // Emit when an user exchange AG to BNB
    event ExchangeBNB(address indexed to, uint256 agAmount);

    event AddDGTDispatchAmount(uint256 addition);
    event PostponeWithdrawBlock(uint256 newWithdrawEndBlock);

    // fixed convert rate from BNB to DGT
    uint256 public constant BNB_TO_DGT = 4000;

    // fixed convert rate from BNB to Acient Gold
    uint256 public constant BNB_TO_AG = 20000;

    uint256 private constant _pAcc1e18 = 1e18;
    uint256 private constant _totalPercentage = 100;
    uint256 private constant _totalDiv = _totalPercentage * _pAcc1e18;
    uint256 private constant _base = 10 * _pAcc1e18;
    uint256 private constant _offSet = 40 * _pAcc1e18;

    // minimal AG to change with
    uint256 public constant exchangeBNBMinimal = 500 ether;

    // total dgp shall dispatched, might increase in future
    uint256 public dgtDispatchTotal = 2000000 ether;
    uint256 public dgtDispatchRest = 2000000 ether;
    mapping(address => uint256) public userDGTPreview;
    IDG20 public immutable ag;

    // User can exchange AG for BNB before this block, might be postponed in considering of project progression
    // Block 15666150, appox. Tue Mar 01 2022 00:00:00 GMT+0000
    uint32 public withdrawEndBlock = 15666150;

    // true for indicate exchange from ag to BNB is started
    bool public isExChangeStarted;

    constructor(address ag_) {
        ag = IDG20(ag_);
    }

    function setStartExchange() external onlyOwner {
        isExChangeStarted = true;
    }

    /**
     * @dev Add more DGT to the pool
     * @param addition the amount that added to DGT dispatchs
     */
    function addDGTDispatchAmount(uint256 addition) external onlyOwner {
        dgtDispatchTotal += addition;
        dgtDispatchRest += addition;
        emit AddDGTDispatchAmount(addition);
    }

    /**
     * @dev Postpone withdraw block
     * @param newWithdrawEndBlock the new withdraw block, should greater than current withdraw block
     */
    function postponeWithdrawBlock(uint32 newWithdrawEndBlock) external onlyOwner {
        require(newWithdrawEndBlock > withdrawEndBlock, "new withdraw block should > current withdraw block");
        withdrawEndBlock = newWithdrawEndBlock;
        emit PostponeWithdrawBlock(newWithdrawEndBlock);
    }

    /**
     * @dev Estimate how many DGT should be claimed when buying AG using BNB
     * @param bnbAmount BNB amount
     */
    function estimateBNBToDGT(uint256 bnbAmount) public view returns (uint256 dgtPreview) {
        // (10% + (percentage of rest DGT pool) * 40%) * dgtAmount
        dgtPreview = ((_base + (dgtDispatchRest * _offSet) / dgtDispatchTotal) * bnbAmount * BNB_TO_DGT) / _totalDiv;
        if (dgtPreview > dgtDispatchTotal) dgtPreview = dgtDispatchRest;
    }

    /**
     * @dev Estimate how many AG should be claimed in exchange of BNB
     * @param bnbAmount BNB amount
     */
    function estimateBNB2AG(uint256 bnbAmount) public pure override returns (uint256 agAmount) {
        agAmount = bnbAmount * BNB_TO_AG;
    }

    /**
     * @dev Estimate how many AG and DGT should be claimed in exchange of BNB
     * @param bnbAmount BNB amount
     */
    function estimateBNB2AGnDGT(uint256 bnbAmount) public view returns (uint256 agAmount, uint256 dgtAmount) {
        agAmount = bnbAmount * BNB_TO_AG;
        dgtAmount = estimateBNBToDGT(bnbAmount);
    }

    /**
     * @dev Exchange AG from BNB, only can be operated by specified operator, user will get DGT as well.
     * DGT amount will stay in this contract, and can be minted in future by other contracts.
     * The exchanged AG will send to caller, in this case, the gaming contract.
     * @param proxyTo The real user who exchange AGs, and the dispatched DGT will be registed to this address.
     */
    function exchangeAG(address proxyTo) external payable override onlyOperator returns (uint256 exchanged) {
        exchanged = estimateBNB2AG(msg.value);
        ag.mint(msg.sender, exchanged);
        uint256 dgtPreview = estimateBNBToDGT(msg.value);
        dgtDispatchRest -= dgtPreview;
        userDGTPreview[proxyTo] += dgtPreview;
        emit ExchangeAG(proxyTo, msg.sender, exchanged);
    }

    /**
     * @dev Estimate how many BNB should be claimed in exchange of AG
     * @param agAmount AG amount
     */
    function estimateAG2BNB(uint256 agAmount) public pure override returns (uint256 bnbAmount) {
        bnbAmount = agAmount / BNB_TO_AG;
    }

    /**
     * @dev Estimate how many BNB and DGT should be claimed in exchange of AG
     * @param agAmount AG amount
     */
    function estimateAG2BNBnDGT(uint256 agAmount) public view returns (uint256 bnbAmount, uint256 dgtAmount) {
        bnbAmount = agAmount / BNB_TO_AG;
        dgtAmount = estimateBNBToDGT(bnbAmount);
    }

    /**
     * @dev Exchange AGs to BNB
     * @param amount AG amount
     */
    function exchangeBNB(uint256 amount) external override withdrawable returns (uint256 exchanged) {
        require(amount >= exchangeBNBMinimal, "Not enought to exchange");
        exchanged = estimateAG2BNB(amount);
        require(address(this).balance >= exchanged, "not enought BNB to withdraw?"); // this should never happens
        ag.burnFrom(msg.sender, amount);
        payable(msg.sender).transfer(exchanged);
        emit ExchangeBNB(msg.sender, amount);
    }

    /**
     * @dev simple recive function use to make a initial deposit
     */
    receive() external payable onlyOwner {}

    /**
     * @dev Withdral remaining BNB after withdraw end block
     * These BNBs is going to support liquidity pools
     */
    function withdraw() external onlyOwner {
        require(block.number >= withdrawEndBlock, "should > withdrawEndBlock");
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Check wheather user can exchange their BNB
     */
    modifier withdrawable() {
        require(isExChangeStarted, "exchange not started");
        require(block.number <= withdrawEndBlock, "already pass withdraw end block");
        _;
    }
}
