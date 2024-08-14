// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {DEXPlatform} from "../src/dex.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
    // mint 函数，用于测试

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract DEXPlatformTest is Test {
    DEXPlatform dexPlatform;
    TestERC20 tokenA;
    TestERC20 tokenB;
    address user = address(0x123);

    function setUp() public {
        //Deploy the contract
        dexPlatform = new DEXPlatform();

        //Deploy two ERC20 token
        tokenA = new TestERC20("TokenA", "A");
        tokenB = new TestERC20("TokenB", "B");

        //Give users some tokens
        tokenA.mint(user, 1000 * 1e18);
        tokenB.mint(user, 1000 * 1e18);

        vm.startPrank(user);
        tokenA.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 缺少这一步的话会出现testAddLiquidity 0！=500~0的错误
        tokenB.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 必须是给dexplatform而不是user?
        vm.stopPrank();

        /*
        console.log("User tokenA allowance:", tokenA.allowance(user, address(dexPlatform)));
        console.log("User tokenB allowance:", tokenB.allowance(user, address(dexPlatform)));
        console.log("User tokenA balance:", tokenA.balanceOf(user));
        console.log("User tokenB balance:", tokenB.balanceOf(user));*/
    }

    function testCreatePool() public {
        //Users create pool
        vm.prank(user);
        dexPlatform.createPool(address(tokenA), address(tokenB));

        //Validate pool created
        (IERC20 token0, IERC20 token1,,,) = dexPlatform.pools(address(tokenA), address(tokenB));
        assertEq(address(token0), address(tokenA));
        assertEq(address(token1), address(tokenB));
    } //Passed

    function testAddLiquidity() public {
        // 创建池子
        vm.startPrank(user);
        dexPlatform.createPool(address(tokenA), address(tokenB));
        vm.stopPrank();

        // 输出用户的代币余额
        /*uint256 balanceA = tokenA.balanceOf(user);
        uint256 balanceB = tokenB.balanceOf(user);
        console.log("User tokenA balance:", balanceA);
        console.log("User tokenB balance:", balanceB);*/

        // 输出授权额度
        /*
        uint256 allowanceA = tokenA.allowance(user, address(dexPlatform));
        uint256 allowanceB = tokenB.allowance(user, address(dexPlatform));
        console.log("User tokenA allowance:", allowanceA);
        console.log("User tokenB allowance:", allowanceB);*/

        // 执行添加流动性操作
        uint256 amount0 = 500 * 1e18;
        uint256 amount1 = 500 * 1e18;
        vm.startPrank(user);
        uint256 shares = dexPlatform.addLiquidity(address(tokenA), address(tokenB), amount0, amount1);
        vm.stopPrank();

        (IERC20 token0, IERC20 token1, uint256 reserve0, uint256 reserve1, uint256 totalShares) =
            dexPlatform.pools(address(tokenA), address(tokenB));
        /*console.log("Pool Reserve0:", reserve0);
        console.log("Pool Reserve1:", reserve1);*/
        assertEq(reserve0, amount0, "Unexpected amount of token0 in pool");
        assertEq(reserve1, amount1, "Unexpected amount of token1 in pool");
        assertEq(totalShares, shares);
        /*totalshares和shares在代码里就不一样啊，totalshares永远比shares大1000
        修改了源代码AddLiquidity之后修复了
        if (pool.totalShares == 0) {
            shares = Math.sqrt(amount0 * amount1);
            pool.totalShares = shares > MINIMUM_LIQUIDITY ? 0 : MINIMUM_LIQUIDITY; 
        } else {
            shares =
                Math.min((amount0 * pool.totalShares) / pool.reserve0, (amount1 * pool.totalShares) / pool.reserve1);
        }因为后面pool.totalShares += shares， 所以一开始的代码导致了永远重复增加1000，所以报错
        //assertEq(totalShares, shares);
        console.log("shares", shares); //shares 499999999999999999000
        console.log("totalshares:", totalShares); //totalshare500000000000000000000 修改允许误差范围之后1e3倒是好了

        uint256 tolerance = 1e3; // 允许的误差范围 因为差1000，所以误差小于1e3就报错了
        assertTrue(
            abs(totalShares - shares) <= tolerance,
            string.concat("Expected shares: ", uint2str(shares), ", Actual totalShares: ", uint2str(totalShares))
        );*/
    }

    function checkAllowance(address token, address spender, uint256 expectedAllowance) public view {
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        assertEq(allowance, expectedAllowance);
    }

    // 在测试中检查授权额度
    function testCheckAllowance() public {
        // 设置预期的授权额度
        uint256 expectedAllowance = 500 * 1e18;

        // 检查 tokenA 的授权额度
        checkAllowance(address(tokenA), address(dexPlatform), expectedAllowance);

        // 检查 tokenB 的授权额度
        checkAllowance(address(tokenB), address(dexPlatform), expectedAllowance);
    }

    function abs(uint256 a) internal pure returns (uint256) {
        return a;
    }

    function uint2str(uint256 _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + j % 10));
            j /= 10;
        }
        return string(bstr);
    }

    function testRemoveLiquidity() public {
        // 创建池并添加流动性
        vm.prank(user);
        dexPlatform.createPool(address(tokenA), address(tokenB));
        tokenA.approve(address(dexPlatform), 500 * 1e18);
        tokenB.approve(address(dexPlatform), 500 * 1e18);
        vm.prank(user);
        uint256 shares = dexPlatform.addLiquidity(address(tokenA), address(tokenB), 500 * 1e18, 500 * 1e18);

        console.log(shares);

        // 用户移除流动性
        vm.prank(user);
        (uint256 amount0, uint256 amount1) = dexPlatform.removeLiquidity(address(tokenA), address(tokenB), shares);

        // 验证流动性已移除
        assertEq(amount0, 500 * 1e18);
        assertEq(amount1, 500 * 1e18);
    }

    function testSwap() public {
        // 创建池并添加流动性
        vm.startPrank(user);
        dexPlatform.createPool(address(tokenA), address(tokenB));
        tokenA.approve(address(dexPlatform), 500 * 1e18);
        tokenB.approve(address(dexPlatform), 500 * 1e18);
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), 500 * 1e18, 500 * 1e18);
        vm.stopPrank();

        // 用户进行交换
        vm.startPrank(user);
        tokenA.approve(address(dexPlatform), 100 * 1e18);
        uint256 amountOut = dexPlatform.swap(address(tokenA), address(tokenB), 100 * 1e18);
        vm.stopPrank();

        // 验证交换结果
        assertTrue(amountOut > 0);
    }

    ////////////////////////
    // Test Add Liquidity //
    ////////////////////////
    function testAddLiquidityInitial() public {
        // 设定用户地址
        vm.startPrank(user);

        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加流动性
        uint256 amountA = 5000;
        uint256 amountB = 5000;
        uint256 shares = dexPlatform.addLiquidity(address(tokenA), address(tokenB), amountA, amountB);

        // 检查流动性池是否创建
        (IERC20 token0, IERC20 token1, uint256 reserve0, uint256 reserve1, uint256 totalShares) =
            dexPlatform.pools(address(tokenA), address(tokenB));
        assertEq(reserve0, amountA);
        assertEq(reserve1, amountB);
        assertEq(totalShares, shares);

        // 检查用户股份
        uint256 userShare = dexPlatform.userShares(user, address(tokenA), address(tokenB));
        assertEq(userShare, shares);

        vm.stopPrank();
    }

    function testAddLiquidityToExistingPool() public {
        address user2 = address(0x456);
        //Give users some tokens
        tokenA.mint(user2, 1000 * 1e18);
        tokenB.mint(user2, 1000 * 1e18);

        vm.startPrank(user2);
        tokenA.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 缺少这一步的话会出现testAddLiquidity 0！=500~0的错误
        tokenB.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 必须是给dexplatform而不是user?

        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);
        vm.stopPrank();

        vm.startPrank(user);
        // 当前池中的流动性
        (IERC20 token0, IERC20 token1, uint256 reserve0, uint256 reserve1, uint256 totalShares) =
            dexPlatform.pools(address(tokenA), address(tokenB));
        uint256 initialReserve0 = reserve0;
        uint256 initialReserve1 = reserve1;
        uint256 initialTotalShares = totalShares;

        // 用户添加更多流动性
        uint256 additionalAmountA = 2000;
        uint256 additionalAmountB = 2000;
        uint256 shares =
            dexPlatform.addLiquidity(address(tokenA), address(tokenB), additionalAmountA, additionalAmountB);

        // 检查流动性池状态
        (,, uint256 updatedReserve0, uint256 updatedReserve1, uint256 updatedTotalShares) =
            dexPlatform.pools(address(tokenA), address(tokenB));
        vm.stopPrank();

        // 计算预期股份
        uint256 expectedShares = Math.min(
            (additionalAmountA * initialTotalShares) / initialReserve0,
            (additionalAmountB * initialTotalShares) / initialReserve1
        );

        // 检查流动性池的储备量
        assertEq(updatedReserve0, initialReserve0 + additionalAmountA);
        assertEq(updatedReserve1, initialReserve1 + additionalAmountB);

        // 检查总股份
        assertEq(updatedTotalShares, initialTotalShares + shares);

        // 检查用户股份
        uint256 userShare = dexPlatform.userShares(user, address(tokenA), address(tokenB));
        assertEq(userShare, shares);

        // 检查股份计算是否正确
        assertEq(shares, expectedShares);
    }

    function testAddZeroLiquidity() public {
        address user2 = address(0x456);
        //Give users some tokens
        tokenA.mint(user2, 1000 * 1e18);
        tokenB.mint(user2, 1000 * 1e18);

        vm.startPrank(user2);
        tokenA.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 缺少这一步的话会出现testAddLiquidity 0！=500~0的错误
        tokenB.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 必须是给dexplatform而不是user?

        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 zeroAmountA = 0;
        uint256 zeroAmountB = 0;

        vm.expectRevert("Insufficient liquidity minted");
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), zeroAmountA, zeroAmountB);

        vm.stopPrank();
    }

    function testAddLiquidityToNenExistentPool() public {
        TestERC20 tokenC;
        tokenC = new TestERC20("Token C", "C"); // 用于测试不存在的池
        tokenC.mint(user, 10000); // 为用户添加不存在池的代币余额

        address user2 = address(0x456);
        //Give users some tokens
        tokenA.mint(user2, 1000 * 1e18);
        tokenB.mint(user2, 1000 * 1e18);

        vm.startPrank(user2);
        tokenA.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 缺少这一步的话会出现testAddLiquidity 0！=500~0的错误
        tokenB.approve(address(dexPlatform), 500 * 1e18); // 授权500代币 必须是给dexplatform而不是user?

        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);
        vm.stopPrank();

        vm.startPrank(user);
        // 尝试向不存在的池中添加流动性
        uint256 amountC = 5000;
        uint256 amountB = 5000;

        // 允许 DEX 合约从用户地址转移代币
        tokenC.approve(address(dexPlatform), amountC);
        tokenB.approve(address(dexPlatform), amountB);

        // 期望交易回退，提示 "Pool doesn't exist"
        vm.expectRevert("Pool doesn't exist");
        dexPlatform.addLiquidity(address(tokenC), address(tokenB), amountC, amountB);

        vm.stopPrank();
    }

    /////////////////////////////
    /// Test Remove Liquidity ///
    /////////////////////////////
    function testRemoveLiquidityValid() public {
        vm.startPrank(user); //必须是同一个用户添加的流动性在同一个账户删除，否则userShares为0会出现除0错误
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        uint256 initialBalance0 = tokenA.balanceOf(user);
        uint256 initialBalance1 = tokenB.balanceOf(user);
        (,,,, uint256 shares) = dexPlatform.pools(address(tokenA), address(tokenB));

        console.log("share amount:", shares);

        (uint256 amount0, uint256 amount1) = dexPlatform.removeLiquidity(address(tokenA), address(tokenB), shares / 2);

        assertEq(tokenA.balanceOf(user), initialBalance0 + amount0, "Invalid token0 balance after removing liquidity");
        assertEq(tokenB.balanceOf(user), initialBalance1 + amount1, "Invalid token1 balance after removing liquidity");
        assertEq(
            dexPlatform.userShares(user, address(tokenA), address(tokenB)),
            shares / 2,
            "Invalid user shares after removing liquidity"
        );
        vm.stopPrank();
    }

    function testRemoveLiquidityInvalidShares() public {
        vm.startPrank(user);
        dexPlatform.createPool(address(tokenA), address(tokenB));
        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        uint256 invalidShares = 0;
        vm.expectRevert("Invalid shares amount");
        dexPlatform.removeLiquidity(address(tokenA), address(tokenB), invalidShares);
        vm.stopPrank();
    }

    function testRemoveLiquidityPoolNotExist() public {
        vm.startPrank(user);
        address nonExistentToken = address(0x123);
        vm.expectRevert("Pool doesn't exist");
        dexPlatform.removeLiquidity(nonExistentToken, address(tokenB), 100 ether);
        vm.stopPrank();
    }

    function testRemoveLiquidityInsufficientLiquidity() public {
        vm.startPrank(user);
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        (,,,, uint256 shares) = dexPlatform.pools(address(tokenA), address(tokenB));

        // Attempt to remove more liquidity than the user holds
        vm.expectRevert("Insufficient liquidity burned");
        dexPlatform.removeLiquidity(address(tokenA), address(tokenB), shares * 2);
        vm.stopPrank();
    }

    /////////////////////////////
    ////          Test Swap  ////
    /////////////////////////////
    function testBasicSwap() public {
        vm.startPrank(user);
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 5000;
        uint256 initialAmountB = 5000;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        vm.stopPrank();

        address userA = address(0x456);
        address token0 = address(tokenA);
        address token1 = address(tokenB);
        uint256 amountIn = 1000; //Token A amount that userA want to exchange

        vm.startPrank(userA);
        tokenA.mint(userA, 1001);
        tokenA.approve(address(dexPlatform), 500 * 1e18);

        uint256 userABalanceBefore = tokenA.balanceOf(userA);
        console.log("userABalanceBeforeA:", userABalanceBefore);
        console.log("userABalanceBeforeB:", tokenB.balanceOf(userA));
        (,, uint256 reserve0, uint256 reserve1,) = dexPlatform.pools(token0, token1);

        dexPlatform.swap(token0, token1, amountIn);

        uint256 userABalanceAfter = tokenA.balanceOf(userA);
        (,, uint256 newReserve0, uint256 newReserve1,) = dexPlatform.pools(token0, token1);
        console.log("userABalanceAfterA:", userABalanceAfter);
        console.log("userABalanceAfterB:", tokenB.balanceOf(userA));
        // 检查用户的代币余额
        assertEq(userABalanceBefore - amountIn, userABalanceAfter);
    }

    function testLargeAmountSwap() public {
        vm.startPrank(user);
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 400 * 1e18;
        uint256 initialAmountB = 400 * 1e18;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        vm.stopPrank();

        address token0 = address(tokenA);
        address token1 = address(tokenB);
        uint256 amountIn = 350 * 1e18; // 用户想要交换的大额代币A数量

        (,, uint256 reserve0, uint256 reserve1,) = dexPlatform.pools(token0, token1);

        address userB = address(0x456);
        vm.startPrank(userB);
        tokenA.mint(userB, 400 * 1e18);
        tokenA.approve(address(dexPlatform), 500 * 1e18);

        dexPlatform.swap(token0, token1, amountIn);
        (,, uint256 newReserve0, uint256 newReserve1,) = dexPlatform.pools(token0, token1);

        vm.stopPrank();

        // 检查池子的储备变化是否正确
        assertEq(newReserve0, reserve0 + amountIn);
        assertTrue(newReserve1 < reserve1); // poolToken1的储备应该减少

        // 检查池子的储备是否在合理范围内
        assertTrue(newReserve0 > reserve0);
        assertTrue(newReserve1 < reserve1);
        console.log("newReserve0:", newReserve0);
        console.log("newReserve1:", newReserve1);
    }

    function testZeroOutputSwap() public {
        vm.startPrank(user);
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 400 * 1e18;
        uint256 initialAmountB = 400 * 1e18;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        vm.stopPrank();

        address userC = address(0x789);
        address token0 = address(tokenA);
        address token1 = address(tokenB);
        uint256 amountIn = 1; // 用户想要交换的极小的代币A数量

        (,, uint256 reserve0, uint256 reserve1,) = dexPlatform.pools(token0, token1);

        vm.startPrank(userC);
        tokenA.mint(userC, 11);
        tokenA.approve(address(dexPlatform), 500 * 1e18);
        dexPlatform.swap(token0, token1, amountIn);
        (,, uint256 newReserve0, uint256 newReserve1,) = dexPlatform.pools(token0, token1);

        // 检查池子的储备变化是否正确
        // 因为交换数量太小，池子的储备应该没有变化
        //assertEq(newReserve0, reserve0); 这个肯定不可能相等的
        assertEq(newReserve1, reserve1);
    }

    function testInvalidTokenSwap() public {
        // 使用一个不在池子中的代币进行交换
        address tokenInvalid = address(0x123456);
        address token0 = address(tokenA);

        vm.startPrank(user);
        //创建池子
        dexPlatform.createPool(address(tokenA), address(tokenB));

        // 用户向 DEX 平台添加初始流动性
        uint256 initialAmountA = 400;
        uint256 initialAmountB = 400;
        dexPlatform.addLiquidity(address(tokenA), address(tokenB), initialAmountA, initialAmountB);

        vm.expectRevert("Pool doesn't exist");
        dexPlatform.swap(token0, tokenInvalid, 10);
        vm.stopPrank();
    }
}
