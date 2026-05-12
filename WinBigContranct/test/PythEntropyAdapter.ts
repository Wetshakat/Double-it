import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();

/**
 * MockPythEntropy — simulates IEntropyV2 for testing the adapter
 */
const MOCK_PYTH_ABI = [
  "function getFeeV2() view returns (uint256)",
  "function requestV2() payable returns (uint64)",
  "function fulfillRequest(uint64 sequenceNumber, address provider, bytes32 randomNumber) external"
];

describe("PythEntropyAdapter", function () {
  let adapter: any;
  let mockPyth: any;
  let mockWinBig: any;
  let owner: any;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    // Deploy a minimal mock Pyth Entropy contract
    const MockPyth = await ethers.getContractFactory("MockPythEntropy");
    mockPyth = await MockPyth.deploy();

    // Deploy adapter pointing at mock Pyth
    adapter = await ethers.deployContract("PythEntropyAdapter", [await mockPyth.getAddress()]);

    // Deploy a mock consumer (WinBigRounds stand-in)
    const MockConsumer = await ethers.getContractFactory("MockEntropyConsumer");
    mockWinBig = await MockConsumer.deploy(await adapter.getAddress());
  });

  it("Should request randomness and receive callback", async function () {
    // Fund adapter
    await adapter.fundAdapter({ value: ethers.parseEther("0.1") });

    // Consumer requests randomness
    const tx = await mockWinBig.requestRandom();
    const receipt = await tx.wait();

    // Get sequenceNumber from MockPyth event
    const seqEvent = receipt.logs
      .map((l: any) => { try { return mockPyth.interface.parseLog(l); } catch { return null; } })
      .find((e: any) => e?.name === "Requested");
    const sequenceNumber = seqEvent.args[0];

    // Pyth fulfills the request
    const randomNumber = ethers.id("test-random");
    await mockPyth.fulfillRequest(sequenceNumber, await mockPyth.getAddress(), randomNumber);

    // Consumer should have received the random word
    const received = await mockWinBig.lastRandomWord();
    expect(received).to.equal(BigInt(randomNumber));
  });

  it("Should revert if adapter has insufficient CELO for fee", async function () {
    // adapter has no CELO — call adapter directly so we get the custom error
    await expect(
      adapter.requestRandomWords(ethers.ZeroHash, 0n, 0n, 0n, 1n)
    ).to.be.revertedWithCustomError(adapter, "InsufficientFee");
  });
});
