
## Overview
`DexPassiveReward` is a Solidity contract that distributes a project/DEX reward token to users simply for **holding** one or more supported ERC-20 tokens in their wallet. There are no explicit stake/deposit calls — the contract samples on-chain wallet balances for a configured set of tokens and accrues rewards over time.
## Key features
- Passive reward distribution based on wallet holdings (no staking/deposit).  
- Multiple tracked tokens with configurable relative weights (heavier weight → more rewards).  
- `rewardRatePerSecond` (per-second rate, scaled by `1e18`) for precise reward math.  
- Safe ERC-20 handling via OpenZeppelin `SafeERC20`.  
- Reentrancy protection via `ReentrancyGuard`.  
- Owner controls: add tracked tokens, change weights, set reward rate, deposit/withdraw reward tokens.  
- Gas guard: limits number of tracked tokens with `MAX_TRACKED = 20` to avoid large loops.

---

## How it works (short)
1. Owner configures which ERC-20 tokens to track and assigns each a weight.  
2. For each user the contract keeps a snapshot (`lastBalanceSum`) and a `lastUpdate` timestamp.  
3. On interactions (`updateRewards`, `claim`, or internal accrual) the contract computes the time delta, multiplies by the stored weighted balance snapshot and the `rewardRatePerSecond`, scales by `1e18`, and increments `accrued` rewards.  
4. Users call `claim()` to transfer their accrued `rewardToken` from the contract to their address.

---

## Requirements / Technologies
- Solidity `^0.8.20`  
- OpenZeppelin Contracts: `IERC20`, `SafeERC20`, `Ownable`, `ReentrancyGuard`  
- Typical toolchains: Hardhat / Foundry / Remix for compile & deploy

---

## Deployment example (Hardhat / ethers.js)

// `scripts/deploy.js` (example)
```js
const { ethers } = require("hardhat");

async function main() {
  const rewardTokenAddr = "0x..."; // deployed reward token address

  // Example: if you want 0.1 rewardToken per (token*weight) per year:
  const secondsPerYear = 365 * 24 * 3600; // 31536000
  const annualAmount = ethers.utils.parseUnits("0.1", 18); // 0.1 tokens, 18 decimals
  // ratePerSecond should be scaled to 1e18 in contract math — adjust accordingly in your calculations
  const ratePerSecond = annualAmount.mul(ethers.BigNumber.from("1000000000000000000")).div(secondsPerYear);

  const DexPassiveReward = await ethers.getContractFactory("DexPassiveReward");
  const inst = await DexPassiveReward.deploy(rewardTokenAddr, ratePerSecond);
  await inst.deployed();
  console.log("Deployed to", inst.address);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
