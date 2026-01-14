// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./TreasuryBase.sol";
/**
 * @notice Executes an approved treasury transfer
 * @param to Recipient address
 * @param amount Amount of ETH to transfer
 */

/**
 * @title InvestmentTreasury
 * @notice Medium-risk treasury for investments
 *
 * - ETH transfers capped
 * - ERC20 allowed (strategies controlled by governance)
 */
contract InvestmentTreasury is TreasuryBase {
    uint256 public immutable maxETHTransfer;

    constructor(address timelock, uint256 _maxETHTransfer)
        TreasuryBase(timelock)
    {
        require(_maxETHTransfer > 0, "Investment: max transfer zero");
        maxETHTransfer = _maxETHTransfer;
    }

    function transferETH(address to, uint256 amount) external {
        require(amount <= maxETHTransfer, "Investment: exceeds limit");
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
