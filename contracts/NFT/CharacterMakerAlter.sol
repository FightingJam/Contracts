// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../utils/OperatorGuard.sol";
import "../utils/SignerValidator.sol";
import "../interfaces/ISummonTicketClient.sol";
import "../interfaces/ICharacterRegistry.sol";
import "../interfaces/IDG721.sol";
import "../interfaces/ISquadProvider.sol";
import "../RandomBase.sol";

contract CharacterMakerAlter is OperatorGuard, SignerValidator, Pausable {
    using Strings for uint256;

    address public constant zeroAddress = address(0x0);
    event CharacterCreated(address indexed account, uint256 globalTokenId, uint256 rarity);

    struct Project {
        address contractAddress;
        uint16 count;
        uint16 rest;
        string chainSymbol;
    }

    uint256 public maxCharacterPerAccount = 1;
    uint256 public projectCount;
    mapping(uint256 => uint256) public supportedProjectIds;
    mapping(uint256 => Project) public supportedProject;
    mapping(address => uint256) public accountCreatedCount;

    ICharacterRegistry private immutable _charaRegistry;
    ISquadProvider private _squadProvider;

    constructor(
        address signer_,
        ICharacterRegistry charaRegistry_,
        ISquadProvider squadProvider_
    ) SignerValidator(signer_) {
        _charaRegistry = charaRegistry_;
        _squadProvider = squadProvider_;
    }

    function setMaxCharacterPerAccount(uint256 maxCharacterPerAccount_) external onlyOwner {
        maxCharacterPerAccount = maxCharacterPerAccount_;
    }

    function accountHasCreated(address account) external view returns (bool) {
        return accountCreatedCount[account] != 0;
    }

    function resetAccountHasCreated(address account) external onlyOwner {
        accountCreatedCount[account] = 0;
    }

    function setupProject(
        string calldata chainSymbol,
        address contractAddress,
        uint16 count
    ) external onlyOwner {
        uint256 _projectCount = projectCount;
        uint256 projectId = generateProjectId(chainSymbol, contractAddress);
        if (bytes(supportedProject[projectId].chainSymbol).length == 0) projectCount = _projectCount + 1;
        supportedProject[projectId].chainSymbol = chainSymbol;
        supportedProject[projectId].contractAddress = contractAddress;
        supportedProject[projectId].count = count;
        supportedProject[projectId].rest = count;
        supportedProjectIds[_projectCount] = projectId;
    }

    function createCharacter(
        string calldata chainSymbol,
        address contractAddress,
        uint256 tokenId,
        uint256 squadLeaderId,
        uint256 rarity,
        bytes calldata signature
    ) external nonContractCaller returns (uint256 globalTokenId) {
        bytes32 structHash = keccak256(abi.encode(address(this), msg.sender, chainSymbol, contractAddress, tokenId, squadLeaderId, rarity));
        _validSignature(structHash, signature);
        globalTokenId = _createCharacter(msg.sender, chainSymbol, contractAddress, tokenId, rarity);
        _tryJoinSquad(squadLeaderId, globalTokenId);
    }

    function createCharacterThoughtOperator(
        address account,
        string calldata chainSymbol,
        address contractAddress,
        uint256 tokenId,
        uint256 squadLeaderId,
        uint256 rarity
    ) external onlyOperator returns (uint256 globalTokenId) {
        globalTokenId = _createCharacter(account, chainSymbol, contractAddress, tokenId, rarity);
        _tryJoinSquad(squadLeaderId, globalTokenId);
    }

    function _tryJoinSquad(uint256 squadLeaderId, uint256 globalTokenId) private {
        _squadProvider.joinSquad(globalTokenId, squadLeaderId);
    }

    function _createCharacter(
        address account,
        string calldata chainSymbol,
        address contractAddress,
        uint256 tokenId,
        uint256 rarity
    ) private returns (uint256 globalTokenId) {
        uint256 createdCount = accountCreatedCount[account];
        require(createdCount < maxCharacterPerAccount, "account created count exceeds");
        uint256 projectId = generateProjectId(chainSymbol, contractAddress);
        require(!_charaRegistry.isTokenRegistred(chainSymbol, contractAddress, tokenId), "token already registered");
        require(supportedProject[projectId].contractAddress != zeroAddress, "project not support");
        require(supportedProject[projectId].rest > 0, "not enought position");
        accountCreatedCount[account] = createdCount + 1;
        supportedProject[projectId].rest -= 1;
        (, globalTokenId) = _charaRegistry.initAsCharacter(chainSymbol, contractAddress, tokenId, rarity, 0);
        emit CharacterCreated(account, globalTokenId, rarity);
    }

    function generateProjectId(string calldata chainSymbol, address contractAddress) public pure returns (uint256 projectId) {
        projectId = uint256(keccak256(abi.encodePacked(chainSymbol, contractAddress)));
    }

    modifier nonContractCaller() {
        require(tx.origin == msg.sender, "cannot call from contract");
        _;
    }
}
