// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ISummonTicketClient is IERC1155 {
    function mint(
        address account,
        uint256 ticketId,
        uint256 amount,
        bytes calldata data
    ) external;

    function mintBatch(
        address[] calldata accounts,
        uint256 ticketId,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    function burn(
        address account,
        uint256 ticketId,
        uint256 amount
    ) external;

    function burnBatch(
        address account,
        uint256[] calldata ticketIds,
        uint256[] calldata amounts
    ) external;
}
