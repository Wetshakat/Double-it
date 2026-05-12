// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockPythEntropy
 * @notice Minimal IEntropyV2 mock for testing PythEntropyAdapter
 */
contract MockPythEntropy {
    uint64 private _seq;
    mapping(uint64 => address) public consumers;

    event Requested(uint64 sequenceNumber, address consumer);

    function getFeeV2() external pure returns (uint256) {
        return 0.001 ether;
    }

    function requestV2() external payable returns (uint64 sequenceNumber) {
        require(msg.value >= 0.001 ether, "Insufficient fee");
        _seq++;
        sequenceNumber = _seq;
        consumers[sequenceNumber] = msg.sender;
        emit Requested(sequenceNumber, msg.sender);
    }

    // Simulates Pyth fulfilling a request — calls _entropyCallback on the adapter
    function fulfillRequest(uint64 sequenceNumber, address provider, bytes32 randomNumber) external {
        address consumer = consumers[sequenceNumber];
        require(consumer != address(0), "Unknown sequence");
        (bool success,) = consumer.call(
            abi.encodeWithSignature(
                "_entropyCallback(uint64,address,bytes32)",
                sequenceNumber, provider, randomNumber
            )
        );
        require(success, "Callback failed");
    }
}
