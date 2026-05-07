import { ethers } from "hardhat";

async function main() {
  const paymentToken = process.env.CUSDC_ALFAJORES!;
  const treasury = process.env.TREASURY_ADDRESS!;
  const vrfCoordinator = process.env.VRF_COORDINATOR_ALFAJORES!;
  const keyHash = process.env.KEY_HASH_ALFAJORES!;
  const subscriptionId = BigInt(process.env.VRF_SUBSCRIPTION_ID_ALFAJORES || "0");

  console.log("Deploying WinBigRounds to Alfajores...");
  console.log({
    paymentToken,
    treasury,
    vrfCoordinator,
    keyHash,
    subscriptionId: subscriptionId.toString()
  });

  const WinBigRounds = await ethers.getContractFactory("WinBigRounds");
  const fortuna = await WinBigRounds.deploy(
    paymentToken,
    treasury,
    ethers.parseEther("10"), // 10 cUSD per ticket
    100, // max 100 tickets per round
    300, // 5 minutes
    vrfCoordinator,
    keyHash,
    subscriptionId
  );

  await fortuna.waitForDeployment();
  const address = await fortuna.getAddress();
  
  console.log(`WinBigRounds deployed to: ${address}`);
  console.log(`Verify with: npx hardhat verify --network alfajores ${address} ${paymentToken} ${treasury} ${ethers.parseEther("10")} 100 300 ${vrfCoordinator} ${keyHash} ${subscriptionId}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
