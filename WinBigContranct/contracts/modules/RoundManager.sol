// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Types} from "../libraries/Types.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {TicketManager} from "./TicketManager.sol";

/**
 * @title RoundManager
 * @notice Handles round lifecycle management
 */
abstract contract RoundManager is TicketManager {
    /**
     * @notice Close an expired or sold-out round
     * @param roundId Round to close
     */
    function closeRound(uint256 roundId)
        external
        nonReentrant
        whenNotPaused
        roundExists(roundId)
    {
        Types.Round storage round = _rounds[roundId];

        if (round.status == Types.RoundStatus.COMPLETED) revert Errors.AlreadyCompleted();
        if (round.status == Types.RoundStatus.DRAWING) revert Errors.AlreadyDrawing();
        
        if (block.timestamp < round.endTime && round.totalTicketsSold < round.maxTickets) {
            revert Errors.RoundStillOpen();
        }

        _closeRound(roundId);
    }

    /**
     * @notice Create a new round (if current is completed)
     */
    function createNewRound() external {
        Types.Round storage currentRound = _rounds[currentRoundId];
        
        if (currentRound.status != Types.RoundStatus.COMPLETED &&
            currentRound.status != Types.RoundStatus.CANCELLED) {
            revert Errors.RoundStillOpen();
        }
        
        _createNewRound();
    }

    /**
     * @notice Get current round details
     */
    function getCurrentRound() external view returns (Types.Round memory) {
        return _rounds[currentRoundId];
    }

    /**
     * @notice Get round details by ID
     */
    function getRound(uint256 roundId)
        external
        view
        roundExists(roundId)
        returns (Types.Round memory)
    {
        return _rounds[roundId];
    }

    // ============ Internal Functions ============

    function _createNewRound() internal {
        currentRoundId++;
        
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + roundDuration;

        _rounds[currentRoundId] = Types.Round({
            roundId: currentRoundId,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            totalTicketsSold: 0,
            startTime: startTime,
            endTime: endTime,
            prizePool: 0,
            winner: address(0),
            status: Types.RoundStatus.OPEN
        });

        emit Events.RoundCreated(
            currentRoundId,
            ticketPrice,
            maxTickets,
            startTime,
            endTime
        );
    }

    function _closeRound(uint256 roundId) internal override {
        Types.Round storage round = _rounds[roundId];

        // Cancel if no tickets sold
        if (round.totalTicketsSold == 0) {
            round.status = Types.RoundStatus.CANCELLED;
            emit Events.RoundCancelled(roundId);
            _createNewRound();
            return;
        }

        // Start drawing process
        round.status = Types.RoundStatus.DRAWING;
        emit Events.RoundClosed(roundId, round.totalTicketsSold, round.prizePool);

        // Request randomness
        _requestRandomness(roundId);
    }

    // ============ Abstract Functions ============

    function _requestRandomness(uint256 roundId) internal virtual;
}
