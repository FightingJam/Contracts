// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IDGPRegistry.sol";
import "../interfaces/IGamePortal.sol";
import "../utils/SignerValidator.sol";

// A contract using for manage relationship between addresses using DGPRegistry
// The relationship is confirm off-chain, so it needs a signature to valid
contract GamePortal is SignerValidator, IGamePortal {
    address private constant ZeroAddress = address(0x0);
    uint256 public constant AccountMinLength = 4;

    IDGPRegistry public immutable dgpRegistry;
    uint256 public immutable projectId;

    event PassportUpdate(address indexed account, string newId);

    // addrss => name
    mapping(address => string) private _addressToPassport;
    // name => address
    mapping(bytes32 => address) private _accountToAddress;

    constructor(
        address remoteSigner_,
        uint256 projectId_,
        IDGPRegistry dgpRegistry_
    ) SignerValidator(remoteSigner_) {
        projectId = projectId_;
        dgpRegistry = dgpRegistry_;
    }

    /**
     * @dev Create a game passport with parent relationship
     * @param accountId the account name to be set
     * @param parent parent to set with
     * @param signature the signature from server
     */
    function createWithParent(
        string calldata accountId,
        address parent,
        bytes calldata signature
    ) external {
        // get old parent
        address oldParent = dgpRegistry.ancestor(projectId, msg.sender);
        // construct hash structure (contractAddress, sender, oldParent, newParent, accountName)
        bytes32 structHash = keccak256(abi.encode(address(this), msg.sender, oldParent, parent, accountId));
        // valid signature
        _validSignature(structHash, signature);
        // check account name exists
        require(bytes(_addressToPassport[msg.sender]).length == 0, "acount already created");
        bytes32 hashedAccount = keccak256(bytes(accountId));
        // check account name is occupied
        require(_accountToAddress[hashedAccount] == ZeroAddress, "accountId already exists");
        // set account name
        _addressToPassport[msg.sender] = accountId;
        _accountToAddress[hashedAccount] = msg.sender;

        // set parent relationship
        dgpRegistry.setParent(projectId, msg.sender, parent);
        emit PassportUpdate(msg.sender, accountId);
    }

    /**
     * @dev Update account name
     * @param accountId the account name to be set
     * @param signature the signature from server
     */
    function update(string calldata accountId, bytes calldata signature) external {
        // construct hash structure (contractAddress, sender, oldParent, newParent, accountName)
        bytes32 structHash = keccak256(abi.encode(address(this), msg.sender, accountId));
        // valid signature
        _validSignature(structHash, signature);

        // check account exists
        bytes32 hashedAccount = keccak256(bytes(accountId));
        {
            address account = _accountToAddress[hashedAccount];
            if (account == msg.sender) return;
            require(account == ZeroAddress, "accountId already exists");
        }

        // check if account has passport or not
        bytes32 oldHashedAccount = keccak256(bytes(_addressToPassport[msg.sender]));
        require(_accountToAddress[oldHashedAccount] == msg.sender, "account not existe");

        _addressToPassport[msg.sender] = accountId;
        delete _accountToAddress[oldHashedAccount];
        _accountToAddress[hashedAccount] = msg.sender;
        emit PassportUpdate(msg.sender, accountId);
    }

    /**
     * @dev Check if an account is registed
     * @param account the address to check 
     */
    function isAddressRegisted(address account) external view override returns (bool) {
        return bytes(_addressToPassport[account]).length > 0;
    }

    /**
     * @dev Get account name of an address
     * @param account the address to query 
     */
    function getAccountId(address account) external view override returns (string memory) {
        return _addressToPassport[account];
    }

    /**
     * @dev get the owner of an account name
     * @param accountId the account name to query
     */
    function getAccountAddress(string calldata accountId) external view override returns (address) {
        return _accountToAddress[keccak256(bytes(accountId))];
    }
}
