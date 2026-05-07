// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Errors
 * @notice Centralized error definitions for FortunaRounds
 */
library Errors {
    // Input validation errors
    error InvalidAmount();
    error InvalidAddress();
    error InvalidFee();

    // Round state errors
    error RoundNotOpen();
    error RoundExpired();
    error RoundSoldOut();
    error RoundStillOpen();
    error AlreadyDrawing();
    error AlreadyCompleted();
    error RoundDoesNotExist();

    // Ticket errors
    error ExceedsMaxPerWallet();
    error NoTicketsSold();

    // VRF errors
    error VRFRequestFailed();
    error InvalidRequest();

    // Transfer errors
    error TransferFailed();
    error InsufficientBalance();
    error InsufficientAllowance();
}
