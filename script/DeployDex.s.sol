// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {DEXPlatform} from "../src/dex.sol";

contract DeployDEXPlatform is Script {
    function run() external {
        vm.startBroadcast();

        // // Deploy the DEX platform contract
        DEXPlatform dexPlatform = new DEXPlatform();

        // print the address of dexplatform
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
 * ##### dev
 * ✅  [Success]Hash: 0x3a5e1fc15a2e236e2fc13b554a023d5e8d084f74fa08183cce72094593080c3c
 * Contract Address: 0x03585BF82765B2434f6ace3A270A2ef60ed114D5
 * Block: 154
 * Paid: 0.005910972017732916 ETH (1970324 gas * 3.000000009 gwei)
 * ##### dev
 * ✅  [Success]Hash: 0x1e621b1b13e6294b53f8aace26701538bd5f2f720c49faeb604ab96cdeedda74
 * Contract Address: 0x14024406B95E8f821B1020Bb7fab45a18f863Edf
 * Block: 167
 * Paid: 0.005837073015565528 ETH (1945691 gas * 3.000000008 gwei)
 */
