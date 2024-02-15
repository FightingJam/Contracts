// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IDG20.sol";
import "../interfaces/IERC1155Minter.sol";
import "../interfaces/IAGExchanger.sol";
import "../interfaces/IGamePortal.sol";
import "../interfaces/IDGPRegistry.sol";
import "../interfaces/IMysteryBoxStaking.sol";
import "../RandomBase.sol";

contract Minigames is Ownable, RandomBase, ERC1155Receiver {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    event SpendAGAxe(address indexed account, uint256 amount, bool useBNB);

    event ReferralReward(address indexed account, address from, uint256 level, uint256 amount);
    event ThrowAxe(address indexed account, uint256[] prizeAG, uint256[] prizeTokenId, address[] token3rdAddress, uint256[] token3rdAmount);
    event MergeMysteryBox(address indexed account, uint256 mysteryBoxId, uint256 amount);

    event SpendAGBeat(address indexed account, uint256 amount, bool useBNB, uint256 round);
    event BeatAGPrizeDispatched(address indexed account, uint256 round, uint256 source, uint256 amount);

    address public constant zeroAddress = address(0x0);
    uint256 private constant uint16Mask = 0xffff;

    uint256 public constant totalPercentage = 100;

    // 10% fee goes to parent
    uint256 public constant feeToParentsPercentage = 10;
    // in the fees to parent, there are 70% goes to direct parent
    uint256 public constant parentPercentage = 70;
    // the rest 30% will goes to grand parent
    uint256 public constant grandParentPercentage = 30;

    // not in use
    struct AxeReward {
        uint32 percentage;
        uint32 parts;
        uint32 rest;
        uint32 boxId;
    }

    // axe rewards from 3rd party
    struct Axe3rdAirdrop {
        address tokenAddress;
        uint96 unitAmount;
        uint256 quantity;
    }

    // bank contract, work as change BNB to AG
    IAGExchanger private _agExchanger;

    // box merges xor hash table
    mapping(uint256 => uint256) public boxMerges;

    IERC1155Minter private immutable _godGadget;
    IDG20 private immutable _ag;
    IGamePortal private immutable _gamePortal;
    IDGPRegistry private immutable _dgpRegistry;
    uint256 private immutable _projectId;
    IMysteryBoxStaking private immutable _mBoxStaking;

    // total burnt acient gold
    uint256 public totalBurnAG;
    mapping(address => uint256) public burnts;

    // ==========================================================================
    // ** Throw AXE **
    // total axe AG pool
    uint256 public axeAGPool;
    // a maximun count of axe can throw in one transaction
    uint256 public constant maxAxeCountPerRound = 10;
    // price of each axe
    uint256 public constant throwAxePrice = 100 ether;
    // axe AG bingo upper level
    uint256 public constant axeAgBingo = 30;
    // axe ag MBOX bingo upper level
    uint256 public constant axeMBoxBingo = 10;
    // not in use
    mapping(uint256 => AxeReward) private _mboxs;
    // user's rune fragment
    mapping(address => uint256) private _userMBoxFragement;
    // axe extra rewards from 3rd party
    mapping(uint256 => Axe3rdAirdrop) private _axe3rdAirdrop;
    // 3rd Airdrop indexes
    EnumerableSet.UintSet private _axe3rdAirdropIndexes;
    // total sum of rewards from 3rd party
    uint256 public airdrop3rdQuantitySum;

    // ** Throw AXE **
    // ==========================================================================

    // ==========================================================================
    // ** Beat SB **

    struct UserInfo {
        uint32 twigs; // deposited twigs
        uint32 round; // rounds
        uint32 beats; // total beats
        uint160 rewardDebt; // reward debt
    }

    uint256 private constant _claimPendingEventSource = 0;
    uint256 private constant _sidePoolEventSource = 1;
    uint256 private constant _airdropEventSource = 2;
    uint256 private constant _grandPrizeEventSource = 3;

    uint256 private constant _acc1e12 = 1e12;
    // the winner's share in Jackpot
    uint256 private constant _winnerPercentage = 75;
    // the share of one side pool owner
    uint256 private constant _sidePoolPercentage = 5;
    // the percentage of beat entry fee goes to axe pool
    uint256 private constant _feeToAxePercentage = 2;
    // the percentage of burn in every participation
    uint256 private constant _feeToBurnPercentage = 10;
    // the percentage gose to dividends
    uint256 private constant _feeToDividendsPoolPercentage = 40;
    // the percetage gose to airdrop pool
    uint256 private constant _feeToAirdropPoolPercentage = 1;
    // start price of beat
    uint256 private constant _startPrice = 100 ether; // 100 for prod
    // count of side pools
    uint256 private constant _sidePoolPositions = 3;
    // rest percentage when withdraw twig
    uint256 private constant _twigBurnRestPercentage = 80;
    uint256 private constant _airdropReclaimL1Factor = 5;
    uint256 private constant _airdropReclaimL2Factor = 25;
    uint256 private constant _airdropReclaimL1Percentage = 25;
    uint256 private constant _airdropReclaimL2Percentage = 50;
    uint256 private constant _airdropReclaimL3Percentage = 75;
    uint256 private constant _twigId = 0;

    // round => accu pershare times 1e12
    mapping(uint256 => uint256) public roundAccumulatePerShare;
    // round => owner
    mapping(uint256 => EnumerableSet.AddressSet) private _sidePoolOwner;

    // account  => info
    mapping(address => UserInfo) public userBeats;
    // beat's jackpot
    uint256 public beatAGPool;

    // AG raise per beat
    uint256 public raisePerBeat = 2 ether; //may change
    // airdrop rate raise
    uint256 public raisePerAirdrops = 2; // 2 for prod times 1000;

    // enlength blocks in each play
    uint8 public blockEnlengthen = 30; // 30 in prod  // nonchange
    // enlength blocks in each play (in next round)
    uint8 public blockEnlengthenNext = 15; // 15 in prod //maychange
    // airdrop minimal and it should * 100 to match deposited amout
    uint96 public airdropMinAG = 25 ether;
    // airdrop minial in next round
    uint96 public airdropMinAGNext = 25 ether;
    // round initial length
    uint24 public roundStartBlockLength = 48 * 60 * 20; // 24 * 60 *20 for prod
    // next round initial length
    uint24 public roundStartBlockLengthNext = 24 * 60 * 20;

    // ****************************
    // current winner
    address public currentStand;
    // current round end block
    uint32 public currentRoundEndBlock;
    // current round total beats
    uint64 public currentRoundBeats;
    // **********256bits***********

    // ****************************
    // current airdrop pool
    uint96 public currentAirdropPool;
    // percentage of airdrop
    uint16 public airdropRate;
    // current price per beat
    uint96 public currentPrice;
    // current round number
    uint16 public currentRound;

    // **********224bits***********

    // ** Beat SB **
    // ==========================================================================
    // global start status
    uint256 private _globalStatus;

    constructor(
        address randomizer_,
        address godGadget_,
        address agExchanger_,
        address ag_,
        uint256 projectId_,
        address dgpRegistry_,
        address gamePortal_,
        address mBoxStaking_
    ) RandomBase(randomizer_) {
        _godGadget = IERC1155Minter(godGadget_);
        _agExchanger = IAGExchanger(agExchanger_);
        _ag = IDG20(ag_);
        _projectId = projectId_;
        _dgpRegistry = IDGPRegistry(dgpRegistry_);
        _gamePortal = IGamePortal(gamePortal_);
        _mBoxStaking = IMysteryBoxStaking(mBoxStaking_);
        IDG20(ag_).approve(address(mBoxStaking_), type(uint256).max);

        currentPrice = uint96(_startPrice);

        uint256[] memory ids = new uint256[](3);
        ids[0] = 0;
        ids[1] = 1;
        ids[2] = 2;
        _setBoxMerge(ids, 110);
        ids[0] = 3;
        ids[1] = 4;
        ids[2] = 5;
        _setBoxMerge(ids, 111);
        ids[0] = 6;
        ids[1] = 7;
        ids[2] = 8;
        _setBoxMerge(ids, 112);
    }

    /**
     * @dev set merge methode oof runes
     * @param ids rune ids
     * @param mBoxId_ merged mboxId
     */
    function _setBoxMerge(uint256[] memory ids, uint256 mBoxId_) private {
        uint256 base;
        for (uint256 index = 0; index < ids.length; ++index) base ^= _hashUint(ids[index]);
        boxMerges[base] = mBoxId_ + 1;
    }

    /**
     * @dev start game
     */
    function setStart() external onlyOwner {
        (bool started, , ) = getGlobalStatus();
        require(!started, "already started");
        _globalStatus |= 0x1;
        currentRoundEndBlock = uint32(block.number + roundStartBlockLength);
    }

    /**
     * @dev stop game, axe will stopped immediately, beat will stoped in next round
     */
    function setStop() external onlyOwner {
        (bool started, bool stopped, ) = getGlobalStatus();
        require(started, "not started");
        require(!stopped, "already stopped");
        _globalStatus |= 0x2;
    }

    /**
     * @dev get game status
     */
    function getGlobalStatus()
        public
        view
        returns (
            bool started,
            bool stopped,
            bool beatStopped
        )
    {
        uint256 gStatus = _globalStatus;
        started = (gStatus & 0x1) == 0x1;
        stopped = (gStatus & 0x2) == 0x2;
        beatStopped = (gStatus & 0x4) == 0x4;
    }

    /**
     * @dev deposit mystery box staking rewards from axe AG pool
     * @param percentage the percentage of axe ag pool will dispatched
     */
    function depositMysteryBoxStakingRewards(uint256 percentage) external onlyOwner {
        require(percentage <= totalPercentage, "percentage not valid");
        uint256 dispatchedAmount = (axeAGPool * percentage) / totalPercentage;
        axeAGPool -= dispatchedAmount;
        _mBoxStaking.depositRewards(dispatchedAmount);
    }

    /**
     * @dev deposit initial rewards to axe AG pool, will using ag exchanger to exchange BNB to desired AG
     * @param agAmount_ the amount of ag willing to deposit
     */
    function addAxePool(uint256 agAmount_) external payable onlyOwner {
        _chargeAsBNB(agAmount_);
        axeAGPool += agAmount_;
    }

    /**
     * @dev deposit initial rewards to beat AG pool, will using ag exchanger to exchange BNB to desired AG
     * @param agAmount_ the amount of ag willing to deposit
     */
    function addBeatPool(uint256 agAmount_) external payable onlyOwner {
        _chargeAsBNB(agAmount_);
        beatAGPool += agAmount_;
    }

/**
     * @dev merge runes to get a mystery box
     * @param ids the id of the runes to merge
     * @param amount the amount of mystery box to merge
     */
    function mergeParts(uint256[] calldata ids, uint256 amount) external {
        require(amount > 0, "amount should > 0");
        uint256 base;
        uint256 userMBoxFragement = _userMBoxFragement[msg.sender];
        for (uint256 index = 0; index < ids.length; ++index) {
            uint256 tokenId = ids[index];
            uint256 offset = tokenId * 24;
            require(uint24(userMBoxFragement >> offset) >= amount, "token balance not enough");
            userMBoxFragement -= (amount << offset);
            base ^= _hashUint(tokenId);
        }
        uint256 mysteryBoxId = boxMerges[base];
        require(mysteryBoxId > 0, "mystery box not mergable");
        --mysteryBoxId;
        _userMBoxFragement[msg.sender] = userMBoxFragement;
        _godGadget.mint(msg.sender, mysteryBoxId, amount, "");
        emit MergeMysteryBox(msg.sender, mysteryBoxId, amount);
    }

    function setAxe3rdAirdrops(
        address tokenAddress,
        uint256 unitAmount,
        uint256 quantity
    ) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this), unitAmount * quantity);
        uint256 count = _axe3rdAirdropIndexes.length();
        _axe3rdAirdrop[count].tokenAddress = tokenAddress;
        _axe3rdAirdrop[count].unitAmount = uint96(unitAmount);
        _axe3rdAirdrop[count].quantity = quantity;
        _axe3rdAirdropIndexes.add(count);
        airdrop3rdQuantitySum += quantity;
    }

    function getAxe3rdAirdrops()
        external
        view
        returns (
            address[] memory tokenAddr,
            uint256[] memory unitAmount,
            uint256[] memory counts
        )
    {
        uint256 count = _axe3rdAirdropIndexes.length();
        tokenAddr = new address[](count);
        unitAmount = new uint256[](count);
        counts = new uint256[](count);
        while (count > 0) {
            --count;
            tokenAddr[count] = _axe3rdAirdrop[count].tokenAddress;
            unitAmount[count] = _axe3rdAirdrop[count].unitAmount;
            counts[count] = _axe3rdAirdrop[count].quantity;
        }
    }

    function throwAxeBNB(uint256 count) external payable verifyAxeCount(count) canPlayAxe {
        uint256 entryFee = count * throwAxePrice;
        _chargeAsBNB(entryFee);
        emit SpendAGAxe(msg.sender, entryFee, true);
        _throwAxe(entryFee, count);
    }

    function throwAxe(uint256 count) external verifyAxeCount(count) canPlayAxe {
        uint256 entryFee = count * throwAxePrice;
        _charge(entryFee);
        emit SpendAGAxe(msg.sender, entryFee, false);
        _throwAxe(entryFee, count);
    }

    function _throwAxe(uint256 entryFee, uint256 count) private nonContractCaller isRegistred {
        uint256 _axeAGPool = axeAGPool;
        {
            uint256 parentFee = (entryFee * feeToParentsPercentage) / totalPercentage;
            uint256 remains = _sendToParents(parentFee, msg.sender);
            _axeAGPool += remains;
            entryFee -= parentFee;
        }
        uint256 seed = _genRandomNumber();
        uint256[] memory agPrizes;
        uint256[] memory tokenIds;
        address[] memory airDrop3rdToken;
        uint256[] memory airDrop3rdAmount;
        uint256 agBingo;
        uint256 boxBingo;
        uint256 airdrop3rdQuantitySum_ = airdrop3rdQuantitySum;
        for (uint256 index = 0; index < count; ++index) {
            seed = _hashUint(seed);
            uint256 bingo = seed % totalPercentage;
            if (bingo >= axeAgBingo) ++agBingo;
            else if (bingo >= axeMBoxBingo) ++boxBingo;
            else {
                if (airdrop3rdQuantitySum_ == 0) ++agBingo;
                else --airdrop3rdQuantitySum_;
            }
        }
        {
            uint256 agBingoAmount = (entryFee * agBingo) / count;
            _axeAGPool += agBingoAmount;
            _burnAG(msg.sender, entryFee - agBingoAmount);
        }
        if (agBingo > 0) {
            seed = _hashUint(seed);
            (agPrizes, _axeAGPool) = _agBingo(seed, agBingo, _axeAGPool);
        }
        if (boxBingo > 0) {
            seed = _hashUint(seed);
            tokenIds = _boxBingo(seed, boxBingo);
        }
        uint256 drop3rd = count - (agBingo + boxBingo);
        if (drop3rd > 0) {
            airdrop3rdQuantitySum = airdrop3rdQuantitySum_;
            seed = _hashUint(seed);
            (airDrop3rdToken, airDrop3rdAmount) = _3rdAirdropBingo(seed, drop3rd);
        }
        axeAGPool = _axeAGPool;
        emit ThrowAxe(msg.sender, agPrizes, tokenIds, airDrop3rdToken, airDrop3rdAmount);
    }

    function _agBingo(
        uint256 randomSeed,
        uint256 count,
        uint256 _axeAGPool
    ) private returns (uint256[] memory prizes, uint256 agRest) {
        uint256 prizeSum;
        prizes = new uint256[](count);
        while (count > 0) {
            --count;
            randomSeed = _hashUint(randomSeed);
            uint256 chance = randomSeed % 10000;
            uint256 amount;
            if (chance >= 9700) amount = 1 ether;
            else if (chance >= 8052) amount = 10 ether;
            else if (chance >= 5952) amount = 20 ether;
            else if (chance >= 1652) amount = 50 ether;
            else if (chance >= 152) amount = 200 ether;
            else if (chance >= 52) amount = 400 ether;
            else if (chance >= 2) amount = 600 ether;
            else amount = 1000 ether;
            prizeSum += amount;
            prizes[count] = amount;
        }
        if (prizeSum > _axeAGPool) prizeSum = _axeAGPool;
        _ag.transfer(msg.sender, prizeSum);
        agRest = _axeAGPool - prizeSum;
    }

    function _boxBingo(uint256 randomSeed, uint256 count) private returns (uint256[] memory tokenIds) {
        uint256 userFragement = _userMBoxFragement[msg.sender];
        tokenIds = new uint256[](count);
        while (count > 0) {
            randomSeed = _hashUint(randomSeed);
            uint256 chance = randomSeed % 5555;
            uint256 tokenId;
            if (chance >= 5554) tokenId = 0;
            else if (chance >= 5474) tokenId = 1;
            else if (chance >= 5394) tokenId = 2;
            else if (chance >= 4894) tokenId = 3;
            else if (chance >= 4874) tokenId = 4;
            else if (chance >= 4374) tokenId = 5;
            else if (chance >= 2257) tokenId = 6;
            else if (chance >= 140) tokenId = 7;
            else tokenId = 8;
            userFragement += (1 << (tokenId * 24));
            --count;
            tokenIds[count] = tokenId;
        }
        _userMBoxFragement[msg.sender] = userFragement;
    }

    function _3rdAirdropBingo(uint256 randomSeed, uint256 count) private returns (address[] memory tokenAddress, uint256[] memory amounts) {
        tokenAddress = new address[](count);
        amounts = new uint256[](count);
        uint256 airdopProviderCounts = _axe3rdAirdropIndexes.length();
        while (count > 0) {
            --count;
            randomSeed = _hashUint(randomSeed);
            uint256 targetAirdropId = _axe3rdAirdropIndexes.at(randomSeed % airdopProviderCounts);
            Axe3rdAirdrop storage airdrop = _axe3rdAirdrop[targetAirdropId];
            tokenAddress[count] = airdrop.tokenAddress;
            amounts[count] = airdrop.unitAmount;
            IERC20(tokenAddress[count]).safeTransfer(msg.sender, amounts[count]);
            uint256 quantity = airdrop.quantity;
            if (quantity == 1) {
                _axe3rdAirdropIndexes.remove(targetAirdropId);
                delete _axe3rdAirdrop[targetAirdropId];
                --airdopProviderCounts;
            } else airdrop.quantity = quantity - 1;
        }
    }

    function _burnAG(address account, uint256 amount) private {
        if (amount > 0) {
            burnts[account] += amount;
            totalBurnAG += amount;
        }
    }

    function userFragments(address account) external view returns (uint256[] memory amounts) {
        uint256 userFragement = _userMBoxFragement[account];
        amounts = new uint256[](10);
        for (uint256 index = 0; index < 10; ++index) amounts[index] = uint24(userFragement >> (index * 24));
    }

    function updateBeatParameters(
        uint256 raisePerBeat_,
        uint256 raisePerAirdrops_,
        uint8 blockEnlengthenNext_,
        uint24 roundStartBlockLengthNext_,
        uint96 airdropMinAGNext_,
        uint96 airdropMinAG_
    ) external onlyOwner {
        raisePerBeat = raisePerBeat_;
        raisePerAirdrops = raisePerAirdrops_;
        blockEnlengthenNext = blockEnlengthenNext_;
        airdropMinAGNext = airdropMinAGNext_;
        roundStartBlockLengthNext = roundStartBlockLengthNext_;
        (bool isStarted, , ) = getGlobalStatus();
        if (!isStarted) airdropMinAG = airdropMinAG_;
    }

    function beatBNB(uint256 count) external payable {
        if (_checkBeatPlayable()) {
            (uint256 entryFee, uint256 round) = _estimateBeatEntryFeeAndUpdate(count);
            _chargeAsBNB(entryFee);
            emit SpendAGBeat(msg.sender, entryFee, true, round);
            _beat(entryFee, count, round);
        } else payable(msg.sender).transfer(msg.value);
    }

    function beat(uint256 count) external {
        if (_checkBeatPlayable()) {
            (uint256 entryFee, uint256 round) = _estimateBeatEntryFeeAndUpdate(count);
            _charge(entryFee);
            emit SpendAGBeat(msg.sender, entryFee, false, round);
            _beat(entryFee, count, round);
        }
    }

    function _checkBeatPlayable() private returns (bool) {
        (bool started, bool stopped, bool beatStopped) = getGlobalStatus();
        require(started, "not started");
        require(!beatStopped, "already stopped");
        if (!stopped) return true;
        if (isRoundEnded()) {
            uint256 beatAGRest = _settleLastRound(currentRound, beatAGPool);
            _ag.burn(beatAGRest + currentAirdropPool);
            currentAirdropPool = 0;
            beatAGPool = 0;
            _globalStatus |= 0x4;
            return false;
        } else return true;
    }

    function _beat(
        uint256 entryFee,
        uint256 count,
        uint256 round
    ) private nonContractCaller isRegistred {
        uint256 beatAGPool_ = beatAGPool;
        uint256 entryFeeRest = entryFee;
        {
            uint256 currentRoundBeats_;
            if (isRoundEnded()) {
                beatAGPool_ = _settleLastRound(round - 1, beatAGPool_);
                blockEnlengthen = blockEnlengthenNext;
                airdropMinAG = airdropMinAGNext;
                roundStartBlockLength = roundStartBlockLengthNext;
                currentRoundEndBlock = uint32(count * blockEnlengthen + roundStartBlockLength + block.number);
            } else {
                currentRoundEndBlock += uint32(count * blockEnlengthen);
                currentRoundBeats_ = currentRoundBeats;
            }
            currentStand = msg.sender;
            currentRoundBeats = uint64(currentRoundBeats_ + count);
            {
                uint256 poolFee = (entryFee * _feeToDividendsPoolPercentage) / totalPercentage;
                uint256 fraction = _addBeats(round, poolFee, count, currentRoundBeats_);
                entryFeeRest = entryFeeRest - poolFee + fraction;
            }
        }
        {
            uint256 airdropFee = (entryFee * _feeToAirdropPoolPercentage) / totalPercentage;
            entryFeeRest -= airdropFee;
            uint256 parentFee = (entryFee * feeToParentsPercentage) / totalPercentage;
            uint256 remains = _sendToParents(parentFee, msg.sender);
            entryFeeRest -= parentFee;
            _airDrop(airdropFee, remains, _genRandomNumber(), round);
        }
        {
            uint256 burnAmount = (entryFee * _feeToBurnPercentage) / totalPercentage;
            _burnAG(msg.sender, burnAmount);
            entryFeeRest -= burnAmount;
        }
        {
            uint256 feeToAxe = (entryFee * _feeToAxePercentage) / totalPercentage;
            axeAGPool += feeToAxe;
            entryFeeRest -= feeToAxe;
        }
        beatAGPool = beatAGPool_ + entryFeeRest;
    }

    function withdrawBeatReward() external {
        _withdrawBeatReward(msg.sender);
    }

    function withdrawTwigs() external {
        require(!_sidePoolOwner[currentRound].contains(msg.sender), "side pool owner cannot withdraw");
        uint256 withdrawableTwigs = (_twigBurnRestPercentage * userBeats[msg.sender].twigs) / totalPercentage;
        userBeats[msg.sender].twigs = 0;
        _godGadget.safeTransferFrom(address(this), msg.sender, _twigId, withdrawableTwigs, "");
    }

    function sidePoolOwners(uint256 round) external view returns (address[] memory owners, uint256[] memory twigs) {
        EnumerableSet.AddressSet storage sidePoolOwners_ = _sidePoolOwner[round];
        owners = new address[](sidePoolOwners_.length());
        twigs = new uint256[](owners.length);
        for (uint256 index = 0; index < owners.length; ++index) {
            owners[index] = sidePoolOwners_.at(index);
            twigs[index] = userBeats[owners[index]].twigs;
        }
    }

    function pendingBeatReward(address account) external view returns (uint256 pending) {
        uint256 round = userBeats[account].round;
        pending = (roundAccumulatePerShare[round] * userBeats[account].beats) / _acc1e12 - userBeats[account].rewardDebt;
    }

    function isRoundEnded() public view returns (bool) {
        return block.number > currentRoundEndBlock;
    }

    function estimateBeatEntryFee(uint256 count)
        external
        view
        returns (
            uint256 agAmount_,
            uint256 airdropRate_,
            uint256 airdropPercentage_
        )
    {
        (agAmount_, , ) = _estimateBeatEntryFee(count);
        uint256 airdropLevel = (agAmount_ * _feeToAirdropPoolPercentage) / totalPercentage / airdropMinAG;
        if (airdropLevel > 0) {
            airdropRate_ = airdropRate + raisePerAirdrops;
            if (airdropLevel < _airdropReclaimL1Factor) airdropPercentage_ = _airdropReclaimL1Percentage;
            else if (airdropLevel < _airdropReclaimL2Factor) airdropPercentage_ = _airdropReclaimL2Percentage;
            else airdropPercentage_ = _airdropReclaimL3Percentage;
        }
    }

    function _estimateBeatEntryFee(uint256 count)
        private
        view
        returns (
            uint256 agAmount_,
            uint256 currentPrice_,
            uint256 currentRound_
        )
    {
        if (isRoundEnded()) {
            currentPrice_ = _startPrice;
            currentRound_ = currentRound + 1;
        } else {
            currentPrice_ = currentPrice;
            currentRound_ = currentRound;
        }
        uint256 raisePerBeat_ = raisePerBeat;
        agAmount_ = currentPrice_ * count + (count * (count - 1) * raisePerBeat_) / 2;
        currentPrice_ += count * raisePerBeat_;
    }

    function _estimateBeatEntryFeeAndUpdate(uint256 count) private returns (uint256, uint256) {
        (uint256 agAmount_, uint256 currentPrice_, uint256 currentRound_) = _estimateBeatEntryFee(count);
        currentPrice = uint96(currentPrice_);
        currentRound = uint16(currentRound_);
        return (agAmount_, currentRound_);
    }

    function _addBeats(
        uint256 round,
        uint256 fee,
        uint256 count,
        uint256 currentRoundBeats_
    ) private returns (uint256 fraction) {
        uint256 pending;
        uint256 beats;
        uint256 userRound = userBeats[msg.sender].round;
        uint256 accumulatePerShare;
        if (currentRoundBeats_ != 0) {
            accumulatePerShare = roundAccumulatePerShare[round] + (fee * _acc1e12) / currentRoundBeats_;
            roundAccumulatePerShare[round] = accumulatePerShare;
        } else fraction = fee;
        if (userRound != round) {
            pending = (roundAccumulatePerShare[userRound] * userBeats[msg.sender].beats) / _acc1e12 - userBeats[msg.sender].rewardDebt;
            userBeats[msg.sender].round = uint32(round);
            _reorganizeSidePool(msg.sender);
        } else {
            beats = userBeats[msg.sender].beats;
            pending = (accumulatePerShare * beats) / _acc1e12 - userBeats[msg.sender].rewardDebt;
        }
        beats += count;
        userBeats[msg.sender].beats = uint32(beats);
        userBeats[msg.sender].rewardDebt = uint160((accumulatePerShare * beats) / _acc1e12);
        if (pending > 0) {
            _ag.transfer(msg.sender, pending);
            emit BeatAGPrizeDispatched(msg.sender, round, _claimPendingEventSource, pending);
        }
    }

    function _airDrop(
        uint256 airdropFee,
        uint256 parentFee,
        uint256 randomSeed,
        uint256 round
    ) private {
        uint256 _airdropPool = currentAirdropPool + airdropFee + parentFee;
        uint256 airdropLevel = airdropFee / airdropMinAG;
        if (airdropLevel > 0) {
            uint256 airdropRate_ = airdropRate + raisePerAirdrops;
            if (randomSeed % 1000 < airdropRate_) {
                uint256 percentage;
                if (airdropLevel < _airdropReclaimL1Factor) percentage = _airdropReclaimL1Percentage;
                else if (airdropLevel < _airdropReclaimL2Factor) percentage = _airdropReclaimL2Percentage;
                else percentage = _airdropReclaimL3Percentage;
                uint256 drops = (_airdropPool * percentage) / totalPercentage;
                _ag.transfer(msg.sender, drops);
                _airdropPool -= drops;
                airdropRate_ = 0;
                emit BeatAGPrizeDispatched(msg.sender, round, _airdropEventSource, drops);
            }
            airdropRate = uint16(airdropRate_);
        }
        currentAirdropPool = uint96(_airdropPool);
    }

    function _settleLastRound(uint256 oldRound, uint256 beatAGPool_) private returns (uint256) {
        address currentStand_ = currentStand;
        uint256 winnerAmount;
        if (currentStand_ != zeroAddress) {
            winnerAmount = (beatAGPool_ * _winnerPercentage) / totalPercentage;
            _ag.transfer(currentStand, winnerAmount);
            emit BeatAGPrizeDispatched(currentStand, oldRound, _grandPrizeEventSource, winnerAmount);
        }
        uint256 sidePoolAmount = (beatAGPool_ * _sidePoolPercentage) / totalPercentage / 3;
        _dispatchSidePool(oldRound, sidePoolAmount);
        return beatAGPool_ - winnerAmount - sidePoolAmount * 3;
    }

    function _dispatchSidePool(uint256 round, uint256 amount) private {
        EnumerableSet.AddressSet storage sidePoolOwners_ = _sidePoolOwner[round];
        uint256 sidePoolCount = sidePoolOwners_.length();
        for (uint256 index = 0; index < sidePoolCount; ++index) {
            address sideOwner = sidePoolOwners_.at(index);
            userBeats[sideOwner].twigs = 0;
            _ag.transfer(sideOwner, amount);
            emit BeatAGPrizeDispatched(sideOwner, round, _sidePoolEventSource, amount);
        }
        if (sidePoolCount < _sidePoolPositions) totalBurnAG += (_sidePoolPositions - sidePoolCount) * amount;
    }

    function _withdrawBeatReward(address account) private {
        uint256 round = userBeats[account].round;
        uint256 accuReward = (roundAccumulatePerShare[round] * userBeats[account].beats) / _acc1e12;
        uint256 pending = accuReward - userBeats[account].rewardDebt;
        if (pending > 0) {
            _ag.transfer(account, pending);
            emit BeatAGPrizeDispatched(account, round, _claimPendingEventSource, pending);
        }
        if (round != currentRound) {
            userBeats[account].beats = 0;
            userBeats[account].rewardDebt = 0;
            userBeats[account].round = uint32(currentRound);
            _reorganizeSidePool(account);
        } else userBeats[account].rewardDebt = uint160(accuReward);
    }

    function _depositTwig(address account, uint256 amount) private {
        userBeats[account].twigs += uint32(amount);
        _withdrawBeatReward(account);
        _reorganizeSidePool(account);
    }

    function _reorganizeSidePool(address account) private {
        uint256 accountTwigs = userBeats[account].twigs;
        if (accountTwigs > 0) {
            uint256 _currentRound = currentRound;
            EnumerableSet.AddressSet storage sidePoolOwners_ = _sidePoolOwner[_currentRound];
            if (!sidePoolOwners_.contains(account)) {
                uint256 minTwigs = 1 << 32;
                address minOwner;
                uint256 sidePoolCount = sidePoolOwners_.length();
                if (sidePoolCount < _sidePoolPositions) sidePoolOwners_.add(account);
                else {
                    for (uint256 index = 0; index < _sidePoolPositions; ++index) {
                        address owner = sidePoolOwners_.at(index);
                        uint256 twigs = userBeats[owner].twigs;
                        if (twigs <= minTwigs) {
                            minTwigs = twigs;
                            minOwner = owner;
                        }
                    }
                    if (accountTwigs > minTwigs) {
                        sidePoolOwners_.remove(minOwner);
                        sidePoolOwners_.add(account);
                    }
                }
            }
        }
    }

    function _chargeAsBNB(uint256 agAmount_) private {
        uint256 bnbCost = _agExchanger.estimateAG2BNB(agAmount_);
        require(msg.value >= bnbCost, "not enought BNB paid");
        if (msg.value > bnbCost) payable(msg.sender).transfer(msg.value - bnbCost);
        _agExchanger.exchangeAG{value: bnbCost}(msg.sender);
    }

    function _charge(uint256 agAmount_) private {
        _ag.transferFrom(msg.sender, address(this), agAmount_);
    }

    function _sendToParents(uint256 amount, address account) private returns (uint256 remains) {
        remains = amount;
        (, address[] memory parents) = _dgpRegistry.ancestors(_projectId, account, 2);
        if (parents[0] != zeroAddress) {
            uint256 sent = (amount * parentPercentage) / totalPercentage;
            _ag.transfer(parents[0], sent);
            emit ReferralReward(parents[0], msg.sender, 1, sent);
            remains -= sent;
            if (parents[1] != zeroAddress) {
                sent = (amount * grandParentPercentage) / totalPercentage;
                _ag.transfer(parents[1], sent);
                emit ReferralReward(parents[1], msg.sender, 2, sent);
                remains -= sent;
            }
        }
    }

    function _hashUint(uint256 seed) private pure returns (uint256) {
        bytes memory data = new bytes(32);
        assembly {
            mstore(add(data, 32), seed)
        }
        return uint256(keccak256(data));
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata
    ) public virtual override returns (bytes4) {
        require(msg.sender == address(_godGadget), "must send from GodGadget");
        require(tx.origin == operator && operator == from, "must send from owner");
        require(id == _twigId, "token not supported");
        if (value > 0) _depositTwig(from, value);
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

    modifier canPlayAxe() {
        (bool started, bool stopped, ) = getGlobalStatus();
        require(started && !stopped, "not playable");
        _;
    }

    modifier verifyAxeCount(uint256 count) {
        require(count > 0 && count <= maxAxeCountPerRound, "throwing count not valid");
        _;
    }

    modifier nonContractCaller() {
        require(tx.origin == msg.sender, "cannot call from contract");
        _;
    }

    modifier isRegistred() {
        require(_gamePortal.isAddressRegisted(msg.sender), "not registred");
        _;
    }
}
