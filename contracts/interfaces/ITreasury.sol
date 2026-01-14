// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ITreasury
 * @author CryptoVentures DAO
 * @notice Interface for DAO treasury contracts
 *
 * @dev Implemented by Operational, Investment, and Reserve treasuries
 */
interface ITreasury {
    /**
     * @notice Transfers ETH from the treasury
     * @param to Recipient address
     * @param amount Amount of ETH to transfer
     */
    function transferETH(address to, uint256 amount) external;
}
