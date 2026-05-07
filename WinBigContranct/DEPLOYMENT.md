# FortunaRounds Deployment Guide

## Prerequisites

### 1. Install Dependencies
```bash
npm install
```

### 2. Get Testnet Tokens

#### Get Alfajores CELO
1. Visit [Celo Alfajores Faucet](https://celo.org/developers/faucet)
2. Enter your wallet address
3. Receive testnet CELO for gas fees

#### Get Testnet cUSD
1. Visit [Celo Alfajores Faucet](https://celo.org/developers/faucet)
2. Request cUSD tokens
3. Or use the Mento Exchange to swap CELO for cUSD

### 3. Setup Wallet

1. Create a new wallet or use existing one
2. Export the private key (MetaMask: Account Details → Export Private Key)
3. Fund the wallet with Alfajores CELO (for gas)

## Environment Setup

### 1. Configure .env File

```bash
cp .env.example .env
```

Edit `.env` with your values:

```bash
# Celo Alfajores Testnet
ALFAJORES_RPC_URL=https://alfajores-forno.celo-testnet.org
ALFAJORES_PRIVATE_KEY=your_private_key_without_0x_prefix

# Payment Token (cUSD on Alfajores)
CUSDC_ALFAJORES=0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1

# Treasury Wallet (where fees go)
TREASURY_ADDRESS=your_treasury_wallet_address

# Chainlink VRF (Alfajores - Already configured)
VRF_COORDINATOR_ALFAJORES=0xbd13f082824249580e7247B383Bc83654a637d44
KEY_HASH_ALFAJORES=0x6e092a9b38c4f6d8d8c9c8d1f4b5a3c2e1d0f9a8b7c6d5e4f3a2b1c0d9e8f7a6
VRF_SUBSCRIPTION_ID_ALFAJORES=0
```

## Chainlink VRF Setup (Required for Production)

### 1. Create VRF Subscription

1. Visit [Chainlink VRF Subscription Manager](https://vrf.chain.link/)
2. Connect your wallet (Alfajores network)
3. Create a new subscription
4. Fund the subscription with LINK tokens
5. Note your subscription ID

### 2. Add Consumer Contract

After deploying FortunaRounds:
1. Go to your subscription on VRF Subscription Manager
2. Add the deployed contract address as a consumer

## Deployment

### Option 1: Using Hardhat Ignition (Recommended)

```bash
# Deploy to Alfajores testnet
npx hardhat ignition deploy ignition/modules/FortunaRounds.ts --network alfajores \
  --parameters '{
    "FortunaRounds": {
      "paymentToken": "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1",
      "treasury": "YOUR_TREASURY_ADDRESS",
      "vrfCoordinator": "0xbd13f082824249580e7247B383Bc83654a637d44",
      "keyHash": "0x6e092a9b38c4f6d8d8c9c8d1f4b5a3c2e1d0f9a8b7c6d5e4f3a2b1c0d9e8f7a6",
      "subscriptionId": "YOUR_SUBSCRIPTION_ID"
    }
  }'
```

### Option 2: Using Deployment Script

```bash
npx hardhat run scripts/deploy-alfajores.ts --network alfajores
```

## Post-Deployment

### 1. Verify Contract

```bash
npx hardhat verify --network alfajores <CONTRACT_ADDRESS> \
  <PAYMENT_TOKEN> \
  <TREASURY> \
  <TICKET_PRICE> \
  <MAX_TICKETS> \
  <ROUND_DURATION> \
  <VRF_COORDINATOR> \
  <KEY_HASH> \
  <SUBSCRIPTION_ID>
```

### 2. Add Contract to VRF Subscription

1. Visit [Chainlink VRF Subscription Manager](https://vrf.chain.link/)
2. Select your subscription
3. Add consumer: `<CONTRACT_ADDRESS>`

### 3. Test the Contract

```bash
# Buy tickets (need cUSD approval first)
npx hardhat console --network alfajores
```

```javascript
const fortuna = await ethers.getContractAt("FortunaRounds", "YOUR_CONTRACT_ADDRESS");
const token = await ethers.getContractAt("IERC20", "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1");

// Approve tokens
await token.approve("YOUR_CONTRACT_ADDRESS", ethers.parseEther("100"));

// Buy tickets
await fortuna.buyTickets(1);
```

## Contract Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Ticket Price | 10 cUSD | Price per ticket |
| Max Tickets | 100 | Maximum tickets per round |
| Round Duration | 300 sec | 5 minutes |
| Platform Fee | 2% | Configurable up to 5% |

## Alfajores Contract Addresses

| Contract | Address |
|----------|---------|
| cUSD (Testnet) | `0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1` |
| CELO (Testnet) | `0xF194afDf50B03e69Bd7D057c1Aa9e10c9954E4C9` |
| VRF Coordinator | `0xbd13f082824249580e7247B383Bc83654a637d44` |

## Security Checklist

- [ ] Never commit `.env` file
- [ ] Use a dedicated deployment wallet
- [ ] Verify all constructor parameters
- [ ] Test thoroughly on testnet before mainnet
- [ ] Fund VRF subscription with enough LINK
- [ ] Set appropriate treasury address
- [ ] Verify contract on block explorer

## Troubleshooting

### Insufficient Funds
```
Error: insufficient funds for gas * price + value
```
Solution: Get more testnet CELO from faucet

### VRF Request Failed
```
Error: VRF request failed
```
Solution: 
1. Check VRF subscription is funded
2. Verify contract is added as consumer
3. Check keyHash matches network

### Token Transfer Failed
```
Error: ERC20: transfer amount exceeds balance
```
Solution: Get testnet cUSD from faucet

## Mainnet Deployment

For mainnet deployment, update `.env` with:

```bash
CELO_RPC_URL=https://forno.celo.org
CELO_PRIVATE_KEY=your_mainnet_private_key
CUSDC_CELO=0x765DE816845861e75A25fCA122bb6898B8B1282a
VRF_COORDINATOR_CELO=<mainnet_vrf_coordinator>
KEY_HASH_CELO=<mainnet_key_hash>
VRF_SUBSCRIPTION_ID_CELO=<mainnet_subscription_id>
```

Then deploy:
```bash
npx hardhat ignition deploy ignition/modules/FortunaRounds.ts --network celo
```
