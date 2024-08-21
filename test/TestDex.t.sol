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

        //For test addliquidity
        dexPlatform.createPool(address(tokenA), address(tokenB));
        dexPlatform.createPool(address(tokenA), address(tokenC));
        dexPlatform.createPool(address(tokenB), address(tokenC));

        //For testing swap
        vm.startPrank(user1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), 100, 200);
        dexPlatform.addLiquidity(address(tokenB), address(tokenC), 30, 40);
        dexPlatform.addLiquidity(address(tokenC), address(tokenA), 5000, 6000);
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

    /////////////////////////
    /// Get PoolInfo Test ///
    /////////////////////////
    function testGetPoolInfoBasic() public {
        uint256 amountA = 100;
        uint256 amountB = 1000;
        vm.startPrank(user1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amountA, amountB);
        vm.stopPrank();

        (uint256 newAmountA, uint256 newAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        assertEq(amountA, newAmountA);
        assertEq(amountB, newAmountB);
    }

    function testGetPoolInfoReverse() public {
        uint256 amountA = 100;
        uint256 amountB = 1000;
        vm.startPrank(user1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amountA, amountB);
        vm.stopPrank();

        (uint256 newAmountB, uint256 newAmountA,) = dexPlatform.getPoolInfo(address(tokenB), address(tokenA));

        assertEq(amountA, newAmountA);
        assertEq(amountB, newAmountB);
    }

    /////////////////////////
    /// Add Liqudity Test ///
    /////////////////////////
    function testAddLiquidityZero() public {
        uint256 amountA = 10;
        uint256 amountB = 0;
        vm.prank(user1);
        vm.expectRevert();
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amountA, amountB);
    }

    function testAddLiquidityByDiffUsers() public {
        uint256 amtA_Usr1 = 100;
        uint256 amtB_Usr1 = 200;
        vm.startPrank(user1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amtA_Usr1, amtB_Usr1);
        vm.stopPrank();

        uint256 amtA_Usr2 = 3000;
        uint256 amtB_Usr2 = 4000;
        vm.startPrank(user2);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amtA_Usr2, amtB_Usr2);
        vm.stopPrank();

        (uint256 newAmountA, uint256 newAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        assertEq(amtA_Usr1 + amtA_Usr2, newAmountA);
        assertEq(amtB_Usr1 + amtB_Usr2, newAmountB);
    }

    function testAddLiquidityToDiffPool() public {
        uint256 amtA_Usr1 = 100;
        uint256 amtB_Usr1 = 200;
        uint256 amtA2_Usr1 = 300;
        uint256 amtC_Usr1 = 400;
        uint256 amtB2_Usr1 = 500;
        uint256 amtC2_Usr1 = 600;

        vm.startPrank(user1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), amtA_Usr1, amtB_Usr1);
        dexPlatform.addLiquidity(address(tokenA), address(tokenC), amtA2_Usr1, amtC_Usr1);
        dexPlatform.addLiquidity(address(tokenB), address(tokenC), amtB2_Usr1, amtC2_Usr1);
        vm.stopPrank();

        (uint256 newAmountA, uint256 newAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));
        (uint256 newAmountA2, uint256 newAmountC,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenC));
        (uint256 newAmountB2, uint256 newAmountC2,) = dexPlatform.getPoolInfo(address(tokenB), address(tokenC));

        assertEq(amtA_Usr1, newAmountA);
        assertEq(amtB_Usr1, newAmountB);
        assertEq(amtA2_Usr1, newAmountA2);
        assertEq(amtC_Usr1, newAmountC);
        assertEq(amtB2_Usr1, newAmountB2);
        assertEq(amtC2_Usr1, newAmountC2);
    }

    //////////////////////////
    //// Swap Test        ////
    //////////////////////////
    function testSwapBasic() public {
        (uint256 initAmountA, uint256 initAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        vm.prank(user1);
        dexPlatform.swap(address(tokenA), address(tokenB), 10);
        (uint256 newAmountA, uint256 newAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        console.log("initial liquidity A", initAmountA);
        console.log("initial liquidity B", initAmountB);
        console.log("new liquidity A", newAmountA);
        console.log("new liquidity B", newAmountB);
    }

    function testSwapReverse() public {
        (uint256 initAmountA, uint256 initAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        vm.prank(user1);
        dexPlatform.swap(address(tokenB), address(tokenA), 10);
        (uint256 newAmountA, uint256 newAmountB,) = dexPlatform.getPoolInfo(address(tokenA), address(tokenB));

        console.log("initial liquidity A", initAmountA);
        console.log("initial liquidity B", initAmountB);
        console.log("new liquidity A", newAmountA);
        console.log("new liquidity B", newAmountB);
    }
}
