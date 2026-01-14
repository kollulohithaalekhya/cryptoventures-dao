// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./TreasuryBase.sol";
/**
 * @notice Executes an approved treasury transfer
 * @param to Recipient address
 * @param amount Amount of ETH to transfer
 */

/**
 * @title OperationalTreasury
 * @notice Low-risk treasury for routine expenses
 *
 * - Smaller transfers
 * - Timelock enforced
 */
contract OperationalTreasury is TreasuryBase {
    uint256 public immutable maxETHTransfer;

    constructor(address timelock, uint256 _maxETHTransfer)
        TreasuryBase(timelock)
    {
        require(_maxETHTransfer > 0, "Operational: max transfer zero");
        maxETHTransfer = _maxETHTransfer;
    }

    function transferETH(address to, uint256 amount) external {
        require(amount <= maxETHTransfer, "Operational: exceeds limit");
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
