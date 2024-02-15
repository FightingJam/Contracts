// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/INOOValidator.sol";

abstract contract NOOClient {
    INOOValidator private _nooValidator;

    constructor(address nooValidator_) {
        _changeValidator(nooValidator_);
    }

    function _validateOwner(
        address account,
        uint256 tokenId,
        uint256 blockNumber,
        bytes calldata signature
    ) internal {
        _nooValidator.validateOwner(account, tokenId, blockNumber, signature);
    }

    function _validateOwner(address account, bytes calldata compositeData) internal returns (uint256 globalTokenId) {
        globalTokenId = _nooValidator.validateOwner(account, compositeData);
    }

    function _validateOwnerBatch(address account, bytes calldata compositeData) internal returns (uint256[] memory globalTokenIds) {
        globalTokenIds = _nooValidator.validateOwnerBatch(account, compositeData);
    }

    function _changeValidator(address nooValidator_) internal {
        _nooValidator = INOOValidator(nooValidator_);
    }
}
