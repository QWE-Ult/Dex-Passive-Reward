// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



/// @notice Distributes rewards in `rewardToken` to users simply for holding
/// a set of supported tokens in their wallet.  No staking/deposit calls.
contract DexPassiveReward is Ownable(msg.sender), ReentrancyGuard  {
     using SafeERC20 for IERC20;

    /// Your DEX’s reward token
    IERC20 public immutable rewardToken;

    /// Annual interest rate, in rewardToken units per (tokenBalance × weight), scaled by 1e18.
    uint256 public rewardRatePerSecond;


    struct Tracked {
        IERC20 token;
        uint256 weight;   // relative weight for this token
    }
    Tracked[] public trackedTokens;
    uint256 public totalWeight;

    mapping(address => uint256) public lastUpdate;  // last timestamp we updated this user
    mapping(address => uint256) public accrued;     // pending rewardToken balance
    mapping(address => uint256) public lastBalanceSum; // Previous weighted balance
 
         uint256 public constant MAX_TRACKED = 20;//Max number of tokens you can track (to prevent large loops from costing too much gas).





    event TokenAdded(address indexed token, uint256 weight);
    event TokenWeightUpdated(uint256 indexed idx, uint256 newWeight);
    event RewardRateUpdated(uint256 newRate);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardsUpdated(address indexed user, uint256 totalAccrued);
    event RewardsAccrued(address indexed user, uint256 amount, uint256 timestamp);
    event FundsDeposited(address indexed owner, uint256 amount);
    event Withdrawal(address indexed owner, uint256 amount);


    constructor(IERC20 _rewardToken, uint256 _rewardRatePerSecond) {
        rewardToken = _rewardToken;

        rewardRatePerSecond = _rewardRatePerSecond;

    }

    /// @notice Add a token that users can passively earn on.
    /// @param token  ERC20 to track
    /// @param weight Relative weight (higher → more rewards)
    function addToken(IERC20 token, uint256 weight) external onlyOwner {
        require(weight > 0, "weight>0");
        require(trackedTokens.length < MAX_TRACKED, "too many tokens");
        trackedTokens.push(Tracked({token: token, weight: weight}));
        totalWeight += weight;
        emit TokenAdded(address(token), weight);
    }

    /// @notice Change the weight of a tracked token.
    function setTokenWeight(uint256 idx, uint256 newWeight) external onlyOwner {
        require(idx < trackedTokens.length, "idx OOB");
            require(newWeight > 0, "weight must >0"); 

        totalWeight = totalWeight - trackedTokens[idx].weight + newWeight;
        trackedTokens[idx].weight = newWeight;
        emit TokenWeightUpdated(idx, newWeight);
    }

    /// @notice Adjust the global reward rate (per second).
    function setRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
        emit RewardRateUpdated(newRate);
    }

    /// @notice Owner can deposit reward tokens into contract
    function depositRewards(uint256 amount) external onlyOwner {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
        emit FundsDeposited(msg.sender, amount);
    }

    /// @notice Owner can withdraw leftover reward tokens in an emergency
    function WithdrawRewardTokens(uint256 amount) external onlyOwner {
        rewardToken.safeTransfer(msg.sender, amount);
        emit Withdrawal(msg.sender, amount);
    }

    /// @dev Internal: accrue rewards up to now for `user`.
function _accrue(address user) internal {
    uint256 last = lastUpdate[user];
    if (last == 0) { // First interaction init
        lastUpdate[user] = block.timestamp;
        lastBalanceSum[user] = _currentBalanceSum(user);
        return;
    }
    
    uint256 delta = block.timestamp - last;
    if (delta < 1 seconds) {// 1 hour
            uint256 curr = _currentBalanceSum(user);
            if (curr == 0) {
         uint256 accruedAmount = (lastBalanceSum[user] * rewardRatePerSecond * delta) / 1e18;
           accrued[user] += accruedAmount;

                lastBalanceSum[user] = 0;
                lastUpdate[user] = block.timestamp;
                           emit RewardsAccrued(user, accruedAmount, block.timestamp);

            } 
            return;
        }

        //  REWARD accrual with previous snapshot
        uint256 reward = (lastBalanceSum[user] * rewardRatePerSecond * delta) / 1e18;
        accrued[user] += reward;
        emit RewardsAccrued(user, reward, block.timestamp); //  NEW

        // Update tracking
        lastUpdate[user] = block.timestamp;
        lastBalanceSum[user] = _currentBalanceSum(user); // Track new balance
    }
function _currentBalanceSum(address user) internal view returns (uint256) {
    uint256 sum;
    for (uint i = 0; i < trackedTokens.length; i++) {
        Tracked storage t = trackedTokens[i];
        sum += t.token.balanceOf(user) * t.weight;
    }
    return sum;
}
    /// @notice Public: update your accrued rewards (no token transfer).
    function updateRewards() external nonReentrant  {
        _accrue(msg.sender);
     emit RewardsUpdated(msg.sender, accrued[msg.sender]);

    }

    /// @notice Claim all your pending rewardToken.
    function claim() external nonReentrant  {
        _accrue(msg.sender);
        uint256 amount = accrued[msg.sender];
        require(amount > 0, "no rewards");
        accrued[msg.sender] = 0;
 rewardToken.safeTransfer(msg.sender, amount);
        emit RewardClaimed(msg.sender, amount);
    }

    /// @notice View pending rewards for a user (does not modify state).
    function pendingRewards(address user) external view returns (uint256) {
    uint256 last = lastUpdate[user];
    if (last == 0) return 0;
    
    uint256 delta = block.timestamp - last;
    if (delta < 1 seconds) // 1 hour
     return accrued[user];
    
    return accrued[user] + ((lastBalanceSum[user] * rewardRatePerSecond * delta) / 1e18);
}
}


