// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Constants
 * @notice Protocol constants for FortunaRounds
 */
library Constants {
    // Fee limits
    uint256 internal constant MAX_FEE_BPS = 500; // 5% max fee
    uint256 internal constant BPS_DENOMINATOR = 10000;
    uint256 internal constant DEFAULT_FEE_BPS = 200; // 2% default fee

    // Round defaults
    uint256 internal constant DEFAULT_ROUND_DURATION = 300; // 5 minutes
    uint256 internal constant DEFAULT_MAX_TICKETS = 100;

    // VRF defaults
    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 100000;
    uint16 internal constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 internal constant VRF_NUM_WORDS = 1;
}
