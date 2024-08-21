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
 * [Success]Hash: 0x452187be67f1d17780977dad9be478eb293ce9d95c74dc6ffd21b19b19f68afc
 * Contract Address: 0x46D7cb0f4DD857127354bD5EcAb75C06E88Ca373
 * Block: 75
 * Paid: 0.004330555986495257 ETH (1443467 gas * 3.000107371 gwei)
 *
 *   [Success]Hash: 0x6c9dae486628075e1d510e6d1ffdbeb9fcd13c0089b597e2f466bb01d34ab948
 * Contract Address: 0x3D484E9E3f7c0ffcDE03315A5d6fc81C510b636F
 * Block: 87
 * Paid: 0.004321327491120295 ETH (1440431 gas * 3.000023945 gwei)
 */
