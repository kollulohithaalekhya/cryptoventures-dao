// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Roles
 * @author CryptoVentures DAO
 * @notice Centralized role definitions for governance & treasury system
 *
 * Roles are assigned ONLY during deployment or via governance proposals.
 * No EOAs should retain privileged roles long-term.
 */
contract Roles is AccessControl {
    /// @notice Admin role (bootstrap only)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Governor role (can create & vote on proposals)
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /// @notice Executor role (timelock executor)
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    /// @notice Treasury role (allowed to move funds when called by governance)
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    /**
     * @param admin Initial bootstrap admin (usually deployer, later revoked)
     */
    constructor(address admin) {
        require(admin != address(0), "Roles: admin is zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }

    /**
     * @notice Grant governor role
     * @dev Callable only via governance
     */
    function grantGovernor(address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _grantRole(GOVERNOR_ROLE, account);
    }

    /**
     * @notice Grant executor role (timelock)
     */
    function grantExecutor(address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _grantRole(EXECUTOR_ROLE, account);
    }

    /**
     * @notice Grant treasury role
     */
    function grantTreasury(address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _grantRole(TREASURY_ROLE, account);
    }

    /**
     * @notice Revoke any role
     * @dev Used when governance fully takes control
     */
    function revoke(bytes32 role, address account)
        external
        onlyRole(ADMIN_ROLE)
    {
        _revokeRole(role, account);
    }
}
