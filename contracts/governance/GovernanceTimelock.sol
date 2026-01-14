// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title GovernanceTimelock
 * @author CryptoVentures DAO
 * @notice Timelock controller for DAO proposal execution
 *
 * - Enforces execution delay
 * - Only governance can queue & execute
 * - No EOAs should hold proposer/executor long-term
 */
contract GovernanceTimelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    )
        TimelockController(
            minDelay,
            proposers,
            executors,
            admin
        )
    {}
}
