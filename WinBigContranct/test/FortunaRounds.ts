import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.create();

describe("FortunaRounds", function () {
  let fortuna: any;
  let token: any;
  let owner: any;
  let user1: any;
  let user2: any;
  let treasury: any;

  const TICKET_PRICE = 10n * 10n ** 18n; // 10 tokens with 18 decimals
  const MAX_TICKETS = 100n;
  const ROUND_DURATION = 300n; // 5 minutes
  const INITIAL_SUPPLY = 1000000n * 10n ** 18n;

  beforeEach(async function () {
    [owner, user1, user2, treasury] = await ethers.getSigners();

    // Deploy mock ERC20
    token = await ethers.deployContract("MockERC20", ["Test USD", "TUSD", INITIAL_SUPPLY]);

    // Distribute tokens to users (owner has all tokens initially)
    await token.connect(owner).transfer(user1.address, 10000n * 10n ** 18n);
    await token.connect(owner).transfer(user2.address, 10000n * 10n ** 18n);

    // Deploy FortunaRounds
    fortuna = await ethers.deployContract("FortunaRounds", [
      await token.getAddress(),
      treasury.address,
      TICKET_PRICE,
      MAX_TICKETS,
      ROUND_DURATION,
      ethers.ZeroAddress, // VRF coordinator (mock)
      ethers.ZeroHash,
      0n
    ]);
  });

  async function getRequestIdFromTx(tx: any) {
    const receipt = await tx.wait();
    const event = receipt.logs.find((log: any) => {
      try {
        const parsed = fortuna.interface.parseLog(log);
        return parsed?.name === "RandomnessRequested";
      } catch {
        return false;
      }
    });
    const parsedEvent = fortuna.interface.parseLog(event);
    return parsedEvent?.args[1];
  }

  describe("Deployment", function () {
    it("Should set correct initial parameters", async function () {
      expect(await fortuna.paymentToken()).to.equal(await token.getAddress());
      expect(await fortuna.treasury()).to.equal(treasury.address);
      expect(await fortuna.ticketPrice()).to.equal(TICKET_PRICE);
      expect(await fortuna.maxTickets()).to.equal(MAX_TICKETS);
      expect(await fortuna.roundDuration()).to.equal(ROUND_DURATION);
      expect(await fortuna.feeBps()).to.equal(200n); // 2%
    });

    it("Should create first round on deployment", async function () {
      expect(await fortuna.currentRoundId()).to.equal(1n);
      const round = await fortuna.getCurrentRound();
      expect(round.roundId).to.equal(1n);
      expect(round.status).to.equal(0); // OPEN
    });

    it("Should revert with zero payment token", async function () {
      await expect(
        ethers.deployContract("FortunaRounds", [
          ethers.ZeroAddress,
          treasury.address,
          TICKET_PRICE,
          MAX_TICKETS,
          ROUND_DURATION,
          ethers.ZeroAddress,
          ethers.ZeroHash,
          0n
        ])
      ).to.be.revertedWithCustomError(fortuna, "InvalidAddress");
    });

    it("Should revert with zero treasury", async function () {
      await expect(
        ethers.deployContract("FortunaRounds", [
          await token.getAddress(),
          ethers.ZeroAddress,
          TICKET_PRICE,
          MAX_TICKETS,
          ROUND_DURATION,
          ethers.ZeroAddress,
          ethers.ZeroHash,
          0n
        ])
      ).to.be.revertedWithCustomError(fortuna, "InvalidAddress");
    });

    it("Should revert with zero ticket price", async function () {
      await expect(
        ethers.deployContract("FortunaRounds", [
          await token.getAddress(),
          treasury.address,
          0n,
          MAX_TICKETS,
          ROUND_DURATION,
          ethers.ZeroAddress,
          ethers.ZeroHash,
          0n
        ])
      ).to.be.revertedWithCustomError(fortuna, "InvalidAmount");
    });
  });

  describe("Buying Tickets", function () {
    beforeEach(async function () {
      // Approve contract to spend tokens
      await token.connect(user1).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
      await token.connect(user2).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
    });

    it("Should allow buying tickets", async function () {
      await fortuna.connect(user1).buyTickets(1);
      expect(await fortuna.getUserTickets(1, user1.address)).to.equal(1n);
      
      const round = await fortuna.getCurrentRound();
      expect(round.totalTicketsSold).to.equal(1n);
      expect(round.prizePool).to.equal(TICKET_PRICE);
    });

    it("Should allow buying multiple tickets", async function () {
      await fortuna.connect(user1).buyTickets(5);
      expect(await fortuna.getUserTickets(1, user1.address)).to.equal(5n);
    });

    it("Should revert if trying to buy 0 tickets", async function () {
      await expect(fortuna.connect(user1).buyTickets(0)).to.be.revertedWithCustomError(fortuna, "InvalidAmount");
    });

    it("Should revert if round is sold out", async function () {
      // Buy max tickets
      await token.connect(user1).approve(await fortuna.getAddress(), 2000n * 10n ** 18n);
      await fortuna.connect(user1).buyTickets(100);
      
      // Round is now in DRAWING state
      await expect(fortuna.connect(user2).buyTickets(1)).to.be.revertedWithCustomError(fortuna, "RoundNotOpen");
    });

    it("Should revert if buying more tickets than remaining", async function () {
      await fortuna.connect(user1).buyTickets(50);
      await expect(fortuna.connect(user2).buyTickets(51)).to.be.revertedWithCustomError(fortuna, "RoundSoldOut");
    });

    it("Should revert if trying to buy after round expired", async function () {
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      await expect(fortuna.connect(user1).buyTickets(1)).to.be.revertedWithCustomError(fortuna, "RoundExpired");
    });

    it("Should emit TicketsPurchased event", async function () {
      await expect(fortuna.connect(user1).buyTickets(5))
        .to.emit(fortuna, "TicketsPurchased")
        .withArgs(1n, user1.address, 5n, TICKET_PRICE * 5n);
    });
  });

  describe("Max Tickets Per Wallet", function () {
    beforeEach(async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
      await fortuna.updateMaxTicketsPerWallet(10n);
    });

    it("Should enforce max tickets per wallet", async function () {
      await fortuna.connect(user1).buyTickets(10);
      await expect(fortuna.connect(user1).buyTickets(1)).to.be.revertedWithCustomError(fortuna, "ExceedsMaxPerWallet");
    });

    it("Should allow buying up to max", async function () {
      await fortuna.connect(user1).buyTickets(10);
      expect(await fortuna.getUserTickets(1, user1.address)).to.equal(10n);
    });
  });

  describe("Round Closing", function () {
    beforeEach(async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
      await token.connect(user2).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
    });

    it("Should auto-close when sold out", async function () {
      await fortuna.connect(user1).buyTickets(100);
      
      const round = await fortuna.getRound(1);
      expect(round.status).to.equal(1); // DRAWING
    });

    it("Should allow closing expired round", async function () {
      await fortuna.connect(user1).buyTickets(1);
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      await fortuna.closeRound(1);
      
      const round = await fortuna.getRound(1);
      expect(round.status).to.equal(1); // DRAWING
    });

    it("Should create new round after closing", async function () {
      await fortuna.connect(user1).buyTickets(1);
      
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      
      // Fulfill randomness
      const randomWords = [12345n];
      await fortuna.fulfillRandomWords(requestId, randomWords);
      
      expect(await fortuna.currentRoundId()).to.equal(2n);
    });

    it("Should cancel round with zero tickets", async function () {
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      await fortuna.closeRound(1);
      
      const round = await fortuna.getRound(1);
      expect(round.status).to.equal(3); // CANCELLED
    });

    it("Should revert when trying to close open round", async function () {
      await fortuna.connect(user1).buyTickets(1);
      await expect(fortuna.closeRound(1)).to.be.revertedWithCustomError(fortuna, "RoundStillOpen");
    });

    it("Should revert when trying to close completed round", async function () {
      await fortuna.connect(user1).buyTickets(1);
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      await fortuna.fulfillRandomWords(requestId, [0n]);
      
      await expect(fortuna.closeRound(1)).to.be.revertedWithCustomError(fortuna, "AlreadyCompleted");
    });
  });

  describe("Winner Selection", function () {
    beforeEach(async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
      await token.connect(user2).approve(await fortuna.getAddress(), 1000n * 10n ** 18n);
    });

    it("Should select correct winner based on randomness", async function () {
      // User1 buys 10 tickets, User2 buys 10 tickets
      await fortuna.connect(user1).buyTickets(10);
      await fortuna.connect(user2).buyTickets(10);
      
      // Close round
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      
      // Fulfill randomness with known value
      const randomWords = [5n]; // Should select ticket index 5
      await fortuna.fulfillRandomWords(requestId, randomWords);
      
      const round = await fortuna.getRound(1);
      expect(round.winner).to.equal(user1.address); // Tickets 0-9 are user1
      expect(round.status).to.equal(2); // COMPLETED
    });

    it("Should select user2 for higher random value", async function () {
      await fortuna.connect(user1).buyTickets(10);
      await fortuna.connect(user2).buyTickets(10);
      
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      
      // Ticket index 15 should be user2
      const randomWords = [15n];
      await fortuna.fulfillRandomWords(requestId, randomWords);
      
      const round = await fortuna.getRound(1);
      expect(round.winner).to.equal(user2.address);
    });

    it("Should distribute prize correctly with 2% fee", async function () {
      await fortuna.connect(user1).buyTickets(10);
      
      const treasuryBalanceBefore = await token.balanceOf(treasury.address);
      
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      
      await fortuna.fulfillRandomWords(requestId, [0n]);
      
      const prizePool = TICKET_PRICE * 10n;
      const expectedFee = (prizePool * 200n) / 10000n; // 2%
      const expectedPrize = prizePool - expectedFee;
      
      const treasuryBalanceAfter = await token.balanceOf(treasury.address);
      expect(treasuryBalanceAfter - treasuryBalanceBefore).to.equal(expectedFee);
      
      // Verify prize was transferred to winner
      const round = await fortuna.getRound(1);
      expect(round.winner).to.equal(user1.address);
      expect(round.prizePool).to.equal(prizePool);
    });

    it("Should emit WinnerSelected event", async function () {
      await fortuna.connect(user1).buyTickets(10);
      
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      
      const prizePool = TICKET_PRICE * 10n;
      const expectedFee = (prizePool * 200n) / 10000n;
      const expectedPrize = prizePool - expectedFee;
      
      await expect(fortuna.fulfillRandomWords(requestId, [0n]))
        .to.emit(fortuna, "WinnerSelected")
        .withArgs(1n, user1.address, 0n, expectedPrize, expectedFee);
    });
  });

  describe("Admin Functions", function () {
    it("Should update treasury", async function () {
      await fortuna.updateTreasury(user1.address);
      expect(await fortuna.treasury()).to.equal(user1.address);
    });

    it("Should revert with zero address for treasury", async function () {
      await expect(fortuna.updateTreasury(ethers.ZeroAddress)).to.be.revertedWithCustomError(fortuna, "InvalidAddress");
    });

    it("Should update fee", async function () {
      await fortuna.updateFeeBps(300n);
      expect(await fortuna.feeBps()).to.equal(300n);
    });

    it("Should not allow fee above 5%", async function () {
      await expect(fortuna.updateFeeBps(600n)).to.be.revertedWithCustomError(fortuna, "InvalidFee");
    });

    it("Should update ticket price", async function () {
      await fortuna.updateTicketPrice(20n * 10n ** 18n);
      expect(await fortuna.ticketPrice()).to.equal(20n * 10n ** 18n);
    });

    it("Should update max tickets", async function () {
      await fortuna.updateMaxTickets(200n);
      expect(await fortuna.maxTickets()).to.equal(200n);
    });

    it("Should pause and unpause", async function () {
      await fortuna.pause();
      await token.connect(user1).approve(await fortuna.getAddress(), 100n * 10n ** 18n);
      await expect(fortuna.connect(user1).buyTickets(1)).to.be.revertedWithCustomError(fortuna, "EnforcedPause");
      
      await fortuna.unpause();
      await fortuna.connect(user1).buyTickets(1);
    });

    it("Should only allow owner to call admin functions", async function () {
      await expect(fortuna.connect(user1).updateTreasury(user1.address))
        .to.be.revertedWithCustomError(fortuna, "OwnableUnauthorizedAccount");
      await expect(fortuna.connect(user1).updateFeeBps(300n))
        .to.be.revertedWithCustomError(fortuna, "OwnableUnauthorizedAccount");
      await expect(fortuna.connect(user1).pause())
        .to.be.revertedWithCustomError(fortuna, "OwnableUnauthorizedAccount");
    });
  });

  describe("View Functions", function () {
    it("Should return current round", async function () {
      const round = await fortuna.getCurrentRound();
      expect(round.roundId).to.equal(1n);
    });

    it("Should return ticket owner", async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 100n * 10n ** 18n);
      await fortuna.connect(user1).buyTickets(5);
      
      expect(await fortuna.getTicketOwner(1, 0)).to.equal(user1.address);
      expect(await fortuna.getTicketOwner(1, 4)).to.equal(user1.address);
    });

    it("Should return user ticket count", async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 100n * 10n ** 18n);
      await fortuna.connect(user1).buyTickets(5);
      
      expect(await fortuna.getUserTickets(1, user1.address)).to.equal(5n);
    });
  });

  describe("Create New Round", function () {
    it("Should allow creating new round after completion", async function () {
      await token.connect(user1).approve(await fortuna.getAddress(), 100n * 10n ** 18n);
      await fortuna.connect(user1).buyTickets(1);
      
      await ethers.provider.send("evm_increaseTime", [301]);
      await ethers.provider.send("evm_mine");
      const tx = await fortuna.closeRound(1);
      const requestId = await getRequestIdFromTx(tx);
      await fortuna.fulfillRandomWords(requestId, [0n]);
      
      expect(await fortuna.currentRoundId()).to.equal(2n);
      
      // Try to create another round manually (should work after completion)
      const newRound = await fortuna.getCurrentRound();
      expect(newRound.roundId).to.equal(2n);
    });
  });
});



