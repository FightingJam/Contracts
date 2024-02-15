// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISquadProvider {
    event JoinSquad(uint256 indexed globalTokenId, uint256 squadLeaderId);
    event LeaveSquad(uint256 indexed globalTokenId, uint256 squadLeaderId);
    
    function joinSquad(uint256 tokenId, uint256 leaderTokenId) external returns (bool isSuccess);

    function leaveSquad(uint256 tokenId) external returns (uint256 leaderId);

    function belongedSquad(uint256 tokenId) external view returns (uint256 leaderId);
}
