# FortunaRounds - Prize Pool Protocol

A production-grade Solidity smart contract for onchain prize-pool rounds, designed for MiniPay/Celo.

## Overview

FortunaRounds is a decentralized prize-pool protocol where users buy tickets into timed rounds. Each round lasts 5 minutes and selects one winner who receives the prize pool minus platform fees.

### Key Features

- **ERC20 Stablecoin Payments**: Users pay with cUSD or USDC-compatible tokens
- **5-Minute Rounds**: Fixed duration rounds with automatic winner selection
- **Multiple Tickets**: Users can buy multiple tickets to increase winning chances
- **Provably Fair Randomness**: Integration with Chainlink VRF for secure randomness
- **2% Platform Fee**: Configurable fee (max 5%) sent to treasury
- **Security**: ReentrancyGuard, Pausable, Ownable, SafeERC20

## Contract Architecture

### Round Lifecycle

```
OPEN → DRAWING → COMPLETED
                    ↓
               CANCELLED (if 0 tickets)
```

1. **OPEN**: Users can buy tickets
2. **DRAWING**: Round closed, waiting for VRF randomness
3. **COMPLETED**: Winner selected and paid
4. **CANCELLED**: Round with 0 tickets sold

### State Variables

| Variable | Type | Description |
|----------|------|-------------|
| `paymentToken` | IERC20 | ERC20 token for ticket payments |
| `treasury` | address | Treasury wallet for fee collection |
| `feeBps` | uint256 | Platform fee in basis points (default: 200 = 2%) |
| `currentRoundId` | uint256 | ID of the current active round |
| `ticketPrice` | uint256 | Price per ticket in payment tokens |
| `maxTickets` | uint256 | Maximum tickets per round |
| `maxTicketsPerWallet` | uint256 | Maximum tickets per wallet (0 = unlimited) |
| `roundDuration` | uint256 | Round duration in seconds (default: 300 = 5 min) |

### Functions

#### User Functions

- `buyTickets(uint256 ticketAmount)`: Buy tickets for the current round
- `closeRound(uint256 roundId)`: Close an expired or sold-out round
- `getCurrentRound()`: Get current round details
- `getRound(uint256 roundId)`: Get round details by ID
- `getUserTickets(uint256 roundId, address user)`: Get user's ticket count
- `getTicketOwner(uint256 roundId, uint256 ticketIndex)`: Get ticket owner

#### Admin Functions

- `updateTreasury(address newTreasury)`: Update treasury address
- `updateFeeBps(uint256 newFeeBps)`: Update platform fee (max 5%)
- `updateTicketPrice(uint256 newPrice)`: Update ticket price for future rounds
- `updateMaxTickets(uint256 newMax)`: Update max tickets per round
- `updateMaxTicketsPerWallet(uint256 newMax)`: Set per-wallet ticket limit
- `pause()`: Pause contract
- `unpause()`: Unpause contract

### Events

- `RoundCreated(roundId, ticketPrice, maxTickets, startTime, endTime)`
- `TicketsPurchased(roundId, buyer, ticketAmount, totalCost)`
- `RoundClosed(roundId, totalTicketsSold, prizePool)`
- `RandomnessRequested(roundId, requestId)`
- `WinnerSelected(roundId, winner, winningTicketIndex, prizeAmount, protocolFee)`
- `PrizePaid(roundId, winner, amount)`
- `FeePaid(roundId, treasury, amount)`

## Installation

```bash
npm install
```

## Compilation

```bash
npx hardhat compile
```

## Testing

```bash
npx hardhat test mocha
```

## Deployment

### Local Deployment

```bash
npx hardhat ignition deploy ignition/modules/FortunaRounds.ts
```

### Deploy to Celo Alfajores (Testnet)

```bash
npx hardhat ignition deploy --network alfajores ignition/modules/FortunaRounds.ts
```

### Deploy to Celo Mainnet

```bash
npx hardhat ignition deploy --network celo ignition/modules/FortunaRounds.ts
```

### Constructor Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `paymentToken` | address | ERC20 token address (e.g., cUSD) |
| `treasury` | address | Treasury wallet for fees |
| `ticketPrice` | uint256 | Price per ticket |
| `maxTickets` | uint256 | Maximum tickets per round |
| `roundDuration` | uint256 | Round duration in seconds |
| `vrfCoordinator` | address | Chainlink VRF Coordinator address |
| `keyHash` | bytes32 | Chainlink VRF key hash |
| `subscriptionId` | uint64 | Chainlink VRF subscription ID |

## Security Features

- **ReentrancyGuard**: Protects against reentrancy attacks
- **Pausable**: Emergency pause functionality
- **Ownable**: Admin functions restricted to owner
- **SafeERC20**: Safe token transfers
- **Input Validation**: All inputs validated with custom errors
- **Fee Cap**: Maximum 5% fee to protect users
- **No Owner Manipulation**: Owner cannot alter active rounds

## VRF Integration

For production, integrate with Chainlink VRF:

### Celo Mainnet VRF Addresses

```solidity
vrfCoordinator = 0x...;
keyHash = 0x...;
```

### Celo Alfajores VRF Addresses

```solidity
vrfCoordinator = 0x...;
keyHash = 0x...;
```

## Gas Optimization

- Uses mappings for O(1) ticket lookups
- Batch operations for multiple tickets
- Efficient storage layout
- Uses custom errors instead of revert strings

## License

MIT License
