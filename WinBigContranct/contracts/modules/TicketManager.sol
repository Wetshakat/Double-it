// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Types} from "../libraries/Types.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {WinBigBase} from "../abstracts/WinBigBase.sol";

/**
 * @title TicketManager
 * @notice Handles ticket purchases and management
 */
abstract contract TicketManager is WinBigBase {
    /**
     * @notice Buy tickets for a round
     * @param ticketAmount Number of tickets to purchase
     */
    function buyTickets(uint256 ticketAmount)
        external
        nonReentrant
        whenNotPaused
        validAmount(ticketAmount)
    {
        Types.Round storage round = _rounds[currentRoundId];

        // Validate round state
        if (round.status != Types.RoundStatus.OPEN) revert Errors.RoundNotOpen();
        if (block.timestamp >= round.endTime) revert Errors.RoundExpired();

        // Check ticket availability
        uint256 remainingTickets = round.maxTickets - round.totalTicketsSold;
        if (ticketAmount > remainingTickets) revert Errors.RoundSoldOut();

        // Check max per wallet
        if (maxTicketsPerWallet > 0) {
            uint256 newUserTotal = _userTicketCount[currentRoundId][msg.sender] + ticketAmount;
            if (newUserTotal > maxTicketsPerWallet) revert Errors.ExceedsMaxPerWallet();
        }

        // Calculate cost and transfer tokens
        uint256 totalCost = ticketPrice * ticketAmount;
        _transferTokens(msg.sender, address(this), totalCost);

        // Record tickets
        _recordTickets(currentRoundId, round.totalTicketsSold, ticketAmount, msg.sender);

        // Update round state
        round.totalTicketsSold += ticketAmount;
        round.prizePool += totalCost;

        emit Events.TicketsPurchased(currentRoundId, msg.sender, ticketAmount, totalCost);

        // Auto-close if sold out
        if (round.totalTicketsSold >= round.maxTickets) {
            _closeRound(currentRoundId);
        }
    }

    /**
     * @notice Get user's ticket count for a round
     */
    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (uint256)
    {
        return _userTicketCount[roundId][user];
    }

    /**
     * @notice Get owner of a specific ticket
     */
    function getTicketOwner(uint256 roundId, uint256 ticketIndex)
        external
        view
        returns (address)
    {
        return _ticketOwners[roundId][ticketIndex];
    }

    // ============ Internal Functions ============

    function _recordTickets(
        uint256 roundId,
        uint256 startIndex,
        uint256 amount,
        address buyer
    ) internal {
        for (uint256 i = 0; i < amount; i++) {
            _ticketOwners[roundId][startIndex + i] = buyer;
        }
        _userTicketCount[roundId][buyer] += amount;
    }

    // ============ Abstract Functions ============

    function _closeRound(uint256 roundId) internal virtual;
}
