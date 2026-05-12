// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockEntropyConsumer
 * @notice Simulates WinBigRounds for adapter testing — calls requestRandomWords
 *         and receives fulfillRandomWords callback
 */
contract MockEntropyConsumer {
    address public adapter;
    uint256 public lastRequestId;
    uint256 public lastRandomWord;

    constructor(address _adapter) {
        adapter = _adapter;
    }

    function requestRandom() external {
        (bool success, bytes memory data) = adapter.call(
            abi.encodeWithSignature(
                "requestRandomWords(bytes32,uint64,uint16,uint32,uint32)",
                bytes32(0), uint64(0), uint16(0), uint32(0), uint32(1)
            )
        );
        require(success, "requestRandomWords failed");
        lastRequestId = abi.decode(data, (uint256));
    }

    // Called by adapter — mirrors WinBigRounds.fulfillRandomWords signature
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        require(msg.sender == adapter, "Only adapter");
        lastRequestId = requestId;
        lastRandomWord = randomWords[0];
    }
}
