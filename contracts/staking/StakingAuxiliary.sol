// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/**
 * @dev Auxiliary contract for StakingDan, all the funtion are 'view' function
 */
contract StakingAuxiliary {
    function getOfficialStakingTokenBatch(
        address account,
        address stakingContract,
        uint256 pId,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            uint256 tokenCount,
            uint256[] memory tokenIds,
            uint256[] memory stakingBlocks,
            uint256[] memory pendingAG,
            uint256[] memory pendingDGT
        )
    {
        IPossiblePorts port = IPossiblePorts(stakingContract);
        tokenCount = port.userStakedTokenCount(pId, account);
        if (offset + limit > tokenCount) limit = tokenCount - offset;
        tokenIds = new uint256[](limit);
        stakingBlocks = new uint256[](limit);
        pendingAG = new uint256[](limit);
        pendingDGT = new uint256[](limit);
        for (uint256 index = 0; index < limit; ++index) {
            uint256 tokenId = port.userStakedTokenByIndex(pId, account, offset + index);
            tokenIds[index] = tokenId;
            pendingAG[index] = port.pendingAG(tokenId);
            pendingDGT[index] = port.pendingDGT(tokenId);
            (, , uint256 lastRewardBlock, ) = port.miners(tokenId);
            stakingBlocks[index] = block.number - lastRewardBlock;
        }
    }

    function getLordStakingTokenBatch(
        address account,
        address stakingContract,
        uint256 pId,
        uint256 offset,
        uint256 limit
    )
        external
        view
        returns (
            uint256 tokenCount,
            uint256[] memory tokenIds,
            uint256[] memory stakingBlocks,
            uint256[] memory pendingAG
        )
    {
        IPossiblePorts port = IPossiblePorts(stakingContract);
        tokenCount = port.userStakedTokenCount(pId, account);
        if (offset + limit > tokenCount) limit = tokenCount - offset;
        tokenIds = new uint256[](limit);
        stakingBlocks = new uint256[](limit);
        pendingAG = new uint256[](limit); 
        for (uint256 index = 0; index < limit; ++index) {
            uint256 tokenId = port.userStakedTokenByIndex(pId, account, index + offset);
            tokenIds[index] = tokenId;
            pendingAG[index] = port.pendingAG(tokenId);
            (, uint256 lastRewardBlock, ) = IPossiblePorts2(stakingContract).miners(tokenId);
            stakingBlocks[index] = block.number - lastRewardBlock;
        }
    }
}

interface IPossiblePorts {
    /**
     * @dev get the pending balance for one pool
     */
    function pendingAG(uint256 tokenId) external view returns (uint256 pending);

    function pendingDGT(uint256 tokenId) external view returns (uint256 pending);

    function userStakedTokenCount(uint256 pId, address account) external view returns (uint256 count);

    function userStakedTokenByIndex(
        uint256 pId,
        address account,
        uint256 index
    ) external view returns (uint256 tokenId);

    function miners(uint256 tokenId)
        external
        view
        returns (
            uint32 agPoint,
            uint32 dgtPoint,
            uint64 lastRewardBlock,
            uint128 rewardDebt
        );
}

interface IPossiblePorts2 {
    function miners(uint256 tokenId)
        external
        view
        returns (
            uint32 agPoint,
            uint64 lastRewardBlock,
            address owner
        );
}
