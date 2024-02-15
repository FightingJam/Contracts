// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../utils/MinterGuard.sol";
import "../interfaces/IERC1155Minter.sol";

contract GodGadget is Ownable, ERC1155, MinterGuard, IERC1155Minter {
    using Strings for uint256;

    event MintBatch(address indexed operator, address to, uint256[] tokenId, uint256[] amounts);
    event Mint(address indexed operator, address to, uint256 tokenId, uint256 amount);

    string public name;
    string public symbol;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_
    ) ERC1155(uri_) {
        name = name_;
        symbol = symbol_;
    }

    function setURI(string calldata uri_) external onlyOwner {
        _setURI(uri_);
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        return string(abi.encodePacked(super.uri(id), id.toString(), ".json"));
    }

    function mint(
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) external override onlyMinter {
        _mint(to, tokenId, amount, data);
        emit Mint(msg.sender, to, tokenId, amount);
    }

    function mintBatch(
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata data
    ) external override onlyMinter {
        _mintBatch(to, tokenIds, amounts, data);
        emit MintBatch(msg.sender, to, tokenIds, amounts);
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) external override {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved"); 
        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) external override {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()), "ERC1155: caller is not owner nor approved"); 
        _burnBatch(account, ids, values);
    }
}
