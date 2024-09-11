// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/stakeEnterWin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract StakingAndGamingTest is Test {
    stakeEnterWin SEW;
    ERC20Mock stablecoin;
    address owner = msg.sender;
    address user1 = address(2);
    address user2 = address(3);

    // function setUp() public {
    //     stablecoin = new ERC20Mock();

    //     SEW = new stakeEnterWin(IERC20(stablecoin));
    //     vm.prank(owner);
    //     stablecoin.mint(user1, 1000 * 1e18); // Mint 1000 tokens to user1

    //     assertEq(stablecoin.balanceOf(user1), 1000 * 1e18);
    // }
    function setUp() public {
        // Prank as address(1), which will be the owner of the contract
        vm.prank(owner); // Prank as owner (address(1))

        // Deploy the ERC20Mock (stablecoin) for testing
        stablecoin = new ERC20Mock();

        // Deploy the staking and gaming contract with the stablecoin
        SEW = new stakeEnterWin(IERC20(stablecoin));

        // Stop pranking after deployment
        vm.stopPrank();

        // Mint some stablecoin tokens for user1 using the owner's context
        vm.prank(owner);
        stablecoin.mint(user1, 1000 * 1e18); // Mint 1000 tokens to user1

        // Ensure user1 has enough balance to stake
        assertEq(stablecoin.balanceOf(user1), 1000 * 1e18);
    }

    function testStake() public {
        // User1 stakes 100 tokens
        vm.startPrank(user1);
        stablecoin.approve(address(SEW), 100 * 1e18); // Approve SEW to spend tokens
        SEW.stake(100 * 1e18); // Stake 100 tokens

        // Check that staking is successful and the balances are correct
        assertEq(SEW.totalStaked(address(stablecoin)), 100 * 1e18);
        //assertEq(SEW.stakers(address(stablecoin), user1).amountStaked, 100 * 1e18);
        // Deconstructing the tuple
        (uint256 amountStaked,) = SEW.stakers(address(stablecoin), user1);

        // Check the amount staked
        assertEq(amountStaked, 100 * 1e18);

        vm.stopPrank();
    }

    function testUnstake() public {
        // First, stake tokens as in the previous test
        testStake();

        // User1 unstakes 50 tokens
        vm.startPrank(user1);
        SEW.unstake(50 * 1e18); // Unstake 50 tokens

        // Check that the unstake was successful
        assertEq(SEW.totalStaked(address(stablecoin)), 50 * 1e18);
        //assertEq(SEW.stakers(address(stablecoin), user1).amountStaked, 50 * 1e18);
        (uint256 amountStaked,) = SEW.stakers(address(stablecoin), user1);
        assertEq(amountStaked, 50 * 1e18);

        vm.stopPrank();
    }
}
