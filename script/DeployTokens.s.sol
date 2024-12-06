// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {TestTokenERC20} from "../src/TestTokenERC20.sol";

contract DeployTokens is Script {
    function run() external {
        vm.startBroadcast();

        TestTokenERC20 tokenA = new TestTokenERC20("TokenA", "TKA");
        TestTokenERC20 tokenB = new TestTokenERC20("TokenB", "TKB");
        TestTokenERC20 tokenC = new TestTokenERC20("TokenC", "TKC");

        // print address
        console.log("tokenA deployed to:", address(tokenA));
        console.log("tokenB deployed to:", address(tokenB));
        console.log("tokenC deployed to:", address(tokenC));

        vm.stopBroadcast();
    }
}

/**
 * tokenA deployed to: 0xD66e16d5ee57FB55f36b5F4FeB6da1922AF6DDA7
 *   tokenB deployed to: 0x590150D5BB3059E2f18Ec5CE136a839d97E9C1c5
 *   tokenC deployed to: 0xA75199d79CD32dd8B2942F36C01dB7a8Bde2351d
 */
