// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SignerTest is EIP712 {
    using Counters for Counters.Counter;
    uint256 private constant uin8Mask = 0xff;
    uint256 private constant uin16Mask = 0xffff;
    uint256 private constant uin32Mask = 0xffffffff;

    uint256 public constant _basicStatusMask = (uin8Mask << 8) | (uin8Mask << 24) | (uin32Mask << 144) | (uin32Mask << 176);
    uint256 public constant _basicStatusMaskInv = ~_basicStatusMask;
    uint256 public constant _levelMask = (uin8Mask << 16) | (uin16Mask << 32) | (uin16Mask << 48) | (uin16Mask << 64) | (uin16Mask << 80) | (uin16Mask << 96) | (uin32Mask << 112);
    uint256 public constant _levelMaskInv = ~_levelMask;

    event Mint(address indexed account, uint256 value, uint256 nonce);

    mapping(address => Counters.Counter) private _nonces;

    bytes32 private immutable _MINT_TYPEHASH = keccak256("Mint(address account,uint256 value,uint256 nonce)");

    address public immutable serverSigner;

    constructor(address serverSigner_) EIP712("SignerTest", "1") {
        serverSigner = serverSigner_;
    }

    function mint(uint256 value, bytes calldata serverSignature) public virtual {
        address account = msg.sender;
        uint256 nonce = _useNonce(account);
        bytes32 structHash = keccak256(abi.encode(account, value, nonce));
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(structHash), serverSignature);
        require(signer == serverSigner, "invalid signature");
        emit Mint(account, value, nonce);
    }

    /**
     * @dev See {IERC20Permit-nonces}.
     */
    function nonces(address owner) public view virtual returns (uint256) {
        return _nonces[owner].current();
    }

    /**
     * @dev See {IERC20Permit-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev "Consume a nonce": return the current value and increment.
     *
     * _Available since v4.1._
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        Counters.Counter storage nonce = _nonces[owner];
        current = nonce.current();
        nonce.increment();
    }

    function recoverContent(
        bytes calldata signature,
        address addr,
        uint256 amount
    )
        external
        pure
        returns (
            address serverAddress,
            bytes32 structHash,
            bytes memory signatureR
        )
    {
        structHash = keccak256(abi.encode(addr, amount));
        signatureR = signature;
        serverAddress = ECDSA.recover(ECDSA.toEthSignedMessageHash(structHash), signature);
    }

    function recoverContent2(
        bytes calldata signature,
        address addr,
        uint256 amount
    ) external pure returns (address serverAddress, bytes32 structHash) {
        structHash = keccak256(abi.encode(addr, amount));
        serverAddress = ECDSA.recover(keccak256(abi.encode(structHash)), signature);
    }
}
