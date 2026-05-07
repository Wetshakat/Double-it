// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFortunaRounds
 * @notice Interface for the FortunaRounds prize pool protocol
 */
interface IFortunaRounds {
    // ============ Enums ============
    enum RoundStatus { OPEN, DRAWING, COMPLETED, CANCELLED }

    // ============ Structs ============
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

    // ============ Events ============
    event RoundCreated(uint256 indexed roundId, uint256 ticketPrice, uint256 maxTickets, uint256 startTime, uint256 endTime);
    event TicketsPurchased(uint256 indexed roundId, address indexed buyer, uint256 ticketAmount, uint256 totalCost);
    event RoundClosed(uint256 indexed roundId, uint256 totalTicketsSold, uint256 prizePool);
    event RandomnessRequested(uint256 indexed roundId, uint256 requestId);
    event WinnerSelected(uint256 indexed roundId, address winner, uint256 winningTicketIndex, uint256 prizeAmount, uint256 protocolFee);
    event PrizePaid(uint256 indexed roundId, address winner, uint256 amount);
    event FeePaid(uint256 indexed roundId, address treasury, uint256 amount);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event TicketPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event MaxTicketsUpdated(uint256 oldMax, uint256 newMax);
    event RoundCancelled(uint256 indexed roundId);

    // ============ Errors ============
    error InvalidAmount();
    error InvalidAddress();
    error InvalidFee();
    error RoundNotOpen();
    error RoundExpired();
    error RoundSoldOut();
    error ExceedsMaxPerWallet();
    error NoTicketsSold();
    error AlreadyDrawing();
    error AlreadyCompleted();
    error RoundStillOpen();
    error VRFRequestFailed();
    error TransferFailed();

    // ============ View Functions ============
    function paymentToken() external view returns (address);
    function treasury() external view returns (address);
    function feeBps() external view returns (uint256);
    function currentRoundId() external view returns (uint256);
    function ticketPrice() external view returns (uint256);
    function maxTickets() external view returns (uint256);
    function maxTicketsPerWallet() external view returns (uint256);
    function roundDuration() external view returns (uint256);
    
    function getCurrentRound() external view returns (Round memory);
    function getRound(uint256 roundId) external view returns (Round memory);
    function getUserTickets(uint256 roundId, address user) external view returns (uint256);
    function getTicketOwner(uint256 roundId, uint256 ticketIndex) external view returns (address);

    // ============ User Functions ============
    function buyTickets(uint256 ticketAmount) external;
    function closeRound(uint256 roundId) external;
    function createNewRound() external;

    // ============ Admin Functions ============
    function updateTreasury(address newTreasury) external;
    function updateFeeBps(uint256 newFeeBps) external;
    function updateTicketPrice(uint256 newTicketPrice) external;
    function updateMaxTickets(uint256 newMaxTickets) external;
    function updateMaxTicketsPerWallet(uint256 newMax) external;
    function pause() external;
    function unpause() external;
}
