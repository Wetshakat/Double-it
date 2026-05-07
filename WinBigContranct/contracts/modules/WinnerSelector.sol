// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Types} from "../libraries/Types.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {RoundManager} from "./RoundManager.sol";

/**
 * @title WinnerSelector
 * @notice Handles winner selection and prize distribution
 */
abstract contract WinnerSelector is RoundManager {
    // VRF state
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;

    // Request tracking
    mapping(uint256 => mapping(uint256 => bool)) internal _vrfRequests;
    mapping(uint256 => uint256) internal _requestToRound;

    // ============ Constructor ============

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) {
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    // ============ External Functions ============

    /**
     * @notice Callback for VRF randomness
     * @param requestId VRF request ID
     * @param randomWords Random numbers from VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        uint256 roundId = _requestToRound[requestId];
        if (roundId == 0) revert Errors.InvalidRequest();

        Types.Round storage round = _rounds[roundId];
        if (round.status != Types.RoundStatus.DRAWING) revert Errors.AlreadyCompleted();

        uint256 randomNumber = randomWords[0];
        _selectWinner(roundId, randomNumber);
    }

    /**
     * @notice Request randomness from VRF
     */
    function requestRandomness(uint256 roundId) external returns (uint256 requestId) {
        Types.Round storage round = _rounds[roundId];
        if (round.status != Types.RoundStatus.DRAWING) revert Errors.AlreadyCompleted();

        requestId = _requestRandomnessInternal(roundId);
    }

    // ============ Internal Functions ============

    function _requestRandomness(uint256 roundId) internal override {
        _requestRandomnessInternal(roundId);
    }

    function _requestRandomnessInternal(uint256 roundId) internal returns (uint256 requestId) {
        // Generate deterministic request ID for testing
        // In production, call Chainlink VRF coordinator
        requestId = uint256(keccak256(abi.encodePacked(block.timestamp, roundId, block.number)));
        
        _requestToRound[requestId] = roundId;
        _vrfRequests[roundId][requestId] = true;

        emit Events.RandomnessRequested(roundId, requestId);
        
        return requestId;
    }

    function _selectWinner(uint256 roundId, uint256 randomNumber) internal {
        Types.Round storage round = _rounds[roundId];

        // Select winning ticket
        uint256 winningTicketIndex = randomNumber % round.totalTicketsSold;
        address winner = _ticketOwners[roundId][winningTicketIndex];

        // Calculate payouts
        uint256 protocolFee = _calculateFee(round.prizePool);
        uint256 prizeAmount = round.prizePool - protocolFee;

        // Update round state
        round.winner = winner;
        round.status = Types.RoundStatus.COMPLETED;

        emit Events.WinnerSelected(
            roundId,
            winner,
            winningTicketIndex,
            prizeAmount,
            protocolFee
        );

        // Transfer prize to winner
        _safeTransfer(winner, prizeAmount);
        emit Events.PrizePaid(roundId, winner, prizeAmount);

        // Transfer fee to treasury
        _safeTransfer(treasury, protocolFee);
        emit Events.FeePaid(roundId, treasury, protocolFee);

        // Create next round
        _createNewRound();
    }
}
