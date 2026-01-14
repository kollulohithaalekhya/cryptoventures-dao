// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @notice Simple ERC20 token for testing purposes
 */
contract MockToken is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {
        _mint(msg.sender, 1_000_000 ether);
    }
}
