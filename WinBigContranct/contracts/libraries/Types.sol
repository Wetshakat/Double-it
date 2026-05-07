// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Types
 * @notice Data structures for FortunaRounds
 */
library Types {
    /**
     * @notice Round status enumeration
     */
    enum RoundStatus {
        OPEN,       // Users can buy tickets
        DRAWING,    // Round closed, waiting for VRF
        COMPLETED,  // Winner selected and paid
        CANCELLED   // Round with 0 tickets
    }

    /**
     * @notice Round data structure
     */
    struct Round {
        uint256 roundId;
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 totalTicketsSold;
        uint256 startTime;
        uint256 endTime;
        uint256 prizePool;
        address winner;
        RoundStatus status;
    }

    /**
     * @notice VRF configuration
     */
    struct VRFConfig {
        address coordinator;
        bytes32 keyHash;
        uint64 subscriptionId;
    }

    /**
     * @notice Round parameters for creation
     */
    struct RoundParams {
        uint256 ticketPrice;
        uint256 maxTickets;
        uint256 duration;
    }
}
