// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token0 is ERC20 {
    constructor() ERC20("Token0", "TK0") {
        _mint(msg.sender, 1000 * 10 ** decimals()); // 初始铸造 1000 个代币
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract Token1 is ERC20 {
    constructor() ERC20("Token1", "TK1") {
        _mint(msg.sender, 1000 * 10 ** decimals()); // 初始铸造 1000 个代币
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
