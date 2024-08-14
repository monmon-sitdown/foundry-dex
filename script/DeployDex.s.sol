// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DEXPlatform} from "../src/dex.sol";

contract DeployDEXPlatform is Script {
    function run() external {
        // 部署合约
        vm.startBroadcast();

        // 部署 DEXPlatform 合约
        DEXPlatform dexPlatform = new DEXPlatform();

        // 输出部署后的合约地址
        console.log("DEXPlatform deployed to:", address(dexPlatform));

        vm.stopBroadcast();
    }
}

/**
 * ##### dev
 * ✅  [Success]Hash: 0x52b19968afa113d70942f1301a1b8e39a8b52cf5f69f91460c8f2ecebe2206ed
 * Contract Address: 0x9E75bb849E8C33C966658307794401F03c192C22
 * Block: 52
 * Paid: 0.00346870420148811 ETH (1155585 gas * 3.001686766 gwei)
 *
 * [Success]Hash: 0x2e59c83e1deaafa105815a7331a0413ae17604fc019683d9f1683dc82d1d0cb3
 * Contract Address: 0x090Bc3ff8116D285ad616aF3A9dF066B64b3126F
 * Block: 53
 * Paid: 0.004470224062260684 ETH (1489306 gas * 3.001548414 gwei)
 */
