// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/ITokenAuxiliary.sol";

contract DGTBatchDropper is Ownable {
    ITokenAuxiliary private _tokenAux;

    constructor(address tokenAux_) {
        _tokenAux = ITokenAuxiliary(tokenAux_);
    }

    function addDGTBatch(address[] calldata accounts, uint256[] calldata amounts) external onlyOwner {
        uint256 count = accounts.length;
        for (uint256 index = 0; index < count; ++index) _tokenAux.addDGT(accounts[index], amounts[index]);
    }
}
