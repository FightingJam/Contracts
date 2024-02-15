// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INOOValidator.sol";
import "../utils/SignerValidator.sol";

contract NOOValidator is INOOValidator, SignerValidator, Ownable {
    uint256 public constant maxSignatureBlockDelay = 40;

    event TokenValidatedBatch(uint256[] globalTokenIds);

    mapping(uint256 => uint256) public override tokenNonce;

    constructor(address signer_) SignerValidator(signer_) {}

    function validateOwner(
        address account,
        uint256 globalTokenId,
        uint256 blockNumber,
        bytes calldata signature
    ) external override {
        require(blockNumber >= block.number - maxSignatureBlockDelay, "signature too old");
        uint256 nonce = tokenNonce[globalTokenId];
        bytes32 structHash = keccak256(abi.encode(address(this), account, nonce, blockNumber, globalTokenId));
        _validSignature(structHash, signature);
        tokenNonce[globalTokenId] = nonce + 1;
        uint256[] memory globalTokenIds = new uint256[](1);
        globalTokenIds[0] = globalTokenId;
        emit TokenValidatedBatch(globalTokenIds);
    }

    function validateOwner(address account, bytes calldata compositeData) external override returns (uint256) {
        (uint256 globalTokenId, uint256 blockNumber, bytes memory signature) = abi.decode(compositeData, (uint256, uint256, bytes));
        require(blockNumber >= block.number - maxSignatureBlockDelay, "signature too old");
        uint256 nonce = tokenNonce[globalTokenId];
        bytes32 structHash = keccak256(abi.encode(address(this), account, nonce, blockNumber, globalTokenId));
        _validSignature(structHash, signature);
        tokenNonce[globalTokenId] = nonce + 1;
        uint256[] memory globalTokenIds = new uint256[](1);
        globalTokenIds[0] = globalTokenId;
        emit TokenValidatedBatch(globalTokenIds);
        return globalTokenId;
    }

    function validateOwnerBatch(address account, bytes calldata compositeData) external override returns (uint256[] memory) {
        (uint256[] memory globalTokenIds, uint256 blockNumber, bytes memory signature) = abi.decode(compositeData, (uint256[], uint256, bytes));
        require(blockNumber >= block.number - maxSignatureBlockDelay, "signature too old");
        uint256[] memory nonces = new uint256[](globalTokenIds.length);
        for (uint256 index = 0; index < nonces.length; ++index) {
            uint256 globalTokenId = globalTokenIds[index];
            nonces[index] = tokenNonce[globalTokenId];
            tokenNonce[globalTokenId] = nonces[index] + 1;
        }
        bytes32 structHash = keccak256(abi.encode(address(this), account, nonces, blockNumber, globalTokenIds));
        _validSignature(structHash, signature);
        emit TokenValidatedBatch(globalTokenIds);
        return globalTokenIds;
    }

    function changeSigner(address signer_) external onlyOwner {
        _setRemoteSigner(signer_);
    }
}
