// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Token0, Token1} from "../src/testToken.sol";

contract DeployTokens is Script {
    function run() external {
        // 部署合约
        vm.startBroadcast();

        Token0 token0 = new Token0();
        Token1 token1 = new Token1();

        // 输出部署后的合约地址
        console.log("token0 deployed to:", address(token0));
        console.log("token1 deployed to:", address(token1));

        vm.stopBroadcast();
    }
}

/**
 * token0 deployed to: 0xE9187dF444B561336c143B04E3a292502eCa2F33
 *   token1 deployed to: 0xf226aD181540a36408b110988dF3c68A94335AB3
 */
