// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DisputeTypes
 * @notice Data structures for dispute resolution
 */
library DisputeTypes {
    /**
     * @notice Dispute status enumeration
     */
    enum DisputeStatus {
        NONE,           // No dispute
        PENDING,        // Dispute raised, awaiting resolution
        RESOLVED,       // Dispute resolved
        CANCELLED       // Dispute cancelled
    }

    /**
     * @notice Dispute reason codes
     */
    enum DisputeReason {
        VRF_FAILURE,        // VRF request failed
        SUSPECTED_FRAUD,    // Suspected fraudulent activity
        TECHNICAL_ERROR,    // Smart contract technical error
        OTHER               // Other reasons
    }

    /**
     * @notice Dispute data structure
     */
    struct Dispute {
        uint256 disputeId;
        uint256 roundId;
        address complainant;
        string description;
        DisputeReason reason;
        DisputeStatus status;
        uint256 createdAt;
        uint256 resolvedAt;
        address resolver;
        string resolution;
    }

    /**
     * @notice Resolution action types
     */
    enum ResolutionAction {
        NO_ACTION,          // Dismiss dispute
        REFUND_ALL,         // Refund all participants
        RESELECT_WINNER,    // Request new VRF for winner selection
        CANCEL_ROUND        // Cancel round entirely
    }
}
