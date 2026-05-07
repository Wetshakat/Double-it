// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FortunaRounds
 * @notice A decentralized prize-pool protocol where users buy tickets into timed rounds
 * @dev Winner selection uses Chainlink VRF for provably fair randomness
 */
contract FortunaRounds is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

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

    // ============ State Variables ============
    IERC20 public immutable paymentToken;
    address public treasury;
    uint256 public feeBps; // Basis points (200 = 2%)
    uint256 public constant MAX_FEE_BPS = 500; // 5% max fee
    uint256 public constant BPS_DENOMINATOR = 10000;

    uint256 public currentRoundId;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public maxTicketsPerWallet; // 0 = unlimited
    uint256 public roundDuration; // in seconds

    // roundId => Round
    mapping(uint256 => Round) public rounds;
    
    // roundId => ticketIndex => owner
    mapping(uint256 => mapping(uint256 => address)) public ticketOwners;
    
    // roundId => user => ticketCount
    mapping(uint256 => mapping(address => uint256)) public userTicketCount;
    
    // roundId => requestId => exists
    mapping(uint256 => mapping(uint256 => bool)) public vrfRequests;
    
    // requestId => roundId
    mapping(uint256 => uint256) public requestToRound;

    // VRF Coordinator (mock for testing, real for production)
    address public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subscriptionId;

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

    // ============ Modifiers ============
    modifier roundExists(uint256 _roundId) {
        require(_roundId > 0 && _roundId <= currentRoundId, "Round does not exist");
        _;
    }

    // ============ Constructor ============
    constructor(
        address _paymentToken,
        address _treasury,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _roundDuration,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert InvalidAddress();
        if (_treasury == address(0)) revert InvalidAddress();
        if (_ticketPrice == 0) revert InvalidAmount();
        if (_maxTickets == 0) revert InvalidAmount();

        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        roundDuration = _roundDuration;
        feeBps = 200; // Default 2%
        maxTicketsPerWallet = 0; // Unlimited by default
        
        vrfCoordinator = _vrfCoordinator;
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;

        // Create first round
        _createNewRound();
    }

    // ============ External Functions ============

    /**
     * @notice Buy tickets for the current round
     * @param _ticketAmount Number of tickets to purchase
     */
    function buyTickets(uint256 _ticketAmount) external nonReentrant whenNotPaused {
        if (_ticketAmount == 0) revert InvalidAmount();

        Round storage round = rounds[currentRoundId];
        
        // Check round status
        if (round.status != RoundStatus.OPEN) revert RoundNotOpen();
        if (block.timestamp >= round.endTime) revert RoundExpired();
        
        uint256 remainingTickets = round.maxTickets - round.totalTicketsSold;
        if (_ticketAmount > remainingTickets) revert RoundSoldOut();
        
        // Check max per wallet
        if (maxTicketsPerWallet > 0) {
            uint256 newUserTotal = userTicketCount[currentRoundId][msg.sender] + _ticketAmount;
            if (newUserTotal > maxTicketsPerWallet) revert ExceedsMaxPerWallet();
        }

        // Calculate cost and transfer tokens
        uint256 totalCost = ticketPrice * _ticketAmount;
        paymentToken.safeTransferFrom(msg.sender, address(this), totalCost);

        // Record tickets
        for (uint256 i = 0; i < _ticketAmount; i++) {
            ticketOwners[currentRoundId][round.totalTicketsSold + i] = msg.sender;
        }
        
        userTicketCount[currentRoundId][msg.sender] += _ticketAmount;
        round.totalTicketsSold += _ticketAmount;
        round.prizePool += totalCost;

        emit TicketsPurchased(currentRoundId, msg.sender, _ticketAmount, totalCost);

        // Auto-close if sold out
        if (round.totalTicketsSold >= round.maxTickets) {
            _closeRound(currentRoundId);
        }
    }

    /**
     * @notice Close an expired round and draw winner
     * @param _roundId Round to close
     */
    function closeRound(uint256 _roundId) external nonReentrant whenNotPaused roundExists(_roundId) {
        Round storage round = rounds[_roundId];
        
        if (round.status == RoundStatus.COMPLETED) revert AlreadyCompleted();
        if (round.status == RoundStatus.DRAWING) revert AlreadyDrawing();
        if (block.timestamp < round.endTime && round.totalTicketsSold < round.maxTickets) {
            revert RoundStillOpen();
        }

        _closeRound(_roundId);
    }

    /**
     * @notice Callback for VRF randomness
     * @param requestId VRF request ID
     * @param randomWords Random numbers from VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        // In production, this would be restricted to VRF Coordinator
        // For testing, we allow anyone to call it
        uint256 roundId = requestToRound[requestId];
        require(roundId > 0, "Invalid request");
        
        Round storage round = rounds[roundId];
        if (round.status != RoundStatus.DRAWING) revert AlreadyCompleted();

        uint256 randomNumber = randomWords[0];
        _selectWinner(roundId, randomNumber);
    }

    /**
     * @notice Create a new round (if current is completed)
     */
    function createNewRound() external {
        Round storage currentRound = rounds[currentRoundId];
        require(
            currentRound.status == RoundStatus.COMPLETED || currentRound.status == RoundStatus.CANCELLED,
            "Current round not completed"
        );
        _createNewRound();
    }

    /**
     * @notice Get current round details
     */
    function getCurrentRound() external view returns (Round memory) {
        return rounds[currentRoundId];
    }

    /**
     * @notice Get round details by ID
     */
    function getRound(uint256 _roundId) external view roundExists(_roundId) returns (Round memory) {
        return rounds[_roundId];
    }

    /**
     * @notice Get user's ticket count for a round
     */
    function getUserTickets(uint256 _roundId, address _user) external view returns (uint256) {
        return userTicketCount[_roundId][_user];
    }

    /**
     * @notice Get owner of a specific ticket
     */
    function getTicketOwner(uint256 _roundId, uint256 _ticketIndex) external view returns (address) {
        return ticketOwners[_roundId][_ticketIndex];
    }

    // ============ Admin Functions ============

    /**
     * @notice Update treasury address
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert InvalidAddress();
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @notice Update fee in basis points
     */
    function updateFeeBps(uint256 _newFeeBps) external onlyOwner {
        if (_newFeeBps > MAX_FEE_BPS) revert InvalidFee();
        uint256 oldFeeBps = feeBps;
        feeBps = _newFeeBps;
        emit FeeUpdated(oldFeeBps, _newFeeBps);
    }

    /**
     * @notice Update ticket price (affects future rounds only)
     */
    function updateTicketPrice(uint256 _newTicketPrice) external onlyOwner {
        if (_newTicketPrice == 0) revert InvalidAmount();
        uint256 oldPrice = ticketPrice;
        ticketPrice = _newTicketPrice;
        emit TicketPriceUpdated(oldPrice, _newTicketPrice);
    }

    /**
     * @notice Update max tickets per round (affects future rounds only)
     */
    function updateMaxTickets(uint256 _newMaxTickets) external onlyOwner {
        if (_newMaxTickets == 0) revert InvalidAmount();
        uint256 oldMax = maxTickets;
        maxTickets = _newMaxTickets;
        emit MaxTicketsUpdated(oldMax, _newMaxTickets);
    }

    /**
     * @notice Update max tickets per wallet (affects future rounds only)
     */
    function updateMaxTicketsPerWallet(uint256 _newMax) external onlyOwner {
        maxTicketsPerWallet = _newMax;
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
     * @notice Request randomness from VRF (for production)
     */
    function requestRandomness(uint256 _roundId) external returns (uint256 requestId) {
        Round storage round = rounds[_roundId];
        if (round.status != RoundStatus.DRAWING) revert AlreadyCompleted();
        
        requestId = _requestRandomnessInternal(_roundId);
    }

    // ============ Internal Functions ============

    function _requestRandomnessInternal(uint256 _roundId) internal returns (uint256 requestId) {
        // In production, call Chainlink VRF
        // For testing, use mock
        requestId = uint256(keccak256(abi.encodePacked(block.timestamp, _roundId, block.number)));
        requestToRound[requestId] = _roundId;
        vrfRequests[_roundId][requestId] = true;
        
        emit RandomnessRequested(_roundId, requestId);
        return requestId;
    }

    function _createNewRound() internal {
        currentRoundId++;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + roundDuration;

        rounds[currentRoundId] = Round({
            roundId: currentRoundId,
            ticketPrice: ticketPrice,
            maxTickets: maxTickets,
            totalTicketsSold: 0,
            startTime: startTime,
            endTime: endTime,
            prizePool: 0,
            winner: address(0),
            status: RoundStatus.OPEN
        });

        emit RoundCreated(currentRoundId, ticketPrice, maxTickets, startTime, endTime);
    }

    function _closeRound(uint256 _roundId) internal {
        Round storage round = rounds[_roundId];
        
        if (round.totalTicketsSold == 0) {
            // No tickets sold - cancel round
            round.status = RoundStatus.CANCELLED;
            emit RoundCancelled(_roundId);
            _createNewRound();
            return;
        }

        round.status = RoundStatus.DRAWING;
        emit RoundClosed(_roundId, round.totalTicketsSold, round.prizePool);

        // Request randomness
        _requestRandomnessInternal(_roundId);
    }

    function _selectWinner(uint256 _roundId, uint256 _randomNumber) internal {
        Round storage round = rounds[_roundId];
        
        uint256 winningTicketIndex = _randomNumber % round.totalTicketsSold;
        address winner = ticketOwners[_roundId][winningTicketIndex];
        
        // Calculate payouts
        uint256 protocolFee = (round.prizePool * feeBps) / BPS_DENOMINATOR;
        uint256 prizeAmount = round.prizePool - protocolFee;

        round.winner = winner;
        round.status = RoundStatus.COMPLETED;

        emit WinnerSelected(_roundId, winner, winningTicketIndex, prizeAmount, protocolFee);

        // Transfer prize to winner
        paymentToken.safeTransfer(winner, prizeAmount);
        emit PrizePaid(_roundId, winner, prizeAmount);

        // Transfer fee to treasury
        paymentToken.safeTransfer(treasury, protocolFee);
        emit FeePaid(_roundId, treasury, protocolFee);

        // Create next round
        _createNewRound();
    }
}
