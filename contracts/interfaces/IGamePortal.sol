// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGamePortal {
     function isAddressRegisted(address account) external view returns (bool) ;

    function getAccountId(address account) external view returns (string memory) ;

    function getAccountAddress(string calldata accountId) external view returns (address) ;
}
