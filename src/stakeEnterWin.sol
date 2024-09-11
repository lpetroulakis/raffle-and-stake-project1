// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract stakeEnterWin is Ownable {
    using SafeERC20 for IERC20;

    error stakeAmountZero();
    error insufficientStakeBalance();
    error noClaimableRewards();
    error noStakedBalance();
    error gameStillActive();
    error noActiveGame();
    error gameNotEnded();
    error insufficientPlayers();
    error invalidGameParticipation();

    struct Staker {
        uint256 amountStaked; // Amount of tokens staked
        uint256 rewards; // Rewards already paid out or available for claim
    }

    // Game information
    struct Game {
        uint256 startTime;
        bool isActive;
        address[] participants;
        address winner;
        uint256 gamePool;
    }

    // stablecoin used for staking and game participation (USDC, DAI etc)
    IERC20 public stablecoin;

    // Total staked amounts per token
    mapping(address => uint256) public totalStaked;

    // Mapping of staker's info against each token
    mapping(address => mapping(address => Staker)) public stakers;

    // Total rewards per token - increases when fees are distributed
    mapping(address => uint256) public rewardPerTokenStored;

    // Last update timestamp for rewardPerToken for each token
    mapping(address => uint256) public lastUpdateTime;

    // Tracker of total fees collected for each ERC20 token
    mapping(address => uint256) public feesCollected;

    // Game tracking
    mapping(uint256 => Game) public games;
    uint256 public gameCounter;

    uint256 public constant PARTICIPATION_FEE = 10 * 1e18; // 10 stablecoin (e.g., DAI)
    uint256 public constant FEE_PERCENTAGE = 10; // 10% fee for staking rewards

    event Staked(address indexed user, address indexed token, uint256 amount);
    event Unstaked(address indexed user, address indexed token, uint256 amount);
    event RewardPaid(address indexed user, address indexed token, uint256 reward);
    event FeesDistributed(address indexed token, uint256 amount);
    event GameStarted(uint256 gameId, uint256 startTime);
    event PlayerJoined(uint256 gameId, address indexed player);
    event WinnerDeclared(uint256 gameId, address indexed winner, uint256 reward);

    constructor(IERC20 _stablecoin) Ownable(msg.sender) {
        stablecoin = _stablecoin; // here we set the stablecoin address (e.g., DAI)
    }

    // External function for any user to stake the stablecoin
    function stake(uint256 _amount) external updateReward(address(stablecoin), msg.sender) {
        if (_amount == 0) {
            revert stakeAmountZero();
        }

        // Transfer stablecoin to the contract
        stablecoin.safeTransferFrom(msg.sender, address(this), _amount);

        // Update the staker's balance and total staked amount
        Staker storage staker = stakers[address(stablecoin)][msg.sender];
        staker.amountStaked += _amount;
        totalStaked[address(stablecoin)] += _amount;

        emit Staked(msg.sender, address(stablecoin), _amount);
    }

    // Function to unstake stablecoin
    function unstake(uint256 _amount) external updateReward(address(stablecoin), msg.sender) {
        Staker storage staker = stakers[address(stablecoin)][msg.sender];
        if (staker.amountStaked < _amount) {
            revert insufficientStakeBalance();
        }

        // Update staker's balance and total staked amount
        staker.amountStaked -= _amount;
        totalStaked[address(stablecoin)] -= _amount;

        // Transfer stablecoin back to the user
        stablecoin.safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, address(stablecoin), _amount);
    }

    // Function to claim rewards in stablecoin
    function claimRewards() external updateReward(address(stablecoin), msg.sender) {
        Staker storage staker = stakers[address(stablecoin)][msg.sender];
        uint256 reward = staker.rewards;
        if (reward == 0) {
            revert noClaimableRewards();
        }

        stablecoin.safeTransfer(msg.sender, reward);

        // Reset available reward
        staker.rewards = 0;

        emit RewardPaid(msg.sender, address(stablecoin), reward);
    }

    // Function to distribute participation fees proportionally to stakers
    function distributeFees(uint256 _feeAmount) public onlyOwner updateReward(address(stablecoin), address(0)) {
        if (totalStaked[address(stablecoin)] == 0) {
            revert noStakedBalance();
        }

        // Transfer the participation fee to the contract
        stablecoin.safeTransferFrom(msg.sender, address(this), _feeAmount);

        // Update the rewardPerTokenStored for the stablecoin
        rewardPerTokenStored[address(stablecoin)] += (_feeAmount * 1e18) / totalStaked[address(stablecoin)];
        lastUpdateTime[address(stablecoin)] = block.timestamp;

        emit FeesDistributed(address(stablecoin), _feeAmount);
    }

    // Start a new raffle game
    function startRaffle() external onlyOwner {
        if (games[gameCounter].isActive) {
            revert gameStillActive();
        }

        gameCounter++;
        games[gameCounter].startTime = block.timestamp;
        games[gameCounter].isActive = true;

        emit GameStarted(gameCounter, block.timestamp);
    }

    // Function for players to join the game (uses stablecoin only)
    function joinRaffle() external {
        Game storage game = games[gameCounter];

        if (!game.isActive) {
            revert noActiveGame();
        }
        if (block.timestamp > game.startTime + 5 minutes) {
            revert gameNotEnded();
        }

        // Transfer participation fee (in stablecoin)
        stablecoin.safeTransferFrom(msg.sender, address(this), PARTICIPATION_FEE);

        // 10% goes to staking rewards
        uint256 stakingFee = (PARTICIPATION_FEE * FEE_PERCENTAGE) / 100;
        distributeFees(stakingFee);

        // 90% goes to the game pool
        game.gamePool += PARTICIPATION_FEE - stakingFee;
        game.participants.push(msg.sender);

        emit PlayerJoined(gameCounter, msg.sender);
    }

    // Declare the winner of the game after 5 minutes
    function declareWinner() external onlyOwner {
        Game storage game = games[gameCounter];

        if (!game.isActive) {
            revert noActiveGame();
        }
        if (block.timestamp < game.startTime + 5 minutes) {
            revert gameNotEnded();
        }
        if (game.participants.length < 2) {
            revert insufficientPlayers();
        }

        // Select winner using block randomness
        uint256 randomIndex =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % game.participants.length;
        address winner = game.participants[randomIndex];

        // Transfer winnings to the winner (in stablecoin)
        stablecoin.safeTransfer(winner, game.gamePool);

        // Mark the game as finished
        game.winner = winner;
        game.isActive = false;

        emit WinnerDeclared(gameCounter, winner, game.gamePool);
    }

    // Modifier to update rewards for a specific token and staker
    modifier updateReward(address _token, address _account) {
        rewardPerTokenStored[_token] = rewardPerToken(_token);
        lastUpdateTime[_token] = block.timestamp;

        if (_account != address(0)) {
            Staker storage staker = stakers[_token][_account];
            staker.rewards = earned(_token, _account);
        }
        _;
    }

    // view function to see how much a user has earned so far
    function earned(address _token, address _account) public view returns (uint256) {
        Staker memory staker = stakers[_token][_account];
        return ((staker.amountStaked * (rewardPerToken(_token) - rewardPerTokenStored[_token])) / 1e18) + staker.rewards;
    }

    // view function to get the current reward per token for the stablecoin
    function rewardPerToken(address _token) public view returns (uint256) {
        if (totalStaked[_token] == 0) {
            return rewardPerTokenStored[_token];
        }

        return rewardPerTokenStored[_token];
    }
}
