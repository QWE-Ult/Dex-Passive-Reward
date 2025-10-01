// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DexPassiveReward is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    uint256 public rewardRatePerSecond; // scaled by 1e18
    uint256 public constant MAX_TRACKED = 20;

    struct Tracked { IERC20 token; uint256 weight; }
    Tracked[] public tracked;
    uint256 public totalWeight;

    mapping(address => uint256) public lastUpdate;
    mapping(address => uint256) public accrued;
    mapping(address => uint256) public lastBalanceSum;

    // constructor sets reward token and rate
    constructor(IERC20 _rewardToken, uint256 _rewardRatePerSecond) {
        rewardToken = _rewardToken;
        rewardRatePerSecond = _rewardRatePerSecond;
    }

    // owner: add a token to track
    function addToken(IERC20 token, uint256 weight) external onlyOwner {
        require(weight > 0, "weight>0");
        require(tracked.length < MAX_TRACKED, "max tracked");
        tracked.push(Tracked({token: token, weight: weight}));
        totalWeight += weight;
    }

    // owner: change weight
    function setTokenWeight(uint256 idx, uint256 newWeight) external onlyOwner {
        require(idx < tracked.length, "idx OOB");
        require(newWeight > 0, "weight>0");
        totalWeight = totalWeight - tracked[idx].weight + newWeight;
        tracked[idx].weight = newWeight;
    }

    // owner: set global rate (scaled by 1e18)
    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
    }

    // owner: fund contract with reward tokens
    function depositRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    // owner: emergency withdraw leftover
    function withdrawRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(msg.sender, amount);
    }

    // public: update internal accrued state for caller
    function updateRewards() external nonReentrant {
        _accrue(msg.sender);
    }

    // claim pending reward tokens
    function claim() external nonReentrant {
        _accrue(msg.sender);
        uint256 amt = accrued[msg.sender];
        require(amt > 0, "no rewards");
        accrued[msg.sender] = 0;
        rewardToken.safeTransfer(msg.sender, amt);
    }

    // view pending rewards without changing state
    function pendingRewards(address user) external view returns (uint256) {
        uint256 last = lastUpdate[user];
        if (last == 0) return 0;
        uint256 delta = block.timestamp - last;
        if (delta == 0) return accrued[user];
        uint256 projected = (lastBalanceSum[user] * rewardRatePerSecond * delta) / 1e18;
        return accrued[user] + projected;
    }

    // internal: update accrued and snapshot
    function _accrue(address user) internal {
        uint256 last = lastUpdate[user];
        uint256 nowTs = block.timestamp;
        if (last == 0) {
            lastUpdate[user] = nowTs;
            lastBalanceSum[user] = _currentBalanceSum(user);
            return;
        }
        uint256 delta = nowTs - last;
        if (delta == 0) {
            return;
        }
        uint256 reward = (lastBalanceSum[user] * rewardRatePerSecond * delta) / 1e18;
        if (reward > 0) {
            accrued[user] += reward;
        }
        lastUpdate[user] = nowTs;
        lastBalanceSum[user] = _currentBalanceSum(user);
    }

    // internal: sum of (balance * weight) for user
    function _currentBalanceSum(address user) internal view returns (uint256 sum) {
        for (uint256 i = 0; i < tracked.length; i++) {
            Tracked storage t = tracked[i];
            sum += t.token.balanceOf(user) * t.weight;
        }
    }
}
