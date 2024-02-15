// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../library/DGPAux.sol";
import "../interfaces/IDCPRegistry.sol";
import "../RandomBase.sol";

contract DCPRegistry is ReentrancyGuard, RandomBase, IDCPRegistry {
    using SafeERC20 for IERC20;
    using DGPAux for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event TokenInitialized(address indexed tokenAddress, uint256 indexed tokenId, uint256 randomizer, uint256 id, uint256 birth, uint256 chainId);

    address public constant addressZero = address(0);
    uint16 public instanceChainId = 0;
    uint96 private _mcpCounter;

    struct MCPProperty {
        uint256 randomizer; // random seed
        uint96 id; // unique Id
        uint128 birth; // created block
        uint16 chainId; // origin chain
        mapping(address => mapping(bytes32 => bytes)) additionalProperty;
    }
    // contract => Id => MCPId
    mapping(address => mapping(uint256 => MCPProperty)) private _tokenProperties;

    constructor(address randomizer_) RandomBase(randomizer_) {}

    function initTokenPropertiesBatch(address tokenAddress, uint256[] calldata tokenIds) external override returns (uint256[] memory randomizers) {
        uint256 count = tokenIds.length;
        uint256 chainId;
        uint256 id;
        uint256 randomBase;
        uint128 birth = uint128(block.number);
        randomizers = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) {
            uint256 tokenId = tokenIds[index];
            uint256 randomizer = _tokenProperties[tokenAddress][tokenId].randomizer;
            if (randomizer == 0) {
                if (randomBase == 0) {
                    randomBase = _genRandomNumber();
                    chainId = instanceChainId;
                    id = _mcpCounter;
                }
                randomizer = randomBase;
                _tokenProperties[tokenAddress][tokenId].randomizer = randomizer;
                _tokenProperties[tokenAddress][tokenId].id = uint96(id++);
                _tokenProperties[tokenAddress][tokenId].chainId = uint16(chainId);
                _tokenProperties[tokenAddress][tokenId].birth = birth = uint128(block.number);
                randomBase ^= uint256(keccak256(randomBase.toBytes()));
                emit TokenInitialized(tokenAddress, tokenId, randomizer, id, birth, chainId);
            }
            randomizers[index] = randomizer;
        }
        if (id != 0) _mcpCounter = uint96(id);
    }

    function fetchOrInitTokenProperties(address tokenAddress, uint256 tokenId)
        public
        override
        returns (
            uint256 randomizer,
            uint96 id,
            uint128 birth,
            uint16 chainId
        )
    {
        randomizer = _tokenProperties[tokenAddress][tokenId].randomizer;
        if (randomizer == 0) {
            _tokenProperties[tokenAddress][tokenId].randomizer = randomizer = _genRandomNumber();
            _tokenProperties[tokenAddress][tokenId].id = id = _mcpCounter++;
            _tokenProperties[tokenAddress][tokenId].chainId = chainId = instanceChainId;
            _tokenProperties[tokenAddress][tokenId].birth = birth = uint128(block.number);
            emit TokenInitialized(tokenAddress, tokenId, randomizer, id, birth, chainId);
        } else (randomizer, id, birth, chainId) = fetchTokenProperties(tokenAddress, tokenId);
    }

    function fetchTokenProperties(address tokenAddress, uint256 tokenId)
        public
        view
        override
        returns (
            uint256 randomizer,
            uint96 id,
            uint128 birth,
            uint16 chainId
        )
    {
        birth = _tokenProperties[tokenAddress][tokenId].birth;
        randomizer = _tokenProperties[tokenAddress][tokenId].randomizer;
        id = _tokenProperties[tokenAddress][tokenId].id;
        chainId = _tokenProperties[tokenAddress][tokenId].chainId;
    }

    function setAdditionalProperty(
        address tokenAddress,
        uint256 tokenId,
        bytes32 key,
        bytes calldata data
    ) public override {
        require(_tokenProperties[tokenAddress][tokenId].randomizer > 0, "token not initialized");
        _tokenProperties[tokenAddress][tokenId].additionalProperty[msg.sender][key] = data;
    }

    function setAdditionalPropertyBatch(
        address tokenAddress,
        uint256[] calldata tokenIds,
        bytes32 key,
        bytes[] calldata data
    ) external override {
        for (uint256 index = 0; index < tokenIds.length; ++index) setAdditionalProperty(tokenAddress, tokenIds[index], key, data[index]);
    }

    function getAdditionalProperty(
        address tokenAddress,
        uint256 tokenId,
        address provider,
        bytes32 key
    ) external view override returns (bytes memory data) {
        data = _tokenProperties[tokenAddress][tokenId].additionalProperty[provider][key];
    }
}
