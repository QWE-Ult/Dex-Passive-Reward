
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

## Configuration & Owner Workflow

### Owner Functions

- `addToken(IERC20 token, uint256 weight)` — Add a tracked token.
- `setTokenWeight(uint256 idx, uint256 newWeight)` — Change a token's weight.
- `setRewardRate(uint256 newRate)` — Set the per-second scaled rate.
- `depositRewards(uint256 amount)` — Deposit reward tokens into the contract.
- `WithdrawRewardTokens(uint256 amount)` — Emergency withdrawal by owner.

### User Actions

- `updateRewards()` — Update (and persist) accrued rewards without claiming.
- `claim()` — Claim all pending rewards (transfers tokens out).
- `pendingRewards(address user)` — View pending rewards (read-only).

---

## Important Notes & Security

- The owner controls key parameters (tracked tokens, weights, reward rate) — using a multisig for the owner address is recommended to reduce centralization and operational risk.
- Token balance checks loop through `trackedTokens`; `MAX_TRACKED = 20` prevents unbounded loops but keep the tracked set small for gas efficiency.
- Uses OpenZeppelin `SafeERC20` and `ReentrancyGuard` to mitigate common token & reentrancy risks.
- Ensure the contract is funded with enough `rewardToken` before users attempt to claim.
- The contract snapshots `lastBalanceSum` on first interaction — users who never call `updateRewards`/`claim` won’t be initialized until they interact; this is expected behavior.

---

## Testing Suggestions

- Unit tests should cover: accrual over time, multiple tokens/weights, zero balances, deposit/withdraw flows, owner-only restrictions, and reentrancy/edge cases.
- Simulate time passage with your test runner (Hardhat `evm_increaseTime` / Foundry `warp`) and assert expected `pendingRewards` values.

---

## Example Usage Flow

1. Owner deploys contract with `rewardToken` and `rewardRatePerSecond`.
2. Owner calls `addToken(...)` for each ERC-20 to track and sets weights.
3. Owner `depositRewards(...)` to fund the contract.
4. Users call `updateRewards()` (optional) and `claim()` to withdraw accrued rewards.
5. Owner adjusts weights or reward rate as needed (consider notifying users off-chain).
"""


