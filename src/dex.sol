// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {console} from "forge-std/Script.sol";

/**
 * @title DEXPlatform
 * @dev This contract implements a decentralized exchange (DEX) platform that allows for the creation of liquidity pools,
 *      addition and removal of liquidity, and token swapping between two ERC20 tokens.
 * @notice This contract uses the ReentrancyGuard to prevent reentrant calls.
 */
contract DEXPlatform is ReentrancyGuard {
    /**
     * @dev Represents a liquidity pool in the DEX.
     * @param token0 The first token in the pool.
     * @param token1 The second token in the pool.
     * @param reserve0 The current reserve of token0 in the pool.
     * @param reserve1 The current reserve of token1 in the pool.
     * @param totalShares The total number of shares in the pool.
     */
    struct Pool {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 totalShares;
    }

    uint256 public nextPoolId;
    mapping(uint256 => Pool) public poolsbyID; // 使用数字ID作为池子的索引
    // Mapping from token pairs to their corresponding liquidity pools 存储每对代币的流动性池
    mapping(address => mapping(address => Pool)) public pools;

    // Mapping from users to their shares in each token pair pool 存储每个用户在每对代币池中的股份
    mapping(address => mapping(address => mapping(address => uint256))) public userShares;

    uint256 public constant MINIMUM_LIQUIDITY = 1000; // Minimum liquidity to prevent extremely low liquidity
    uint256 private constant FEE_DENOMINATOR = 1000; // Denominator for fee calculations 费用分母
    uint256 public feeRate = 3; // 0.3% fee

    /**
     * @dev Emitted when a new pool is created.
     * @param token0 The address of the first token in the pool.
     * @param token1 The address of the second token in the pool.
     */
    event PoolCreated(address indexed token0, address indexed token1);

    /**
     * @dev Emitted when liquidity is added to a pool.
     * @param provider The address of the liquidity provider.
     * @param token0 The address of the first token in the pool.
     * @param token1 The address of the second token in the pool.
     * @param amount0 The amount of token0 added to the pool.
     * @param amount1 The amount of token1 added to the pool.
     * @param shares The number of shares minted for the liquidity provider.
     */
    event LiquidityAdded(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    /**
     * @dev Emitted when liquidity is removed from a pool.
     * @param provider The address of the liquidity provider.
     * @param token0 The address of the first token in the pool.
     * @param token1 The address of the second token in the pool.
     * @param amount0 The amount of token0 removed from the pool.
     * @param amount1 The amount of token1 removed from the pool.
     * @param shares The number of shares burned.
     */
    event LiquidityRemoved(
        address indexed provider,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 shares
    );

    /**
     * @dev Emitted when a token swap is executed.
     * @param user The address of the user who performed the swap.
     * @param tokenIn The address of the token being swapped in.
     * @param tokenOut The address of the token being swapped out.
     * @param amountIn The amount of tokenIn provided for the swap.
     * @param amountOut The amount of tokenOut received from the swap.
     */
    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    /**
     * @dev Creates a new liquidity pool for the given token pair.
     * @param _token0 The address of the first token.
     * @param _token1 The address of the second token.
     * @notice The pool cannot be created if either token address is zero or the pool already exists.
     */
    function createPool(address _token0, address _token1) external {
        require(_token0 != _token1, "Identical addresses");
        require(_token0 != address(0) && _token1 != address(0), "Zero address");
        require(address(pools[_token0][_token1].token0) == address(0), "Pool exists");

        (address token0, address token1) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        pools[token0][token1] = Pool(IERC20(token0), IERC20(token1), 0, 0, 0);
        poolsbyID[nextPoolId] = pools[token0][token1];
        nextPoolId++;
        emit PoolCreated(token0, token1);
    }

    /**
     * @dev Adds liquidity to an existing pool.
     * @param _token0 The address of the first token in the pool.
     * @param _token1 The address of the second token in the pool.
     * @param _amount0 The amount of token0 to add.
     * @param _amount1 The amount of token1 to add.
     * @return shares The number of shares minted for the provided liquidity.
     * @notice The function calculates the amount of shares to mint based on the amount of liquidity added.
     */
    function addLiquidity(address _token0, address _token1, uint256 _amount0, uint256 _amount1)
        external
        nonReentrant
        returns (uint256 shares)
    {
        Pool storage pool = pools[_token0][_token1];
        require(address(pool.token0) != address(0), "Pool doesn't exist");

        uint256 balance0 = pool.token0.balanceOf(address(this));
        uint256 balance1 = pool.token1.balanceOf(address(this));

        uint256 amount0 = _amount0;
        uint256 amount1 = _amount1;

        if (pool.totalShares == 0) {
            shares = Math.sqrt(amount0 * amount1);
            pool.totalShares = shares > MINIMUM_LIQUIDITY ? 0 : MINIMUM_LIQUIDITY;
        } else {
            shares =
                Math.min((amount0 * pool.totalShares) / pool.reserve0, (amount1 * pool.totalShares) / pool.reserve1);
        }

        require(shares > 0, "Insufficient liquidity minted");

        pool.token0.transferFrom(msg.sender, address(this), amount0);
        pool.token1.transferFrom(msg.sender, address(this), amount1);

        pool.reserve0 = balance0 + amount0;
        pool.reserve1 = balance1 + amount1;
        pool.totalShares += shares;
        userShares[msg.sender][_token0][_token1] += shares;

        emit LiquidityAdded(msg.sender, _token0, _token1, amount0, amount1, shares);
    }

    /**
     * @dev Removes liquidity from an existing pool.
     * @param _token0 The address of the first token in the pool.
     * @param _token1 The address of the second token in the pool.
     * @param _shares The number of shares to burn.
     * @return amount0 The amount of token0 withdrawn.
     * @return amount1 The amount of token1 withdrawn.
     * @notice The function calculates the amount of each token to withdraw based on the number of shares burned.
     */
    function removeLiquidity(address _token0, address _token1, uint256 _shares)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        Pool storage pool = pools[_token0][_token1];
        require(address(pool.token0) != address(0), "Pool doesn't exist");
        require(_shares > 0, "Invalid shares amount");
        require(pool.totalShares > 0, "No liquidity");

        uint256 balance0 = pool.token0.balanceOf(address(this));
        uint256 balance1 = pool.token1.balanceOf(address(this));

        amount0 = (_shares * balance0) / pool.totalShares;
        amount1 = (_shares * balance1) / pool.totalShares;

        /*console.log("Balance0:", balance0);
        console.log("Balance1:", balance1);
        console.log("Amount0 to remove:", amount0);
        console.log("Amount1 to remove:", amount1);
        console.log("Pool Total Shares:", pool.totalShares);
        console.log("User Shares:", userShares[msg.sender][_token0][_token1]);*/

        require(amount0 <= balance0 && amount1 <= balance1, "Insufficient liquidity burned");

        /*require(amount0 <= balance0, "Overflow: amount0 > balance0");
        require(amount1 <= balance1, "Overflow: amount1 > balance1");*/
        require(userShares[msg.sender][_token0][_token1] >= _shares, "Not enough shares");

        userShares[msg.sender][_token0][_token1] -= _shares;
        pool.totalShares -= _shares;

        pool.token0.transfer(msg.sender, amount0);
        pool.token1.transfer(msg.sender, amount1);

        pool.reserve0 = balance0 - amount0;
        pool.reserve1 = balance1 - amount1;

        emit LiquidityRemoved(msg.sender, _token0, _token1, amount0, amount1, _shares);
    }

    /**
     * @dev Swaps one token for another.
     * @param _tokenIn The address of the token being swapped in.
     * @param _tokenOut The address of the token being swapped out.
     * @param _amountIn The amount of tokenIn to swap.
     * @return amountOut The amount of tokenOut received.
     * @notice The function performs a swap between two tokens and charges a fee.
     */
    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(_tokenIn != _tokenOut, "Invalid tokens");
        Pool storage pool = pools[_tokenIn][_tokenOut];
        require(address(pool.token0) != address(0), "Pool doesn't exist");

        bool isToken0 = _tokenIn == address(pool.token0);
        (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = isToken0
            ? (pool.token0, pool.token1, pool.reserve0, pool.reserve1)
            : (pool.token1, pool.token0, pool.reserve1, pool.reserve0);

        console.log("reserveIn:", reserveIn);
        console.log("reserveOut:", reserveOut);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        uint256 amountInWithFee = (_amountIn * (FEE_DENOMINATOR - feeRate)) / FEE_DENOMINATOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        //aOut = reOurt - (reIn * reOut) / (reIn + aIn) 简化之后得到上面的式子 原理是恒定乘积市场（Constant Product Market，CPM）的原理，即 reserveIn * reserveOut 的乘积始终保持不变。

        tokenOut.transfer(msg.sender, amountOut);

        _updateReserves(pool, tokenIn.balanceOf(address(this)), tokenOut.balanceOf(address(this)));

        emit Swap(msg.sender, _tokenIn, _tokenOut, _amountIn, amountOut);
    }

    /**
     * @dev Updates the reserves of a pool.
     * @param _pool The pool to update.
     * @param _balance0 The new balance of token0.
     * @param _balance1 The new balance of token1.
     * @notice This function is called after a swap to update the reserves in the pool.
     */
    function _updateReserves(Pool storage _pool, uint256 _balance0, uint256 _balance1) private {
        _pool.reserve0 = _balance0;
        _pool.reserve1 = _balance1;
    }

    function getAllPoolPairs() public view returns (address[][] memory) {
        address[][] memory allPairs = new address[][](nextPoolId);
        for (uint256 i = 0; i < nextPoolId; i++) {
            allPairs[i] = new address[](2);
            allPairs[i][0] = address(poolsbyID[i].token0);
            allPairs[i][1] = address(poolsbyID[i].token1);
        }
        return allPairs;
    }

    function getPoolInfo(address _token0, address _token1) public view returns (uint256, uint256, uint256) {
        Pool storage pool = pools[_token0][_token1];
        return (pool.reserve0, pool.reserve1, pool.totalShares);
    }

    // 获取用户在特定池子中的份额
    function getUserShare(address _user, address _token0, address _token1) public view returns (uint256) {
        return userShares[_user][_token0][_token1];
    }
    // Additional functions: getAmountOut, price oracle, etc.
}
