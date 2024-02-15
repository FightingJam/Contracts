// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "../interfaces/IERC1155Minter.sol";
import "../utils/SignerValidator.sol";

contract GadgetDroper is Ownable, SignerValidator, ERC1155Receiver {
    event AirdropUpdates(uint256 indexed id, uint256 payTokenId, uint256 payTokenCount, uint256 tokenId, uint256 tokenCount, uint256 supply, bool requireSigner, bool isClaimable);

    struct Airdrop {
        uint32 payTokenId;
        uint32 payTokenCount;
        uint32 tokenId;
        uint32 tokenCount;
        uint32 supply;
        uint32 totalSupply;
        bool requireSigner;
        bool isClaimable;
    }

    uint256 public airdropCount;
    mapping(uint256 => Airdrop) public airdrops;
    mapping(uint256 => mapping(address => bool)) private _claimed;

    address public immutable godGadgetForge;

    constructor(address remoteSigner_, address godGadgetForge_) SignerValidator(remoteSigner_) {
        godGadgetForge = godGadgetForge_;
    }

    function addAirdrops(
        uint32 payTokenId,
        uint32 payTokenCount,
        uint32 tokenId,
        uint32 tokenCount,
        uint32 supply,
        bool requireSigner
    ) external onlyOwner {
        uint256 count = airdropCount;
        airdrops[count].payTokenId = payTokenId;
        airdrops[count].payTokenCount = payTokenCount;
        airdrops[count].tokenId = tokenId;
        airdrops[count].tokenCount = tokenCount;
        airdrops[count].supply = supply;
        airdrops[count].totalSupply = supply;
        airdrops[count].requireSigner = requireSigner;
        airdrops[count].isClaimable = false;
        airdropCount = count + 1;
    }

    function updateAirdrops(
        uint256 id,
        uint32 payTokenId,
        uint32 payTokenCount,
        uint32 tokenId,
        uint32 tokenCount,
        uint32 supply,
        bool requireSigner
    ) external onlyOwner {
        require(!airdrops[id].isClaimable, "cannot modify claimable order");
        airdrops[id].payTokenId = payTokenId;
        airdrops[id].payTokenCount = payTokenCount;
        airdrops[id].tokenId = tokenId;
        airdrops[id].tokenCount = tokenCount;
        airdrops[id].supply = supply;
        airdrops[id].requireSigner = requireSigner;
    }

    function markClaimable(uint256 id) external onlyOwner {
        require(id < airdropCount && !airdrops[id].isClaimable, "cannot mark claimable");
        airdrops[id].isClaimable = true;
    }

    function hasClaimed(address account, uint256 id) public view returns (bool) {
        return _claimed[id][account];
    }

    function hasClaimedBatch(address account, uint256[] calldata ids) external view returns (bool[] memory) {
        bool[] memory claims = new bool[](ids.length);
        for (uint256 index = 0; index < ids.length; ++index) claims[index] = _claimed[ids[index]][account];
        return claims;
    }

    function _claim(
        address account,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) private {
        (uint256 id, bytes memory signature) = abi.decode(data, (uint256, bytes));
        require(!hasClaimed(account, id), "already claimed");
        require(airdrops[id].isClaimable, "not claimable");
        require(airdrops[id].payTokenCount == amount, "token count not correct");
        require(airdrops[id].payTokenId == tokenId, "token id not correct");
        if (airdrops[id].requireSigner) {
            bytes32 msgHash = keccak256(abi.encode(address(this), account, id));
            _validSignature(msgHash, signature);
        }
        uint256 supply = airdrops[id].supply - 1;
        airdrops[id].supply = uint32(supply);
        if (supply == 0) airdrops[id].isClaimable = false;
        _claimed[id][account] = true;
        IERC1155Minter(godGadgetForge).mint(account, airdrops[id].tokenId, airdrops[id].tokenCount, "");
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        require(msg.sender == godGadgetForge, "only accept GodGadget transfer");
        require(operator == from && tx.origin == from, "should send from owner only");
        _claim(from, id, value, data);
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
}
