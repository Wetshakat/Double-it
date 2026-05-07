// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Types} from "../libraries/Types.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {WinnerSelector} from "./WinnerSelector.sol";

/**
 * @title AdminManager
 * @notice Handles admin functions and configuration
 */
abstract contract AdminManager is WinnerSelector {
    // ============ Admin Functions ============

    /**
     * @notice Update treasury address
     */
    function updateTreasury(address newTreasury)
        external
        onlyOwner
        validAddress(newTreasury)
    {
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit Events.TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Update platform fee in basis points
     */
    function updateFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > Constants.MAX_FEE_BPS) revert Errors.InvalidFee();
        
        uint256 oldFeeBps = feeBps;
        feeBps = newFeeBps;
        emit Events.FeeUpdated(oldFeeBps, newFeeBps);
    }

    /**
     * @notice Update ticket price (affects future rounds only)
     */
    function updateTicketPrice(uint256 newTicketPrice)
        external
        onlyOwner
        validAmount(newTicketPrice)
    {
        uint256 oldPrice = ticketPrice;
        ticketPrice = newTicketPrice;
        emit Events.TicketPriceUpdated(oldPrice, newTicketPrice);
    }

    /**
     * @notice Update max tickets per round (affects future rounds only)
     */
    function updateMaxTickets(uint256 newMaxTickets)
        external
        onlyOwner
        validAmount(newMaxTickets)
    {
        uint256 oldMax = maxTickets;
        maxTickets = newMaxTickets;
        emit Events.MaxTicketsUpdated(oldMax, newMaxTickets);
    }

    /**
     * @notice Update max tickets per wallet (affects future rounds only)
     */
    function updateMaxTicketsPerWallet(uint256 newMax) external onlyOwner {
        uint256 oldMax = maxTicketsPerWallet;
        maxTicketsPerWallet = newMax;
        emit Events.MaxTicketsPerWalletUpdated(oldMax, newMax);
    }

    /**
     * @notice Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Update VRF configuration
     */
    function updateVRFConfig(
        address newCoordinator,
        bytes32 newKeyHash,
        uint64 newSubscriptionId
    ) external onlyOwner validAddress(newCoordinator) {
        vrfCoordinator = newCoordinator;
        keyHash = newKeyHash;
        subscriptionId = newSubscriptionId;
    }
}
