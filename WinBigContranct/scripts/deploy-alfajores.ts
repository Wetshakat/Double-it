import { ethers } from "hardhat";

/**
 * Celo Alfajores deployment
 *
 * Randomness: Pyth Entropy (https://docs.pyth.network/entropy)
 * Celo Alfajores Entropy: 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c
 *
 * NOTE: WinBigRounds uses a generic IVRFCoordinator interface. For Pyth Entropy,
 * you will need to deploy a thin adapter contract that implements IVRFCoordinator
 * and wraps Pyth's requestWithCallback / entropyCallback pattern.
 * Set VRF_COORDINATOR_ALFAJORES to your adapter address.
 *
 * cUSD Alfajores: 0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1
 */
async function main() {
  const paymentToken = process.env.CUSDC_ALFAJORES;
  const treasury = process.env.TREASURY_ADDRESS;
  const vrfCoordinator = process.env.VRF_COORDINATOR_ALFAJORES;
  const keyHash = process.env.KEY_HASH_ALFAJORES ?? ethers.ZeroHash;
  const subscriptionId = BigInt(process.env.VRF_SUBSCRIPTION_ID_ALFAJORES ?? "0");

  if (!paymentToken) throw new Error("Missing CUSDC_ALFAJORES");
  if (!treasury) throw new Error("Missing TREASURY_ADDRESS");
  if (!vrfCoordinator) throw new Error("Missing VRF_COORDINATOR_ALFAJORES");

  const TICKET_PRICE = ethers.parseEther("1");  // 1 cUSD per ticket
  const MAX_TICKETS = 100n;
  const ROUND_DURATION = 300n; // 5 minutes

  console.log("Deploying WinBigRounds to Celo Alfajores...");
  console.log({ paymentToken, treasury, vrfCoordinator, keyHash, subscriptionId: subscriptionId.toString() });

  const [deployer] = await ethers.getSigners();
  console.log(`Deployer: ${deployer.address}`);

  const WinBigRounds = await ethers.getContractFactory("WinBigRounds");
  const contract = await WinBigRounds.deploy(
    paymentToken,
    treasury,
    TICKET_PRICE,
    MAX_TICKETS,
    ROUND_DURATION,
    vrfCoordinator,
    keyHash,
    subscriptionId
  );

  await contract.waitForDeployment();
  const address = await contract.getAddress();

  console.log(`\nWinBigRounds deployed to: ${address}`);
  console.log(`\nVerify with:`);
  console.log(`npx hardhat verify --network alfajores ${address} ${paymentToken} ${treasury} ${TICKET_PRICE} ${MAX_TICKETS} ${ROUND_DURATION} ${vrfCoordinator} ${keyHash} ${subscriptionId}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
