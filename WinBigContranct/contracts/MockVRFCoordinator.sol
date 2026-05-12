// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockVRFCoordinator
 * @notice Mock VRF coordinator for testing — mimics IVRFCoordinator interface
 */
contract MockVRFCoordinator {
    uint256 private requestCounter;
    mapping(uint256 => address) public consumers;

    function requestRandomWords(
        bytes32, // keyHash
        uint64,  // subId
        uint16,  // minReqConfs
        uint32,  // callbackGasLimit
        uint32   // numWords
    ) external returns (uint256 requestId) {
        requestCounter++;
        requestId = requestCounter;
        consumers[requestId] = msg.sender;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        address consumer = consumers[requestId];
        require(consumer != address(0), "Unknown request");
        (bool success,) = consumer.call(
            abi.encodeWithSignature("fulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "Fulfillment failed");
    }
}
