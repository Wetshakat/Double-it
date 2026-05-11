// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import {Types} from "../libraries/Types.sol";
import {DisputeTypes} from "../libraries/DisputeTypes.sol";
import {Errors} from "../libraries/Errors.sol";
import {Events} from "../libraries/Events.sol";
import {AdminManager} from "./AdminManager.sol";

/**
 * @title DisputeManager
 * @notice Handles dispute resolution for WinBigRounds
 * @dev Adds dispute mechanisms without breaking existing functionality
 */
abstract contract DisputeManager is AdminManager, AccessControl {
    using DisputeTypes for DisputeTypes.Dispute;

    // ============ Constants ============
    
    bytes32 public constant ARBITER_ROLE = keccak256("ARBITER_ROLE");
    uint256 public constant DISPUTE_TIMEOUT = 1 hours; // Time to resolve disputes
    
    // ============ State Variables ============
    
    uint256 public disputeCounter;
    uint256 public disputeFee; // Fee to raise dispute (prevents spam)
    
    mapping(uint256 => DisputeTypes.Dispute) public disputes;
    mapping(uint256 => uint256[]) public roundDisputes; // roundId => disputeIds
    
    // ============ Events ============
    
    event DisputeRaised(
        uint256 indexed disputeId,
        uint256 indexed roundId,
        address indexed complainant,
        DisputeTypes.DisputeReason reason
    );
    
    event DisputeResolved(
        uint256 indexed disputeId,
        uint256 indexed roundId,
        address indexed resolver,
        DisputeTypes.ResolutionAction action
    );
    
    event EmergencyRefund(
        uint256 indexed roundId,
        address indexed user,
        uint256 amount
    );

    // ============ Modifiers ============

    modifier onlyArbiter() {
        if (!hasRole(ARBITER_ROLE, msg.sender) && owner() != msg.sender) {
            revert Errors.InvalidAddress();
        }
        _;
    }

    modifier disputeExists(uint256 disputeId) {
        if (disputes[disputeId].disputeId == 0) revert Errors.RoundDoesNotExist();
        _;
    }

    // ============ Constructor ============

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ARBITER_ROLE, msg.sender);
        disputeFee = 1e18; // 1 token (in payment token decimals)
    }

    // ============ External Functions ============

    /**
     * @notice Raise a dispute for a round
     * @param roundId The round in question
     * @param reason Reason code for dispute
     * @param description Human-readable description
     */
    function raiseDispute(
        uint256 roundId,
        DisputeTypes.DisputeReason reason,
        string calldata description
    ) external roundExists(roundId) {
        // Only ticket holders can raise disputes
        if (_userTicketCount[roundId][msg.sender] == 0) {
            revert Errors.InvalidAmount();
        }

        // Collect dispute fee in payment token
        if (disputeFee > 0) {
            _transferTokens(msg.sender, address(this), disputeFee);
        }

        // Create dispute
        disputeCounter++;
        disputes[disputeCounter] = DisputeTypes.Dispute({
            disputeId: disputeCounter,
            roundId: roundId,
            complainant: msg.sender,
            description: description,
            reason: reason,
            status: DisputeTypes.DisputeStatus.PENDING,
            createdAt: block.timestamp,
            resolvedAt: 0,
            resolver: address(0),
            resolution: ""
        });

        roundDisputes[roundId].push(disputeCounter);

        emit DisputeRaised(disputeCounter, roundId, msg.sender, reason);
    }

    /**
     * @notice Resolve a dispute (arbiter only)
     * @param disputeId The dispute to resolve
     * @param action Resolution action to take
     * @param resolution Notes on the resolution
     */
    function resolveDispute(
        uint256 disputeId,
        DisputeTypes.ResolutionAction action,
        string calldata resolution
    ) external onlyArbiter disputeExists(disputeId) {
        DisputeTypes.Dispute storage dispute = disputes[disputeId];
        
        if (dispute.status != DisputeTypes.DisputeStatus.PENDING) {
            revert Errors.AlreadyCompleted();
        }

        dispute.status = DisputeTypes.DisputeStatus.RESOLVED;
        dispute.resolvedAt = block.timestamp;
        dispute.resolver = msg.sender;
        dispute.resolution = resolution;

        // Execute resolution action
        _executeResolution(dispute.roundId, action);

        emit DisputeResolved(disputeId, dispute.roundId, msg.sender, action);
    }

    /**
     * @notice Emergency refund all users in a round
     * @param roundId The round to refund
     */
    function emergencyRefund(uint256 roundId)
        external
        onlyArbiter
        roundExists(roundId)
    {
        Types.Round storage round = _rounds[roundId];
        
        // Can only refund OPEN or DRAWING rounds
        if (round.status == Types.RoundStatus.COMPLETED ||
            round.status == Types.RoundStatus.CANCELLED) {
            revert Errors.AlreadyCompleted();
        }

        // Mark round as cancelled
        round.status = Types.RoundStatus.CANCELLED;

        // Refund all ticket holders
        // Note: This is gas-intensive for large rounds
        // Consider pull pattern for production
        uint256 totalSold = round.totalTicketsSold;
        for (uint256 i = 0; i < totalSold; i++) {
            address ticketOwner = _ticketOwners[roundId][i];
            uint256 userTickets = _userTicketCount[roundId][ticketOwner];
            
            if (userTickets > 0) {
                uint256 refundAmount = userTickets * round.ticketPrice;
                _safeTransfer(ticketOwner, refundAmount);
                
                emit EmergencyRefund(roundId, ticketOwner, refundAmount);
                
                // Reset to prevent double refund
                _userTicketCount[roundId][ticketOwner] = 0;
            }
        }

        emit Events.RoundCancelled(roundId);
    }

    // ============ View Functions ============

    /**
     * @notice Get all disputes for a round
     */
    function getRoundDisputes(uint256 roundId)
        external
        view
        returns (uint256[] memory)
    {
        return roundDisputes[roundId];
    }

    /**
     * @notice Check if round has pending disputes
     */
    function hasPendingDisputes(uint256 roundId) external view returns (bool) {
        uint256[] memory disputeIds = roundDisputes[roundId];
        for (uint256 i = 0; i < disputeIds.length; i++) {
            if (disputes[disputeIds[i]].status == DisputeTypes.DisputeStatus.PENDING) {
                return true;
            }
        }
        return false;
    }

    // ============ Admin Functions ============

    /**
     * @notice Add arbiter role
     */
    function addArbiter(address arbiter) external onlyOwner {
        grantRole(ARBITER_ROLE, arbiter);
    }

    /**
     * @notice Remove arbiter role
     */
    function removeArbiter(address arbiter) external onlyOwner {
        revokeRole(ARBITER_ROLE, arbiter);
    }

    /**
     * @notice Update dispute fee
     */
    function updateDisputeFee(uint256 newFee) external onlyOwner {
        disputeFee = newFee;
    }

    /**
     * @notice Withdraw accumulated dispute fees to treasury
     */
    function withdrawDisputeFees() external onlyOwner {
        uint256 balance = paymentToken.balanceOf(address(this));
        // Only withdraw what isn't locked in active prize pools
        // Dispute fees are any balance above the sum of active prize pools
        uint256 activePrizePool = _rounds[currentRoundId].prizePool;
        uint256 withdrawable = balance > activePrizePool ? balance - activePrizePool : 0;
        if (withdrawable > 0) {
            _safeTransfer(treasury, withdrawable);
        }
    }

    // ============ Internal Functions ============

    function _executeResolution(
        uint256 roundId,
        DisputeTypes.ResolutionAction action
    ) internal {
        Types.Round storage round = _rounds[roundId];

        if (action == DisputeTypes.ResolutionAction.REFUND_ALL) {
            _emergencyRefundInternal(roundId);
        } else if (action == DisputeTypes.ResolutionAction.RESELECT_WINNER) {
            // Only if in DRAWING state
            if (round.status == Types.RoundStatus.DRAWING) {
                round.status = Types.RoundStatus.OPEN;
                _requestRandomness(roundId);
            }
        } else if (action == DisputeTypes.ResolutionAction.CANCEL_ROUND) {
            round.status = Types.RoundStatus.CANCELLED;
            emit Events.RoundCancelled(roundId);
            _createNewRound();
        }
        // NO_ACTION: do nothing
    }

    function _emergencyRefundInternal(uint256 roundId) internal {
        Types.Round storage round = _rounds[roundId];
        
        // Mark round as cancelled
        round.status = Types.RoundStatus.CANCELLED;

        // Refund all ticket holders
        uint256 totalSold = round.totalTicketsSold;
        for (uint256 i = 0; i < totalSold; i++) {
            address ticketOwner = _ticketOwners[roundId][i];
            uint256 userTickets = _userTicketCount[roundId][ticketOwner];
            
            if (userTickets > 0) {
                uint256 refundAmount = userTickets * round.ticketPrice;
                _safeTransfer(ticketOwner, refundAmount);
                
                emit EmergencyRefund(roundId, ticketOwner, refundAmount);
                
                // Reset to prevent double refund
                _userTicketCount[roundId][ticketOwner] = 0;
            }
        }

        emit Events.RoundCancelled(roundId);
    }
}
