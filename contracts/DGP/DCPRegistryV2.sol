// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../library/DGPAux.sol";
import "../interfaces/IDCPRegistryV2.sol";
import "../RandomBase.sol";

contract DCPRegistryV2 is ReentrancyGuard, RandomBase, IDCPRegistryV2 {
    using SafeERC20 for IERC20;
    using DGPAux for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    event TokenInitialized(uint256 indexed globalTokenId, string chainPrefix, address tokenAddress, uint256 originTokenId, uint256 randomizer);

    address public constant addressZero = address(0);

    struct MCPProperty {
        uint256 randomizer; // random seed
        mapping(address => mapping(bytes32 => bytes)) additionalProperty;
    }
    // globalTokenId => MCP
    mapping(uint256 => MCPProperty) private _tokenProperties;

    constructor(address randomizer_) RandomBase(randomizer_) {}

    function initTokenPropertiesBatch(
        string calldata chainPrefix,
        address tokenAddress,
        uint256[] calldata tokenIds
    ) external override returns (uint256[] memory randomizers, uint256[] memory globalTokenIds) {
        uint256 count = tokenIds.length;
        uint256 randomBase = _genRandomNumber();
        randomizers = new uint256[](count);
        globalTokenIds = new uint256[](count);
        for (uint256 index = 0; index < count; ++index) {
            uint256 globalTokenId = hashTokenId(chainPrefix, tokenAddress, tokenIds[index]);
            if (_tokenProperties[globalTokenId].randomizer == 0) {
                _tokenProperties[globalTokenId].randomizer = randomBase;
                randomizers[index] = randomBase;
                emit TokenInitialized(globalTokenId, chainPrefix, tokenAddress, tokenIds[index], randomBase);
                randomBase ^= uint256(keccak256(randomBase.toBytes()));
            } else randomizers[index] = _tokenProperties[globalTokenId].randomizer;
            globalTokenIds[index] = globalTokenId;
        }
    }

    function hashTokenId(
        string calldata chainPrefix,
        address nftContract,
        uint256 tokenId
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(chainPrefix, nftContract, tokenId)));
    }

    function fetchOrInitTokenProperties(
        string calldata chainPrefix,
        address tokenAddress,
        uint256 tokenId
    ) public override returns (uint256 randomizer, uint256 globalTokenId) {
        globalTokenId = hashTokenId(chainPrefix, tokenAddress, tokenId);
        randomizer = _tokenProperties[globalTokenId].randomizer;
        if (randomizer == 0) {
            _tokenProperties[globalTokenId].randomizer = randomizer = _genRandomNumber();
            emit TokenInitialized(globalTokenId, chainPrefix, tokenAddress, tokenId, randomizer);
        } else (randomizer, globalTokenId) = fetchTokenProperties(chainPrefix, tokenAddress, tokenId);
    }

    function fetchTokenProperties(
        string calldata chainPrefix,
        address tokenAddress,
        uint256 tokenId
    ) public view override returns (uint256 randomizer, uint256 globalTokenId) {
        globalTokenId = hashTokenId(chainPrefix, tokenAddress, tokenId);
        randomizer = _tokenProperties[tokenId].randomizer;
    }

    function fetchTokenProperties(uint256 globalTokenId) public view override returns (uint256 randomizer) {
        randomizer = _tokenProperties[globalTokenId].randomizer;
    }

    function setAdditionalProperty(
        uint256 globalTokenId,
        bytes32 key,
        bytes calldata data
    ) public override {
        require(_tokenProperties[globalTokenId].randomizer > 0, "token not initialized");
        _tokenProperties[globalTokenId].additionalProperty[msg.sender][key] = data;
    }

    function setAdditionalPropertyBatch(
        uint256[] calldata globalTokenIds,
        bytes32 key,
        bytes[] calldata data
    ) external override {
        for (uint256 index = 0; index < globalTokenIds.length; ++index) setAdditionalProperty(globalTokenIds[index], key, data[index]);
    }

    function getAdditionalProperty(
        uint256 globalTokenId,
        address provider,
        bytes32 key
    ) external view override returns (bytes memory data) {
        data = _tokenProperties[globalTokenId].additionalProperty[provider][key];
    }

    function hasAdditionalProperty(
        uint256 globalTokenId,
        address provider,
        bytes32 key
    ) external view override returns (bool) {
        return _tokenProperties[globalTokenId].additionalProperty[provider][key].length != 0;
    }
}
