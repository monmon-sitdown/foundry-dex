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

    struct Transaction {
        uint256 timestamp; // 交易的时间戳
        string action; // 交易类型：添加流动性、移除流动性、交换
        address token0; // 涉及的第一个代币地址
        address token1; // 涉及的第二个代币地址
        uint256 amount0; // 代币0的数量
        uint256 amount1; // 代币1的数量
    }

    uint256 public nextPoolId;
    mapping(uint256 id => Pool pool) public poolsbyID; // Using number ID as an index

    // Mapping from token pairs to their corresponding liquidity pools
    mapping(address token0 => mapping(address token1 => Pool pool)) public pools;

    // Mapping from users to their shares in each token pair pool
    mapping(address user => mapping(address token0 => mapping(address token1 => uint256 shares))) public userShares;

    // Mapping from user addresses to an array of transactions
    mapping(address user => Transaction[] transactions) public userTransactions;

    mapping(address user => mapping(address token => uint256 balance)) public userBalances;

    uint256 public constant MINIMUM_LIQUIDITY = 1; // Minimum liquidity to prevent extremely low liquidity

    uint256 private constant FEE_DENOMINATOR = 1000; // Denominator for fee calculations
    uint256 public feeRate = 3; // 0.3% feerate = feeRate / FEE_DENOMINATOR

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

    error Dex__TokenNotIdenticalAddresses();
    error Dex__NonExistToken();
    error Dex__PoolExisted();
    error Dex__PoolNoExisted();
    error Dex__InsufficientLiquidityMinted();
    error Dex__InvalidSharesAmount();
    error Dex__NoLiquidity();
    error Dex__InsufficientLiquidityBurned();
    error Dex__NotEnoughShares();
    error Dex__GetPrice_InsufficientLiquidity();

    /**
     * @dev Creates a new liquidity pool for the given token pair.
     * @param _token0 The address of the first token.
     * @param _token1 The address of the second token.
     * @notice The pool cannot be created if either token address is zero or the pool already exists.
     */
    function createPool(address _token0, address _token1) external {
        if (_token0 == address(0) || _token1 == address(0)) {
            revert Dex__NonExistToken();
        }
        (address token0, address token1) = sortTokens(_token0, _token1);

        if (address(pools[token0][token1].token0) != address(0)) {
            revert Dex__PoolExisted();
        }

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
        (address token0, address token1, uint256 amount0, uint256 amount1) =
            sortTokensAndAmount(_token0, _token1, _amount0, _amount1);
        Pool storage pool = pools[token0][token1];
        if (address(pool.token0) == address(0)) {
            revert Dex__PoolNoExisted();
        }

        if (pool.totalShares == 0) {
            shares = Math.sqrt(amount0 * amount1);
            pool.totalShares = shares > MINIMUM_LIQUIDITY ? 0 : MINIMUM_LIQUIDITY;
        } else {
            shares =
                Math.min((amount0 * pool.totalShares) / pool.reserve0, (amount1 * pool.totalShares) / pool.reserve1);
        }

        if (shares <= 0) {
            revert Dex__InsufficientLiquidityMinted();
        }

        pool.token0.transferFrom(msg.sender, address(this), amount0);
        pool.token1.transferFrom(msg.sender, address(this), amount1);

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;
        pool.totalShares += shares;
        userShares[msg.sender][token0][token1] += shares;

        // record the transaction
        userTransactions[msg.sender].push(
            Transaction(block.timestamp, "AddLiquidity", _token0, _token1, _amount0, _amount1)
        );

        emit LiquidityAdded(msg.sender, token0, token1, amount0, amount1, shares);
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
        (address token0, address token1) = sortTokens(_token0, _token1);
        Pool storage pool = pools[token0][token1];
        if (address(pool.token0) == address(0)) {
            revert Dex__PoolNoExisted();
        }

        if (_shares <= 0) {
            revert Dex__InvalidSharesAmount();
        }

        if (pool.totalShares <= 0) {
            revert Dex__NoLiquidity();
        }

        // Calculate how many token should be given to user
        amount0 = (_shares * pool.reserve0) / pool.totalShares;
        amount1 = (_shares * pool.reserve1) / pool.totalShares;
        /*console.log("amount0", amount0);
        console.log("amount1", amount1);
        console.log("pool.reserve0", pool.reserve0);
        console.log("pool.reserve1", pool.reserve1);*/

        // Check if the liquidity enought
        if (amount0 > pool.reserve0 || amount1 > pool.reserve1) {
            revert Dex__InsufficientLiquidityBurned();
        }

        // Check the shares of users
        if (userShares[msg.sender][token0][token1] < _shares) {
            revert Dex__NotEnoughShares();
        }

        // Update user shares
        userShares[msg.sender][token0][token1] -= _shares;
        pool.totalShares -= _shares;

        // update pool reserves
        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        // transfer tokens to user account
        pool.token0.transfer(msg.sender, amount0);
        pool.token1.transfer(msg.sender, amount1);

        // record transaction
        userTransactions[msg.sender].push(
            Transaction(block.timestamp, "RemoveLiquidity", _token0, _token1, amount0, amount1)
        );

        emit LiquidityRemoved(msg.sender, token0, token1, amount0, amount1, _shares);
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
        Pool storage pool = pools[_tokenIn][_tokenOut];
        //require(address(pool.token0) != address(0), "Pool doesn't exist");
        if (address(pool.token0) == address(0)) {
            pool = pools[_tokenOut][_tokenIn];
            if (address(pool.token0) == address(0)) {
                revert Dex__PoolNoExisted();
            }
        }

        bool isToken0 = _tokenIn == address(pool.token0);
        (IERC20 tokenIn, IERC20 tokenOut, uint256 reserveIn, uint256 reserveOut) = isToken0
            ? (pool.token0, pool.token1, pool.reserve0, pool.reserve1)
            : (pool.token1, pool.token0, pool.reserve1, pool.reserve0);

        console.log("reserveIn:", reserveIn);
        console.log("reserveOut:", reserveOut);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        console.log("amountIn:", _amountIn);

        uint256 amountInWithFee = (_amountIn * (FEE_DENOMINATOR - feeRate)) / FEE_DENOMINATOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);
        //aOut = reOurt - (reIn * reOut) / (reIn + aIn) 简化之后得到上面的式子 原理是恒定乘积市场（Constant Product Market，CPM）的原理，即 reserveIn * reserveOut 的乘积始终保持不变。

        tokenOut.transfer(msg.sender, amountOut);
        console.log("amountOut:", amountOut);

        //_updateReserves(pool, tokenIn.balanceOf(address(this)), tokenOut.balanceOf(address(this)));
        // Instead of using balanceOf, manually update reserves
        /*console.log("Before update, reserve0:", pool.reserve0);
        console.log("Before update, reserve1:", pool.reserve1);
        console.log("Amount out:", amountOut);*/

        if (isToken0) {
            pool.reserve0 += _amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += _amountIn;
            pool.reserve0 -= amountOut;
        }

        // Update user token balances
        /* console.log("User balance of tokenOut:", userBalances[msg.sender][_tokenOut]);
        console.log("Amount out:", amountOut);
        userBalances[msg.sender][_tokenIn] += _amountIn;
        userBalances[msg.sender][_tokenOut] -= amountOut;*/

        // record transaction
        userTransactions[msg.sender].push(
            Transaction(block.timestamp, "Swap", _tokenIn, _tokenOut, _amountIn, amountOut)
        );

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
        if (_token0 < _token1) {
            Pool storage pool = pools[_token0][_token1];
            return (pool.reserve0, pool.reserve1, pool.totalShares);
        } else {
            Pool storage pool = pools[_token1][_token0];
            return (pool.reserve1, pool.reserve0, pool.totalShares);
        }
    }

    /**
     * @dev Returns the current price of token0 in terms of token1.
     * @param _token0 The address of the first token.
     * @param _token1 The address of the second token.
     * @return price The current price of token0 in terms of token1.
     */
    function getTokenPrice(address _token0, address _token1) public view returns (uint256 price) {
        Pool storage pool;
        if (_token0 < _token1) {
            pool = pools[_token0][_token1];
        } else {
            pool = pools[_token1][_token0];
        }

        if (pool.reserve0 == 0 || pool.reserve1 == 0) {
            revert Dex__GetPrice_InsufficientLiquidity();
        }

        // Calculate price as reserve1/reserve0 价格表示为 token1 相对于 token0：
        price = _token0 < _token1 ? (pool.reserve1 * 1e18) / pool.reserve0 : (pool.reserve0 * 1e18) / pool.reserve1; // Multiply by 1e18 to return a more precise value
    }

    function isEmptyPool(address _token0, address _token1) public view returns (bool) {
        Pool storage pool;
        if (_token0 < _token1) {
            pool = pools[_token0][_token1];
        } else {
            pool = pools[_token1][_token0];
        }
        return pool.reserve0 == 0 && pool.reserve1 == 0;
    }

    // Get user shares in specific pool
    function getUserShare(address _user, address _token0, address _token1) public view returns (uint256) {
        return userShares[_user][_token0][_token1];
    }

    function getUserTransactions(address _user) external view returns (Transaction[] memory) {
        return userTransactions[_user];
    }
    //external 函数在处理大数组或字符串参数时更为高效，因为它可以直接使用 calldata 而无需将数据从 memory 复制到 calldata。

    // Function to get user token balance for a specific token
    function getUserTokenBalance(address _user, address _token) public view returns (uint256) {
        return userBalances[_user][_token];
    }

    function sortTokens(address _tokenA, address _tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    function sortTokensAndAmount(address _tokenA, address _tokenB, uint256 _amount0, uint256 _amount1)
        internal
        pure
        returns (address token0, address token1, uint256 amount0, uint256 amount1)
    {
        (token0, token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        (amount0, amount1) = _tokenA < _tokenB ? (_amount0, _amount1) : (_amount1, _amount0);
    }

    // Additional functions: getAmountOut, price oracle, etc.
}
