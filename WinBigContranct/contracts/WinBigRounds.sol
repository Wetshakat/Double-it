// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WinBigRounds
 * @notice Main entry point for the WinBigRounds prize pool protocol
 * @dev Inherits all modular functionality from DisputeManager
 *
 * Architecture:
 * ├── WinBigRounds.sol (Main contract)
 * │   └── DisputeManager.sol (Dispute resolution)
 * │       └── AdminManager.sol (Admin functions)
 * │           └── WinnerSelector.sol (Winner selection & payouts)
 * │               └── RoundManager.sol (Round lifecycle)
 * │                   └── TicketManager.sol (Ticket purchases)
 * │                       └── WinBigBase.sol (Shared state & utilities)
 * │
 * ├── libraries/
 * │   ├── Types.sol (Data structures)
 * │   ├── Constants.sol (Protocol constants)
 * │   ├── Errors.sol (Error definitions)
 * │   ├── Events.sol (Event definitions)
 * │   └── DisputeTypes.sol (Dispute structures)
 * │
 * └── interfaces/
 *     └── IWinBigRounds.sol (Public interface)
 *
 * Round Lifecycle:
 * OPEN → DRAWING → COMPLETED
 *              ↓
 *         CANCELLED (if 0 tickets)
 */
import {DisputeManager} from "./modules/DisputeManager.sol";
import {WinBigBase} from "./abstracts/WinBigBase.sol";
import {WinnerSelector} from "./modules/WinnerSelector.sol";

contract WinBigRounds is DisputeManager {
    /**
     * @notice Initialize WinBigRounds protocol
     * @param _paymentToken ERC20 token for ticket payments
     * @param _treasury Treasury wallet for fee collection
     * @param _ticketPrice Price per ticket
     * @param _maxTickets Maximum tickets per round
     * @param _roundDuration Round duration in seconds
     * @param _vrfCoordinator Chainlink VRF coordinator address
     * @param _keyHash Chainlink VRF key hash
     * @param _subscriptionId Chainlink VRF subscription ID
     */
    constructor(
        address _paymentToken,
        address _treasury,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _roundDuration,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        WinBigBase(_paymentToken, _treasury, _ticketPrice, _maxTickets, _roundDuration)
        WinnerSelector(_vrfCoordinator, _keyHash, _subscriptionId)
    {
        // Create first round
        _createNewRound();
    }
}


