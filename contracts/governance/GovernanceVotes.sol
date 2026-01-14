// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title GovernanceVotes
 * @author CryptoVentures DAO
 * @notice ERC20-based governance token with delegation and snapshot-based voting
 *
 * @dev Features:
 * - ERC20Votes (Compound-style governance)
 * - Snapshot-based voting power via checkpoints
 * - Delegation support (self or third-party)
 * - Role-restricted minting and burning
 *
 * Voting power is determined at proposal snapshot blocks and
 * automatically includes delegated voting power.
 */
contract GovernanceVotes is
    ERC20,
    ERC20Permit,
    ERC20Votes,
    AccessControl
{
    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role allowed to mint and burn governance tokens
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deploys the governance token
     * @param name_ ERC20 token name
     * @param symbol_ ERC20 token symbol
     * @param governor Address granted mint/burn permissions
     */
    constructor(
        string memory name_,
        string memory symbol_,
        address governor
    )
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        require(governor != address(0), "Votes: governor zero address");
        _grantRole(GOVERNOR_ROLE, governor);
    }

    /*//////////////////////////////////////////////////////////////
                            MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mints governance tokens
     * @param to Recipient address
     * @param amount Amount of tokens to mint
     * @dev Restricted to GOVERNOR_ROLE
     */
    function mint(address to, uint256 amount)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        _mint(to, amount);
    }

    /**
     * @notice Burns governance tokens
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @dev Restricted to GOVERNOR_ROLE
     */
    function burn(address from, uint256 amount)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        _burn(from, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        REQUIRED OVERRIDES (OZ v4)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hook required by ERC20Votes to update voting checkpoints
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    /**
     * @dev Hook required by ERC20Votes to track minting checkpoints
     */
    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    /**
     * @dev Hook required by ERC20Votes to track burning checkpoints
     */
    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }
}
