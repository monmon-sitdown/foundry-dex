# Project Overview

This project is a decentralized exchange (DEX) platform implemented in Solidity. It allows users to create liquidity pools, add/remove liquidity, and swap between two ERC20 tokens. The project includes the following key components:

1. **DEXPlatform.sol**: The main smart contract file implementing the DEX platform's core functionalities.
2. **TestTokenERC20.sol**: A simple ERC20 token contract used for testing purposes.
3. **TestDex.t.sol**: A test file that includes unit tests to validate the functionalities of the DEX platform.

## Key Features

- **Create Liquidity Pools**: Users can create liquidity pools for any two ERC20 tokens.
- **Add Liquidity**: Users can add liquidity to existing pools and receive shares representing their contribution.
- **Remove Liquidity**: Users can remove liquidity and receive their share of tokens back.
- **Token Swap**: Users can swap one token for another within the existing pools, with a fee applied to each swap.
- **Token Price Calculation**: The contract can return the current price of one token in terms of another based on the liquidity pool reserves.

## Files

1. **DEXPlatform.sol:**

- Implements the DEX platform with functionalities for managing liquidity pools, adding/removing liquidity, and swapping tokens.
- Includes security features like reentrancy guards.
- Uses events to log critical actions such as pool creation, liquidity changes, and swaps.

2. **TestTokenERC20.sol:**

- A simple ERC20 token implementation based on OpenZeppelin's ERC20 contract.
- Includes a mint function for creating additional tokens, useful for testing purposes.

3. **TestDex.t.sol:**

- Contains unit tests for the DEX platform.
- Tests various scenarios like pool creation, adding/removing liquidity, and swapping tokens.
- Uses the Foundry testing framework for Solidity.

## Setup and Testing

To set up the project, install the required dependencies and compile the contracts. Use the Foundry framework to run the tests:

```bash
forge install
forge build
forge test
```

This project demonstrates a basic implementation of a decentralized exchange and includes tests to ensure its functionality.
