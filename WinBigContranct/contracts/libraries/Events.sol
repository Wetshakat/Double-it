// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Events
 * @notice Centralized event definitions for FortunaRounds
 */
library Events {
    // Round events
    event RoundCreated(
        uint256 indexed roundId,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 startTime,
        uint256 endTime
    );

    event RoundClosed(
        uint256 indexed roundId,
        uint256 totalTicketsSold,
        uint256 prizePool
    );

    event RoundCancelled(uint256 indexed roundId);

    // Ticket events
    event TicketsPurchased(
        uint256 indexed roundId,
        address indexed buyer,
        uint256 ticketAmount,
        uint256 totalCost
    );

    // VRF events
    event RandomnessRequested(
        uint256 indexed roundId,
        uint256 requestId
    );

    // Winner events
    event WinnerSelected(
        uint256 indexed roundId,
        address winner,
        uint256 winningTicketIndex,
        uint256 prizeAmount,
        uint256 protocolFee
    );

    event PrizePaid(
        uint256 indexed roundId,
        address winner,
        uint256 amount
    );

    event FeePaid(
        uint256 indexed roundId,
        address treasury,
        uint256 amount
    );

    // Admin events
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TicketPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event MaxTicketsUpdated(uint256 oldMax, uint256 newMax);
    event MaxTicketsPerWalletUpdated(uint256 oldMax, uint256 newMax);
    event VRFConfigUpdated(address newCoordinator, bytes32 newKeyHash, uint64 newSubscriptionId);
}
