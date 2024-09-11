// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/stakeEnterWin.sol"; // Make sure the path to your contract is correct

contract DeployStakeEnterWin is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);
        address stablecoinAddress = vm.envAddress("STABLECOIN_ADDRESS");

        // we have to explicitly cast the stablecoin address to the IERC20 type
        IERC20 stablecoin = IERC20(stablecoinAddress);

        stakeEnterWin SEW = new stakeEnterWin(stablecoin);

        console.log("Deployed to:", address(SEW));

        vm.stopBroadcast();
    }
}
