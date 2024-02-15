// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "../interfaces/IERC1155Minter.sol";

contract MysteryBoxMarket is Ownable, ERC1155Receiver {
    using SafeERC20 for IERC20;

    address public constant mainnetTokenAddress = address(0x0);
    address public constant pendingDGTAddress = address(0x1);
    event PlanUpdated(uint256 indexed planId);
    event Purchased(uint256 indexed planId, address indexed buyer, address payToken, uint256 unitPrice, uint256 amount);
    event JoinWhitelist(uint256 indexed whitelistId, address indexed account, uint256 tokenId, uint256 amount);

    struct SellPlan {
        address tokenAddress;
        uint96 unitPrice;
        uint96 unitDGTPrice;
        uint32 tokenId;
        uint32 supply;
        uint32 rest;
        uint8 maxPurchaseOnce;
        bool isSellable;
        uint8 maxPurchasePerAccount; // 0 for unlimited
        uint8 whitelistId; // whitelist id, 0 for not needs whitelist
    }

    struct WhitelistInfo {
        uint32 tokenId;
        uint32 amount;
    }

    address public immutable godGadget;

    // whitelistId(>0) => account => status
    mapping(uint256 => mapping(address => bool)) public whitelist;

    // whitelistId(>0) => WhitelistInfo
    mapping(uint256 => WhitelistInfo) public whitelistInfo;

    // planId => account => remains
    mapping(uint256 => mapping(address => uint256)) public planPurchased;
    // account => used pending DGT
    mapping(address => uint256) public usedPendingDGT;

    SellPlan[] public sellPlans;
    address public feeReciver;

    IRuneStakingPort public immutable runeStaking;
    IAGExchangerPort public immutable agExchanger;

    constructor(
        address godGadget_,
        address feeReciver_,
        address runeStaking_,
        address agExchanger_
    ) {
        godGadget = godGadget_;
        feeReciver = feeReciver_;
        runeStaking = IRuneStakingPort(runeStaking_);
        agExchanger = IAGExchangerPort(agExchanger_);
    }

    function setFeeReciver(address feeReciver_) external onlyOwner {
        feeReciver = feeReciver_;
    }

    function updateWhitelistInfo(
        uint256 whitelistId,
        uint32 consumedTokenId,
        uint32 amount
    ) external onlyOwner {
        whitelistInfo[whitelistId].tokenId = consumedTokenId;
        whitelistInfo[whitelistId].amount = amount;
    }

    function _joinWhitelist(
        address account,
        uint256 whitelistId,
        uint256 tokenId,
        uint256 amount
    ) private {
        require(whitelistId >= 1, "whitelist id should >= 1");
        require(!whitelist[whitelistId][account], "already in whitelist");
        require(whitelistInfo[whitelistId].tokenId == tokenId, "token not suitable");
        require(whitelistInfo[whitelistId].amount == amount, "token amount not collect");
        whitelist[whitelistId][account] = true;
        emit JoinWhitelist(whitelistId, account, tokenId, amount);
    }

    function createSellPlan(
        address tokenAddress,
        uint96 unitPrice,
        uint96 unitDGTPrice,
        uint32 tokenId,
        uint32 supply,
        uint8 maxPurchaseOnce,
        uint8 maxPurchasePerAccount,
        uint8 whitelistId
    ) external onlyOwner {
        uint256 planId = sellPlans.length;
        sellPlans.push(
            SellPlan({
                tokenAddress: tokenAddress,
                unitPrice: unitPrice,
                unitDGTPrice: unitDGTPrice,
                tokenId: tokenId,
                supply: supply,
                rest: supply,
                maxPurchaseOnce: maxPurchaseOnce,
                isSellable: false,
                maxPurchasePerAccount: maxPurchasePerAccount,
                whitelistId: whitelistId
            })
        );
        emit PlanUpdated(planId);
    }

    function addSellPlanRestBatch(uint256[] calldata planIds, uint32[] calldata supplyAdditions) external onlyOwner {
        for (uint256 index = 0; index < planIds.length; ++index) {
            uint256 planId = planIds[index];
            uint32 addition = supplyAdditions[index];
            sellPlans[planId].supply += addition;
            sellPlans[planId].rest += addition;
            emit PlanUpdated(planId);
        }
    }

    function updateSellPlan(
        uint256 planId,
        address tokenAddress,
        uint96 unitPrice,
        uint96 unitDGTPrice,
        uint32 supply,
        uint8 maxPurchaseOnce,
        uint8 maxPurchasePerAccount,
        uint8 whitelistId
    ) external onlyOwner {
        uint256 oldSupply = sellPlans[planId].supply;
        if (oldSupply != 0) {
            if (supply >= oldSupply) {
                sellPlans[planId].rest += uint32(supply - oldSupply);
            } else if (supply != 0) {
                require(sellPlans[planId].rest >= oldSupply - supply, "not enough rest");
                sellPlans[planId].rest -= uint32(oldSupply - supply);
            }
        }
        sellPlans[planId].tokenAddress = tokenAddress;
        sellPlans[planId].unitPrice = unitPrice;
        sellPlans[planId].unitDGTPrice = unitDGTPrice;
        sellPlans[planId].supply = supply;
        sellPlans[planId].maxPurchaseOnce = maxPurchaseOnce;
        sellPlans[planId].maxPurchasePerAccount = maxPurchasePerAccount;
        sellPlans[planId].whitelistId = whitelistId;
        emit PlanUpdated(planId);
    }

    function planCount() external view returns (uint256) {
        return sellPlans.length;
    }

    function makePlanSaleable(uint256[] calldata planIds, bool[] memory isSellables) external onlyOwner {
        for (uint256 index = 0; index < planIds.length; ++index) {
            uint256 planId = planIds[index];
            bool sellable = isSellables[index];
            sellPlans[planId].isSellable = sellable && sellPlans[planId].rest > 0;
            emit PlanUpdated(planId);
        }
    }

    function purchaseBox(uint256 planId, uint256 amount) external payable nonContractCaller {
        address account = msg.sender;
        _purchase(account, planId, amount);
        uint256 unitPrice = sellPlans[planId].unitPrice;
        address tokenAddress = sellPlans[planId].tokenAddress;
        uint256 shouldPayed = unitPrice * amount;
        if (tokenAddress == mainnetTokenAddress) {
            if (msg.value > shouldPayed) payable(account).transfer(msg.value - shouldPayed);
            else if (msg.value < shouldPayed) revert("not enought payed");
            payable(feeReciver).transfer(shouldPayed);
        } else {
            IERC20(tokenAddress).safeTransferFrom(account, feeReciver, shouldPayed);
        }
        IERC1155Minter(godGadget).mint(account, sellPlans[planId].tokenId, amount, "");
        emit Purchased(planId, account, tokenAddress, unitPrice, amount);
    }

    function purchaseBoxDGT(uint256 planId, uint256 amount) external nonContractCaller {
        address account = msg.sender;
        _purchase(account, planId, amount);
        uint256 unitDGTPrice = sellPlans[planId].unitDGTPrice;
        require(unitDGTPrice > 0, "cannot purchase by DGT");
        uint256 shouldPayed = unitDGTPrice * amount;
        uint256 pendingDGTRest = userPendingDGTRest(account);
        require(pendingDGTRest >= shouldPayed, "not enought pending DGT");
        usedPendingDGT[account] += shouldPayed;
        IERC1155Minter(godGadget).mint(account, sellPlans[planId].tokenId, amount, "");
        emit Purchased(planId, account, pendingDGTAddress, unitDGTPrice, amount);
    }

    function _purchase(
        address account,
        uint256 planId,
        uint256 amount
    ) private {
        require(sellPlans[planId].maxPurchaseOnce >= amount, "reach max purchase per transaction");
        require(sellPlans[planId].isSellable, "cannot purchase");
        {
            uint256 whitelistId = sellPlans[planId].whitelistId;
            if (whitelistId > 0) require(whitelist[whitelistId][account], "not in whitelist");
            uint256 maxPurchasePerAccount = sellPlans[planId].maxPurchasePerAccount;
            if (maxPurchasePerAccount != 0) {
                uint256 purchased = planPurchased[planId][account];
                require(purchased + amount <= maxPurchasePerAccount, "exceed max purchase per account");
                unchecked {
                    planPurchased[planId][account] = purchased + amount;
                }
            }
            uint256 rest = sellPlans[planId].rest;
            require(rest >= amount, "not stock to sell");
            unchecked {
                rest -= amount;
            }
            sellPlans[planId].rest = uint32(rest);
            if (rest == 0) {
                sellPlans[planId].isSellable = false;
                emit PlanUpdated(planId);
            }
        }
    }

    function userPendingDGTRest(address account) public view returns (uint256) {
        return runeStaking.pendingToken(account) + agExchanger.userDGTPreview(account) - usedPendingDGT[account];
    }

    function sellPlanBatch(uint256[] calldata planIds)
        external
        view
        returns (
            address[] memory tokenAddresses,
            uint96[] memory unitPrices,
            uint96[] memory unitDGTPrices,
            uint32[] memory tokenIds,
            uint32[] memory supplies,
            uint32[] memory rest,
            uint8[] memory maxPurchaseOnce,
            bool[] memory isSellable,
            uint8[] memory maxPurchasePerAccount,
            uint8[] memory whitelistIds
        )
    {
        tokenAddresses = new address[](planIds.length);
        unitPrices = new uint96[](planIds.length);
        unitDGTPrices = new uint96[](planIds.length);
        tokenIds = new uint32[](planIds.length);
        supplies = new uint32[](planIds.length);
        rest = new uint32[](planIds.length);
        maxPurchaseOnce = new uint8[](planIds.length);
        isSellable = new bool[](planIds.length);
        maxPurchasePerAccount = new uint8[](planIds.length);
        whitelistIds = new uint8[](planIds.length);
        for (uint256 index = 0; index < planIds.length; ++index) {
            tokenAddresses[index] = sellPlans[index].tokenAddress;
            unitPrices[index] = sellPlans[index].unitPrice;
            unitDGTPrices[index] = sellPlans[index].unitDGTPrice;
            tokenIds[index] = sellPlans[index].tokenId;
            supplies[index] = sellPlans[index].supply;
            rest[index] = sellPlans[index].rest;
            maxPurchaseOnce[index] = sellPlans[index].maxPurchaseOnce;
            isSellable[index] = sellPlans[index].isSellable;
            maxPurchasePerAccount[index] = sellPlans[index].maxPurchasePerAccount;
            whitelistIds[index] = sellPlans[index].whitelistId;
        }
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == godGadget, "only accept godgadget transfer");
        require(tx.origin == operator && tx.origin == from, "should call from user himself");
        uint256 whitelistId = abi.decode(data, (uint256));
        _joinWhitelist(from, whitelistId, id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert("not allowed");
    }

    modifier nonContractCaller() {
        require(tx.origin == msg.sender, "cannot call from contract");
        _;
    }
}

interface IRuneStakingPort {
    function pendingToken(address account) external view returns (uint256 pending);
}

interface IAGExchangerPort {
    function userDGTPreview(address account) external view returns (uint256 pending);
}
