// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockVRFCoordinator
 * @notice Mock VRF coordinator for testing purposes
 */
contract MockVRFCoordinator {
    uint256 private requestCounter;
    mapping(uint256 => address) public consumers;

    event RandomnessRequested(uint256 requestId, address consumer);

    function requestRandomWords(
        bytes32, // keyHash
        uint64, // subId
        uint16, // minReqConfs
        uint32, // callbackGasLimit
        uint32, // numWords
        address consumer
    ) external returns (uint256 requestId) {
        requestCounter++;
        requestId = requestCounter;
        consumers[requestId] = consumer;
        emit RandomnessRequested(requestId, consumer);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        address consumer = consumers[requestId];
        // Call the consumer's fulfillRandomWords function
        (bool success,) = consumer.call(
            abi.encodeWithSignature("fulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "Fulfillment failed");
    }
}
