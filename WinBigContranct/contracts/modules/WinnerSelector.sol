// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Types} from "../libraries/Types.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {RoundManager} from "./RoundManager.sol";

interface IVRFCoordinator {
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}

/**
 * @title WinnerSelector
 * @notice Handles winner selection and prize distribution via Chainlink VRF
 */
abstract contract WinnerSelector is RoundManager {
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;

    mapping(uint256 => uint256) internal _requestToRound;

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) {
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;
    }

    /**
     * @notice Callback called by VRF coordinator — only coordinator can call this
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != vrfCoordinator) revert Errors.InvalidRequest();

        uint256 roundId = _requestToRound[requestId];
        if (roundId == 0) revert Errors.InvalidRequest();

        Types.Round storage round = _rounds[roundId];
        if (round.status != Types.RoundStatus.DRAWING) revert Errors.AlreadyCompleted();

        _selectWinner(roundId, randomWords[0]);
    }

    // ============ Internal Functions ============

    function _requestRandomness(uint256 roundId) internal override {
        uint256 requestId = IVRFCoordinator(vrfCoordinator).requestRandomWords(
            keyHash,
            subscriptionId,
            Constants.VRF_REQUEST_CONFIRMATIONS,
            Constants.VRF_CALLBACK_GAS_LIMIT,
            Constants.VRF_NUM_WORDS
        );

        _requestToRound[requestId] = roundId;
        emit Events.RandomnessRequested(roundId, requestId);
    }

    function _selectWinner(uint256 roundId, uint256 randomNumber) internal {
        Types.Round storage round = _rounds[roundId];

        uint256 winningTicketIndex = randomNumber % round.totalTicketsSold;
        address winner = _ticketOwners[roundId][winningTicketIndex];

        uint256 protocolFee = _calculateFee(round.prizePool);
        uint256 prizeAmount = round.prizePool - protocolFee;

        round.winner = winner;
        round.status = Types.RoundStatus.COMPLETED;

        emit Events.WinnerSelected(roundId, winner, winningTicketIndex, prizeAmount, protocolFee);

        _safeTransfer(winner, prizeAmount);
        emit Events.PrizePaid(roundId, winner, prizeAmount);

        _safeTransfer(treasury, protocolFee);
        emit Events.FeePaid(roundId, treasury, protocolFee);

        _createNewRound();
    }
}
