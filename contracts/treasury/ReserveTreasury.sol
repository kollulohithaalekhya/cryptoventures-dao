// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./TreasuryBase.sol";
/**
 * @notice Executes an approved treasury transfer
 * @param to Recipient address
 * @param amount Amount of ETH to transfer
 */

/**
 * @title ReserveTreasury
 * @notice Cold storage treasury
 *
 * - No ETH limits (governance-controlled)
 * - Longest timelock delay expected
 */
contract ReserveTreasury is TreasuryBase {
    constructor(address timelock)
        TreasuryBase(timelock)
    {}

    function transferETH(address to, uint256 amount) external {
        _transferETH(to, amount);
    }

    function transferERC20(
        address token,
        address to,
        uint256 amount
    )
        external
    {
        _transferERC20(token, to, amount);
    }
}
