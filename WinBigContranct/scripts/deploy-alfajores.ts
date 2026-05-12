import { ethers } from "hardhat";

/**
 * Deploy PythEntropyAdapter then WinBigRounds to Celo Alfajores.
 *
 * Pyth Entropy on Celo Alfajores: 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c
 * cUSD on Celo Alfajores:         0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1
 *
 * Required .env vars:
 *   TREASURY_ADDRESS
 *   ALFAJORES_PRIVATE_KEY
 *
 * Optional .env vars (defaults shown):
 *   PYTH_ENTROPY_ALFAJORES   (default: 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c)
 *   CUSDC_ALFAJORES          (default: 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1)
 *   TICKET_PRICE_WEI         (default: 1 cUSD = 1e18)
 *   MAX_TICKETS              (default: 100)
 *   ROUND_DURATION_SECS      (default: 300)
 *   ADAPTER_FUND_CELO        (default: 0.1 CELO — covers ~10 Pyth requests)
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);

  const entropyAddress  = process.env.PYTH_ENTROPY_ALFAJORES  ?? "0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c";
  const paymentToken    = process.env.CUSDC_ALFAJORES          ?? "0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1";
  const treasury        = process.env.TREASURY_ADDRESS;
  const ticketPrice     = BigInt(process.env.TICKET_PRICE_WEI  ?? ethers.parseEther("1").toString());
  const maxTickets      = BigInt(process.env.MAX_TICKETS        ?? "100");
  const roundDuration   = BigInt(process.env.ROUND_DURATION_SECS ?? "300");
  const adapterFund     = ethers.parseEther(process.env.ADAPTER_FUND_CELO ?? "0.1");

  if (!treasury) throw new Error("Missing TREASURY_ADDRESS in .env");

  // ── 1. Deploy adapter ──────────────────────────────────────────────────────
  console.log("\nDeploying PythEntropyAdapter...");
  const adapter = await ethers.deployContract("PythEntropyAdapter", [entropyAddress]);
  await adapter.waitForDeployment();
  const adapterAddress = await adapter.getAddress();
  console.log(`PythEntropyAdapter: ${adapterAddress}`);

  // ── 2. Fund adapter with CELO to cover Pyth fees ──────────────────────────
  console.log(`\nFunding adapter with ${ethers.formatEther(adapterFund)} CELO...`);
  const fundTx = await adapter.fundAdapter({ value: adapterFund });
  await fundTx.wait();
  console.log("Adapter funded.");

  // ── 3. Deploy WinBigRounds ─────────────────────────────────────────────────
  console.log("\nDeploying WinBigRounds...");
  const winBig = await ethers.deployContract("WinBigRounds", [
    paymentToken,
    treasury,
    ticketPrice,
    maxTickets,
    roundDuration,
    adapterAddress,   // vrfCoordinator = our adapter
    ethers.ZeroHash,  // keyHash — unused by Pyth
    0n                // subscriptionId — unused by Pyth
  ]);
  await winBig.waitForDeployment();
  const winBigAddress = await winBig.getAddress();
  console.log(`WinBigRounds: ${winBigAddress}`);

  console.log("\n── Deployment complete ──────────────────────────────────────");
  console.log(`PythEntropyAdapter : ${adapterAddress}`);
  console.log(`WinBigRounds       : ${winBigAddress}`);
  console.log("\nVerify adapter:");
  console.log(`  npx hardhat verify --network alfajores ${adapterAddress} ${entropyAddress}`);
  console.log("\nVerify WinBigRounds:");
  console.log(`  npx hardhat verify --network alfajores ${winBigAddress} ${paymentToken} ${treasury} ${ticketPrice} ${maxTickets} ${roundDuration} ${adapterAddress} ${ethers.ZeroHash} 0`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
