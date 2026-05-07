// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ReentrancyAttacker
 * @notice Malicious contract attempting re-entrancy attack on WinBigRounds
 */
contract ReentrancyAttacker {
    IERC20 public token;
    address public target;
    uint256 public attackCount;
    bool public attacking;

    constructor(address _token, address _target) {
        token = IERC20(_token);
        target = _target;
    }

    // Receive function called during token transfer
    receive() external payable {
        if (attacking && attackCount < 3) {
            attackCount++;
            // Try to buy more tickets during the transfer
            try this.attackBuyTickets(1) {
                // Attack succeeded - this is bad!
            } catch {
                // Attack failed - re-entrancy protection working
            }
        }
    }

    function attackBuyTickets(uint256 amount) external {
        token.approve(target, type(uint256).max);
        attacking = true;
        
        // Call buyTickets on target
        (bool success,) = target.call(
            abi.encodeWithSignature("buyTickets(uint256)", amount)
        );
        
        attacking = false;
        require(success, "Attack failed");
    }

    function approveToken(uint256 amount) external {
        token.approve(target, amount);
    }

    function buyTicketsDirect(uint256 amount) external {
        (bool success,) = target.call(
            abi.encodeWithSignature("buyTickets(uint256)", amount)
        );
        require(success, "Direct buy failed");
    }

    function withdrawTokens() external {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
