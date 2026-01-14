// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @notice Executes an approved treasury transfer
 * @param to Recipient address
 * @param amount Amount of ETH to transfer
 */

/**
 * @title TreasuryBase
 * @author CryptoVentures DAO
 * @notice Base treasury contract controlled by governance timelock
 *
 * - Holds ETH and ERC20 tokens
 * - Only Timelock can execute transfers
 * - Shared logic for all treasury tiers
 */
abstract contract TreasuryBase is AccessControl {
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    event ETHTransferred(address indexed to, uint256 amount);
    event ERC20Transferred(address indexed token, address indexed to, uint256 amount);

    constructor(address timelock) {
        require(timelock != address(0), "Treasury: timelock zero");

        _grantRole(DEFAULT_ADMIN_ROLE, timelock);
        _grantRole(EXECUTOR_ROLE, timelock);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE ETH
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL TRANSFERS
    //////////////////////////////////////////////////////////////*/

    function _transferETH(address to, uint256 amount)
        internal
        onlyRole(EXECUTOR_ROLE)
    {
        require(to != address(0), "Treasury: zero address");
        require(address(this).balance >= amount, "Treasury: insufficient ETH");

        (bool ok, ) = to.call{value: amount}("");
        require(ok, "Treasury: ETH transfer failed");

        emit ETHTransferred(to, amount);
    }

    function _transferERC20(
        address token,
        address to,
        uint256 amount
    )
        internal
        onlyRole(EXECUTOR_ROLE)
    {
        require(token != address(0), "Treasury: token zero");
        require(to != address(0), "Treasury: recipient zero");

        IERC20(token).transfer(to, amount);

        emit ERC20Transferred(token, to, amount);
    }
}
