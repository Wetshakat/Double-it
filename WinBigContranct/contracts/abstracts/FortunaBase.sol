// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Types} from "../libraries/Types.sol";
import {Constants} from "../libraries/Constants.sol";
import {Errors} from "../libraries/Errors.sol";

/**
 * @title FortunaBase
 * @notice Base contract with shared state and modifiers
 */
abstract contract FortunaBase is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ============ State Variables ============
    
    IERC20 public immutable paymentToken;
    address public treasury;
    uint256 public feeBps;
    
    uint256 public currentRoundId;
    uint256 public ticketPrice;
    uint256 public maxTickets;
    uint256 public maxTicketsPerWallet;
    uint256 public roundDuration;

    // ============ Mappings ============
    
    mapping(uint256 => Types.Round) internal _rounds;
    mapping(uint256 => mapping(uint256 => address)) internal _ticketOwners;
    mapping(uint256 => mapping(address => uint256)) internal _userTicketCount;

    // ============ Modifiers ============

    modifier roundExists(uint256 roundId) {
        if (roundId == 0 || roundId > currentRoundId) {
            revert Errors.RoundDoesNotExist();
        }
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert Errors.InvalidAddress();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert Errors.InvalidAmount();
        _;
    }

    // ============ Constructor ============

    constructor(
        address _paymentToken,
        address _treasury,
        uint256 _ticketPrice,
        uint256 _maxTickets,
        uint256 _roundDuration
    ) Ownable(msg.sender) {
        if (_paymentToken == address(0)) revert Errors.InvalidAddress();
        if (_treasury == address(0)) revert Errors.InvalidAddress();
        if (_ticketPrice == 0) revert Errors.InvalidAmount();
        if (_maxTickets == 0) revert Errors.InvalidAmount();

        paymentToken = IERC20(_paymentToken);
        treasury = _treasury;
        ticketPrice = _ticketPrice;
        maxTickets = _maxTickets;
        roundDuration = _roundDuration;
        feeBps = Constants.DEFAULT_FEE_BPS;
    }

    // ============ Internal Functions ============

    function _transferTokens(address from, address to, uint256 amount) internal {
        paymentToken.safeTransferFrom(from, to, amount);
    }

    function _safeTransfer(address to, uint256 amount) internal {
        paymentToken.safeTransfer(to, amount);
    }

    function _calculateFee(uint256 amount) internal view returns (uint256) {
        return (amount * feeBps) / Constants.BPS_DENOMINATOR;
    }
}
