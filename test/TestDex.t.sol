// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DEXPlatform} from "../src/Dex.sol";
import {TestTokenERC20} from "../src/TestTokenERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract DEXPlatformTest is Test {
    DEXPlatform dexPlatform;
    TestTokenERC20 tokenA;
    TestTokenERC20 tokenB;
    TestTokenERC20 tokenC;
    address user1 = address(0x123);
    address user2 = address(0x456);

    function setUp() public {
        //Deploy the contract
        dexPlatform = new DEXPlatform();

        //Deploy two ERC20 token
        tokenA = new TestTokenERC20("TokenA", "A");
        tokenB = new TestTokenERC20("TokenB", "B");
        tokenC = new TestTokenERC20("TokenC", "C");

        //Give users some tokens
        tokenA.mint(user1, 1000 * 1e18);
        tokenB.mint(user1, 1000 * 1e18);
        tokenC.mint(user1, 1000 * 1e18);

        tokenA.mint(user2, 500 * 1e18);
        tokenB.mint(user2, 500 * 1e18);
        tokenC.mint(user2, 500 * 1e18);

        vm.startPrank(user1);
        tokenA.approve(address(dexPlatform), 400 * 1e18);
        tokenB.approve(address(dexPlatform), 400 * 1e18);
        tokenC.approve(address(dexPlatform), 400 * 1e18);
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(dexPlatform), 400 * 1e18);
        tokenB.approve(address(dexPlatform), 400 * 1e18);
        tokenC.approve(address(dexPlatform), 400 * 1e18);
        vm.stopPrank();
    }

    //////////////////////
    // Create Pool Test //
    //////////////////////
    function testIfCanCreatePool() public {
        dexPlatform.createPool(address(tokenA), address(tokenB));
        (IERC20 token0, IERC20 token1,,,) = dexPlatform.pools(address(tokenA), address(tokenB));

        assertEq(address(token0), address(tokenA));
        assertEq(address(token1), address(tokenB));
    }

    function testIfCreateNonExistToken() public {
        TestTokenERC20 tokenD;

        vm.expectRevert();
        dexPlatform.createPool(address(tokenD), address(tokenB));
    }

    function testIfCreateAExistedPool() public {
        dexPlatform.createPool(address(tokenA), address(tokenB));
        (,, uint256 reserveA, uint256 reserveB, uint256 abShares) = dexPlatform.pools(address(tokenA), address(tokenB));
        console.log("A-B pool : ", reserveA, reserveB, abShares);

        vm.expectRevert();
        dexPlatform.createPool(address(tokenA), address(tokenB));
    }

    function testCreateMorePool() public {
        dexPlatform.createPool(address(tokenA), address(tokenB));
        (IERC20 token0, IERC20 token1,,,) = dexPlatform.pools(address(tokenA), address(tokenB));
        assertEq(address(token0), address(tokenA));
        assertEq(address(token1), address(tokenB));
        (uint256 reserveA, uint256 reserveB, uint256 abShares) =
            dexPlatform.getPoolInfo(address(tokenA), address(tokenB));
        console.log("A-B pool : ", reserveA, reserveB, abShares);

        dexPlatform.createPool(address(tokenA), address(tokenC));
        (IERC20 token2, IERC20 token3,,,) = dexPlatform.pools(address(tokenA), address(tokenC));
        assertEq(address(token2), address(tokenA));
        assertEq(address(token3), address(tokenC));
        (uint256 reserveA1, uint256 reserveC, uint256 acShares) =
            dexPlatform.getPoolInfo(address(tokenA), address(tokenC));
        console.log("A-C pool : ", reserveA1, reserveC, acShares);
    }

    function testIfPoolABEqualToPoolBA() public {
        dexPlatform.createPool(address(tokenA), address(tokenB));
        vm.expectRevert();
        dexPlatform.createPool(address(tokenB), address(tokenA));
    }
}
