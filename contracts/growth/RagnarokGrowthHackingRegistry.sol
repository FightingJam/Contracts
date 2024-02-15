// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../library/MGPLib.sol";
import "../utils/SignerValidator.sol";
import "../interfaces/IDGPRegistry.sol";
import "../interfaces/IGrowthHackingRegistry.sol";

contract RagnarokGrowthHackingRegistry is Ownable, SignerValidator, IGrowthHackingRegistry {
    uint256 immutable public projectId;
    IDGPRegistry immutable public dgpRegistry;

    constructor(
        address remoteSigner_,
        uint256 projectId_,
        IDGPRegistry dgpRegistry_
    ) SignerValidator(remoteSigner_) {
        projectId = projectId_;
        dgpRegistry = dgpRegistry_;
    }

    function setRemoteSigner(address remoteSigner_) external onlyOwner {
        _setRemoteSigner(remoteSigner_);
    }
 
    function getParent(address target) public view override returns (address parent) {
        return dgpRegistry.ancestor(projectId, target);
    }

    function getParents(address target, uint256 level) external view override returns (uint256 count, address[] memory parents) {
        (count, parents) = dgpRegistry.ancestors(projectId, target, level);
    }

    function setParent(
        address account,
        address parent,
        bytes calldata signature
    ) external override {
        address oldParent = getParent(account);
        bytes32 structHash = keccak256(abi.encode(address(this), account, oldParent, parent));
        _validSignature(structHash, signature);
        if (oldParent != parent) dgpRegistry.setParent(projectId, account, parent);
    }
}
