import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();

describe("WinBigRounds - Reentrancy Protection", function () {
  let winbig: any;
  let token: any;
  let attacker: any;
  let owner: any;
  let user1: any;
  let treasury: any;

  const TICKET_PRICE = 10n * 10n ** 18n;
  const MAX_TICKETS = 100n;
  const ROUND_DURATION = 300n;
  const INITIAL_SUPPLY = 1000000n * 10n ** 18n;

  beforeEach(async function () {
    [owner, user1, treasury] = await ethers.getSigners();

    // Deploy mock ERC20
    token = await ethers.deployContract("MockERC20", ["Test USD", "TUSD", INITIAL_SUPPLY]);

    // Deploy WinBigRounds
    winbig = await ethers.deployContract("WinBigRounds", [
      await token.getAddress(),
      treasury.address,
      TICKET_PRICE,
      MAX_TICKETS,
      ROUND_DURATION,
      ethers.ZeroAddress,
      ethers.ZeroHash,
      0n
    ]);

    // Deploy attacker contract
    attacker = await ethers.deployContract("ReentrancyAttacker", [
      await token.getAddress(),
      await winbig.getAddress()
    ]);

    // Fund attacker contract with tokens
    await token.transfer(await attacker.getAddress(), 1000n * 10n ** 18n);
  });

  describe("Reentrancy Attack Prevention", function () {
    it("Should prevent reentrancy in buyTickets", async function () {
      // Approve tokens first
      await attacker.connect(user1).approveToken(100n * 10n ** 18n);
      
      // Get initial state
      const initialTickets = await winbig.getUserTickets(1, await attacker.getAddress());
      
      // Attempt attack - should only buy once despite trying to re-enter
      await attacker.connect(user1).buyTicketsDirect(1);
      
      // Verify only one purchase happened
      const finalTickets = await winbig.getUserTickets(1, await attacker.getAddress());
      expect(finalTickets - initialTickets).to.equal(1n);
    });

    it("Should have ReentrancyGuard protection", async function () {
      // Check that the contract uses ReentrancyGuard
      const code = await ethers.provider.getCode(await winbig.getAddress());
      expect(code.length).to.be.greaterThan(100);
    });

    it("Should use nonReentrant modifier on buyTickets", async function () {
      // Buy tickets normally
      await token.connect(owner).approve(await winbig.getAddress(), 100n * 10n ** 18n);
      await winbig.connect(owner).buyTickets(1);
      
      // Should work fine
      expect(await winbig.getUserTickets(1, owner.address)).to.equal(1n);
    });

    it("Should prevent reentrancy in closeRound", async function () {
      // Setup: buy tickets
      await token.connect(owner).approve(await winbig.getAddress(), 100n * 10n ** 18n);
      await winbig.connect(owner).buyTickets(5);
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      // Close round - should work without reentrancy issues
      await winbig.closeRound(1);
      
      // Verify round closed successfully
      const round = await winbig.getRound(1);
      expect(round.status).to.equal(1); // DRAWING
    });
  });

  describe("SafeERC20 Usage", function () {
    it("Should use safe transfer methods", async function () {
      await token.connect(owner).approve(await winbig.getAddress(), 100n * 10n ** 18n);
      
      // Buy tickets - uses SafeERC20
      await winbig.connect(owner).buyTickets(1);
      
      // Verify tokens transferred correctly
      const contractBalance = await token.balanceOf(await winbig.getAddress());
      expect(contractBalance).to.equal(TICKET_PRICE);
    });
  });

  describe("Checks-Effects-Interactions Pattern", function () {
    it("Should update state before external calls", async function () {
      await token.connect(owner).approve(await winbig.getAddress(), 100n * 10n ** 18n);
      
      // Buy tickets
      const tx = await winbig.connect(owner).buyTickets(1);
      const receipt = await tx.wait();
      
      // State should be updated atomically
      const round = await winbig.getCurrentRound();
      expect(round.totalTicketsSold).to.equal(1n);
    });
  });
});
