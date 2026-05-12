// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

/**
 * @title PythEntropyAdapter
 * @notice Bridges Pyth Entropy to the IVRFCoordinator interface used by WinBigRounds.
 *
 * Flow:
 *   WinBigRounds._requestRandomness()
 *     → PythEntropyAdapter.requestRandomWords()   (IVRFCoordinator interface)
 *       → IEntropyV2.requestV2()                  (Pyth)
 *         → PythEntropyAdapter.entropyCallback()  (Pyth calls back)
 *           → WinBigRounds.fulfillRandomWords()   (IVRFCoordinator callback)
 *
 * Deployment:
 *   1. Deploy PythEntropyAdapter(entropyAddress)
 *   2. Pass adapter address as vrfCoordinator to WinBigRounds constructor
 *   3. Fund the adapter with native CELO to cover Pyth fees (use fundAdapter())
 */
contract PythEntropyAdapter is IEntropyConsumer {
    IEntropyV2 public immutable entropy;

    // sequenceNumber → consumer (WinBigRounds address)
    mapping(uint64 => address) private _pendingRequests;
    // sequenceNumber → requestId (passed back to WinBigRounds)
    mapping(uint64 => uint256) private _sequenceToRequestId;

    uint256 private _requestCounter;

    event RandomnessRequested(uint256 indexed requestId, uint64 sequenceNumber);
    event RandomnessFulfilled(uint256 indexed requestId, uint64 sequenceNumber);

    error InsufficientFee(uint256 required, uint256 provided);
    error UnknownSequence(uint64 sequenceNumber);

    constructor(address entropyAddress) {
        entropy = IEntropyV2(entropyAddress);
    }

    /**
     * @notice IVRFCoordinator-compatible request function called by WinBigRounds
     * @dev Caller must ensure this adapter holds enough CELO to cover the Pyth fee.
     *      Use fundAdapter() or send CELO directly to this contract.
     */
    function requestRandomWords(
        bytes32, // keyHash — unused, Pyth uses default provider
        uint64,  // subId  — unused
        uint16,  // minReqConfs — unused
        uint32,  // callbackGasLimit — unused, Pyth handles gas
        uint32   // numWords — always 1 for Pyth
    ) external returns (uint256 requestId) {
        uint256 fee = entropy.getFeeV2();
        if (address(this).balance < fee) revert InsufficientFee(fee, address(this).balance);

        uint64 sequenceNumber = entropy.requestV2{value: fee}();

        _requestCounter++;
        requestId = _requestCounter;

        _pendingRequests[sequenceNumber] = msg.sender;
        _sequenceToRequestId[sequenceNumber] = requestId;

        emit RandomnessRequested(requestId, sequenceNumber);
    }

    /**
     * @notice Called by Pyth Entropy when randomness is ready
     */
    function entropyCallback(
        uint64 sequenceNumber,
        address, // provider — unused
        bytes32 randomNumber
    ) internal override {
        address consumer = _pendingRequests[sequenceNumber];
        if (consumer == address(0)) revert UnknownSequence(sequenceNumber);

        uint256 requestId = _sequenceToRequestId[sequenceNumber];

        delete _pendingRequests[sequenceNumber];
        delete _sequenceToRequestId[sequenceNumber];

        emit RandomnessFulfilled(requestId, sequenceNumber);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = uint256(randomNumber);

        // Call WinBigRounds.fulfillRandomWords
        (bool success,) = consumer.call(
            abi.encodeWithSignature("fulfillRandomWords(uint256,uint256[])", requestId, randomWords)
        );
        require(success, "fulfillRandomWords failed");
    }

    /**
     * @notice Required by IEntropyConsumer — returns the Entropy contract address
     */
    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    /**
     * @notice Fund this adapter with CELO to cover Pyth fees
     */
    function fundAdapter() external payable {}

    /**
     * @notice Withdraw leftover CELO (owner pattern kept simple — use a multisig in prod)
     */
    function withdraw(address payable to, uint256 amount) external {
        // In production, restrict this to an owner/multisig
        (bool success,) = to.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {}
}
