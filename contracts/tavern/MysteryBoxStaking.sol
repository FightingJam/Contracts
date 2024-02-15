// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IMysteryBoxStaking.sol";

contract MysteryBoxStaking is Ownable, ERC1155Receiver, IMysteryBoxStaking {
    using EnumerableSet for EnumerableSet.UintSet;

    event PoolAdded(address account, uint256 tokenId, uint256 allocPoint);
    event WithdrawPendingToken(address indexed account, uint256[] tokenIds, uint256 ag);
    event DepositRewards(address indexed operator, uint256 amount);

    uint256 private constant acc1e12 = 1e12;
    address private constant zeroAddress = address(0x0);
    address public constant mainnetTokenAddress = zeroAddress;

    // Info of each pool.
    struct StakingPool {
        uint16 allocPoint; // alloc Point for the pool
        uint240 accTokenPerShare; // Accumulated token per share, times 1e12.
    }

    // Info of each pool.
    struct UserInfo {
        uint32 amount; // user staked count
        uint224 rewardDebt; // Accumulated rewards
    }

    // account => tokenId => info
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;

    // user total withdraws
    mapping(address => uint256) public userTotalWithdraws;

    // tokenId => pool
    mapping(uint256 => StakingPool) public stakingPools;
    // unstarted tokenPoolId => allocPoints
    mapping(uint256 => uint256) private _allocPoints;
    // supported TokenIds
    EnumerableSet.UintSet private _supportedTokenIds;

    // total diposited rewards
    uint256 public totalRewards;
    // sum of alloc points
    uint256 public totalAllocPoint;
    // the account can deposite rewards
    address public rewardInjector;

    // Ancient Gold
    IERC20 private immutable _ancientGold;
    // Mystery Boxes
    address private immutable _godGadget;

    constructor(address ag_, address godGadget_) {
        _ancientGold = IERC20(ag_);
        _godGadget = godGadget_;
        rewardInjector = owner();

        addSupportedToken(110, 10);
        addSupportedToken(111, 40);
        addSupportedToken(112, 50);
    }

    /**
     * @dev add a supported token(if needs)
     * @param tokenId the tokenId in GodGadget
     * @param allocPoint the alloc point of this tokenId
     */
    function addSupportedToken(uint256 tokenId, uint256 allocPoint) public onlyOwner {
        require(_supportedTokenIds.add(tokenId), "token already added");
        _allocPoints[tokenId] = allocPoint;
    }

    /**
     * @dev set reward depositor
     * @param rewardInjector_ the one who can deposit rewards
     */
    function setRewardInjector(address rewardInjector_) external onlyOwner {
        rewardInjector = rewardInjector_;
    }

    /**
     * @dev Add a pool, each tokenId can be only added once
     * @param account who opend this pool
     * @param tokenId the tokenId to open
     */
    function _addPool(address account, uint256 tokenId) private {
        // get alloc points
        uint256 allocPoint = _allocPoints[tokenId];
        // clear storaged allocPoint
        delete _allocPoints[tokenId];
        // set alloc point
        stakingPools[tokenId].allocPoint = uint16(allocPoint);
        // accumulate total alloc point
        totalAllocPoint += allocPoint;
        emit PoolAdded(account, tokenId, allocPoint);
    }

    /**
     * @dev deposit token into pool
     * @param account the one deposit token
     * @param tokenId the tokenId to deposit
     * @param amount the amount to deposit
     */
    function _deposit(
        address account,
        uint256 tokenId,
        uint256 amount
    ) private {
        // if the pool is not existe(_allocPoints in storage is not 0), then add the pool
        if (_allocPoints[tokenId] != 0) _addPool(account, tokenId);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        // withdraw pending tokens
        _withdrawPendingToken(account, tokenIds);
        // calculate staked amount and its rewardDebt
        uint256 stakedAmount = userInfo[account][tokenId].amount;
        stakedAmount += amount;
        userInfo[account][tokenId].amount = uint32(stakedAmount);
        userInfo[account][tokenId].rewardDebt = uint224((stakedAmount * stakingPools[tokenId].accTokenPerShare) / acc1e12);
    }

    /**
     * @dev deposit reward tokens into pool
     * @param rewards the amount to deposit
     */
    function depositRewards(uint256 rewards) external override onlyRewardInjector {
        // collect tokens
        _ancientGold.transferFrom(msg.sender, address(this), rewards);
        // add total token rewards
        totalRewards += rewards;
        // gas saves
        uint256 count = _supportedTokenIds.length();
        uint256 _totalAllocPoint = totalAllocPoint;
        IERC1155 godGadget = IERC1155(_godGadget);
        for (uint256 index = 0; index < count; ++index) {
            // tokenId of the pool
            uint256 tokenId = _supportedTokenIds.at(index);
            // get allocPoint
            uint256 allocPoint = stakingPools[tokenId].allocPoint;
            // if allocPoint is not 0 (means that the pool is opened)
            if (allocPoint != 0) {
                // calculate income shares per pool
                uint256 income = (rewards * allocPoint) / _totalAllocPoint;
                // calculate tokens deposited
                uint256 balance = godGadget.balanceOf(address(this), tokenId);
                // if there any token deposited, calculate accumulate tokens per share
                if (balance > 0) stakingPools[tokenId].accTokenPerShare += uint240((income * acc1e12) / balance);
            }
        }
        emit DepositRewards(msg.sender, rewards);
    }

    /**
     * @dev update alloc points, not used in prod env
     */
    function _updateAllocPoint(uint256[] calldata tokenIds, uint256[] calldata allocPoints) private {
        uint256 _totalAllocPoint = totalAllocPoint;
        require(tokenIds.length == allocPoints.length, "input array length not equals");
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            uint256 tokenId = tokenIds[index];
            require(_supportedTokenIds.contains(tokenId), "token not supported");
            if (_allocPoints[tokenId] != 0) _allocPoints[tokenId] = allocPoints[index];
            else {
                uint256 newAllocPoint = allocPoints[index];
                _totalAllocPoint = _totalAllocPoint + newAllocPoint - stakingPools[tokenId].allocPoint;
                stakingPools[tokenId].allocPoint = uint16(newAllocPoint);
            }
        }
        totalAllocPoint = _totalAllocPoint;
    }

    /**
     * @dev withdraw staking token from pool
     * @param tokenIds the tokenIds to withdraw
     * @param amounts the amounts to withdraw
     */
    function withdraw(uint256[] calldata tokenIds, uint256[] calldata amounts) external {
        // collect pending tokens
        _withdrawPendingToken(msg.sender, tokenIds);        
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            uint256 tokenId = tokenIds[index];
            uint256 withdrawAmount = amounts[index];
            uint256 stakedAmount = userInfo[msg.sender][tokenId].amount;
            // check if user can withdraw the token with his desired amount
            require(withdrawAmount <= stakedAmount, "not enought to withdraw");
            stakedAmount -= withdrawAmount;
            userInfo[msg.sender][tokenId].amount = uint16(stakedAmount);
            // update rewardDebt
            userInfo[msg.sender][tokenId].rewardDebt = uint224((stakedAmount * stakingPools[tokenId].accTokenPerShare) / acc1e12);
        }
        // transfer out tokens
        IERC1155(_godGadget).safeBatchTransferFrom(address(this), msg.sender, tokenIds, amounts, "");
    }

    /**
     * @dev withdraw pending token
     * @param tokenIds the tokenIds to withdraw pendings
     */
    function withdrawPendingToken(uint256[] calldata tokenIds) external {
        _withdrawPendingToken(msg.sender, tokenIds);
    }

    /**
     * @dev implemtation of withdraw pending tokens
     * @param account the token holder
     * @param tokenIds the tokenIds to withdraw pendings
     */
    function _withdrawPendingToken(address account, uint256[] memory tokenIds) private {
        uint256 profits;
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            uint256 tokenId = tokenIds[index];
            uint256 amount = userInfo[account][tokenId].amount;
            // calculate new rewardDebt
            uint256 newRewardDebt = (amount * stakingPools[tokenId].accTokenPerShare) / acc1e12;
            // accumulate profits using new rewardDebt - old rewardDebt
            profits += newRewardDebt - userInfo[account][tokenId].rewardDebt;
            // update reward debt
            userInfo[account][tokenId].rewardDebt = uint224(newRewardDebt);
        }
        // if there is any profts
        if (profits > 0) {
            // transfer tokens
            _ancientGold.transfer(account, profits);
            // accumulate withdraws
            userTotalWithdraws[account] += profits;
            emit WithdrawPendingToken(account, tokenIds, profits);
        }
    }

    /**
     * @dev pending token of a account
     * @param account the token holder
     * @param tokenIds the tokenIds to withdraw pendings
     */
    function pendingTokens(address account, uint256[] calldata tokenIds) external view returns (uint256[] memory tokenAmounts, uint256[] memory pending) {
        pending = new uint256[](tokenIds.length);
        tokenAmounts = new uint256[](tokenIds.length);
        for (uint256 index = 0; index < tokenIds.length; ++index) {
            uint256 tokenId = tokenIds[index];
            uint256 amount = userInfo[account][tokenId].amount; 
            uint256 rewardDebt = userInfo[account][tokenId].rewardDebt;
            pending[index] = (amount * stakingPools[tokenId].accTokenPerShare) / acc1e12 - rewardDebt;
            tokenAmounts[index] = amount;
        }
    }

    function supportedTokenIds() external view returns (uint256[] memory tokenIds) {
        uint256 count = _supportedTokenIds.length();
        tokenIds = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) tokenIds[index] = _supportedTokenIds.at(index);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata
    ) public virtual override returns (bytes4) {
        require(msg.sender == _godGadget, "must send from GodGadget");
        require(tx.origin == operator && operator == from, "must send from owner");
        require(_supportedTokenIds.contains(id), "token not supported");
        if (value > 0) _deposit(from, id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual override returns (bytes4) {
        revert("not supported");
    }

    modifier onlyRewardInjector() {
        require(msg.sender == rewardInjector, "require reward injector");
        _;
    }
}
