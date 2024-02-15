// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract AGMagnifier is VRFConsumerBaseV2, Ownable {
    // Subscription ID.

    event Randomfulfilled(uint256 indexed reqId, uint256[] numbers);

    uint64 immutable s_subscriptionId;
    address constant vrfCoordinator = 0x6A2AAd07396B36Fe02a22b33cf443582f682c82f;
    bytes32 constant keyHash = 0xd4bb89654db74673a187bd804519e65e3f71a52bc55f11da7601a13dcf505314;
    uint32 constant callbackGasLimit = 10000;
    uint16 constant requestConfirmations = 3;
    uint32 constant numWords = 1;

    VRFCoordinatorV2Interface public immutable COORDINATOR;

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    function requestRandomWords() private returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(keyHash, s_subscriptionId, requestConfirmations, callbackGasLimit, numWords);
    }

    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        emit Randomfulfilled(requestId, randomWords);
    }
}
