import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("FortunaRounds", (m) => {
  // Get parameters from environment or use defaults
  const paymentToken = m.getParameter("paymentToken");
  const treasury = m.getParameter("treasury");
  const ticketPrice = m.getParameter("ticketPrice", 10000000000000000000n); // 10 tokens (18 decimals)
  const maxTickets = m.getParameter("maxTickets", 100n);
  const roundDuration = m.getParameter("roundDuration", 300n); // 5 minutes
  const vrfCoordinator = m.getParameter("vrfCoordinator");
  const keyHash = m.getParameter("keyHash");
  const subscriptionId = m.getParameter("subscriptionId", 0n);

  const fortuna = m.contract("FortunaRounds", [
    paymentToken,
    treasury,
    ticketPrice,
    maxTickets,
    roundDuration,
    vrfCoordinator,
    keyHash,
    subscriptionId
  ]);

  return { fortuna };
});
