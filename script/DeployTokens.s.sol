// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TestTokenERC20} from "../src/TestTokenERC20.sol";

contract DeployTokens is Script {
    function run() external {
        // 部署合约
        vm.startBroadcast();

        TestTokenERC20 token2 = new TestTokenERC20("Token2", "TK2");

        // 输出部署后的合约地址
        console.log("token2 deployed to:", address(token2));

        vm.stopBroadcast();
    }
}

/**
 * token0 deployed to: 0xE9187dF444B561336c143B04E3a292502eCa2F33
 *   token1 deployed to: 0xf226aD181540a36408b110988dF3c68A94335AB3
 *  token2 deployed to: 0x87a0ee49199346B2fcdF54FbCc9C1150d95a22fF
 */
