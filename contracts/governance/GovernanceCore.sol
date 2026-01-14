// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./GovernanceVotes.sol";

/**
 * @title GovernanceCore
 * @author CryptoVentures DAO
 * @notice Core DAO governance contract responsible for proposal lifecycle management
 *
 * @dev Implements:
 * - Snapshot-based voting using ERC20Votes
 * - Proposal threshold & quorum enforcement
 * - One-way proposal state transitions
 * - Role-based access control for governance actions
 *
 * Proposal Lifecycle:
 * Pending → Active → Succeeded → Queued → Executed
 *                    ↘ Defeated
 */
contract GovernanceCore is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Role required to create proposals, vote, queue, and execute
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum voting delay in blocks
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice Minimum voting period in blocks (~1 week at 12s/block)
    uint256 public constant MIN_VOTING_PERIOD = 45818;

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice Possible lifecycle states of a proposal
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed,
        Expired
    }

    /// @notice Core proposal data stored on-chain
    struct Proposal {
        address proposer;
        uint256 snapshotBlock;
        uint256 deadlineBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        bool executed;
        bool queued;
    }

    /*//////////////////////////////////////////////////////////////
                              STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC20Votes-compatible governance token
    GovernanceVotes public immutable votesToken;

    /// @notice Total number of proposals created
    uint256 public proposalCount;

    /// @notice Delay (in blocks) before voting becomes active
    uint256 public votingDelay;

    /// @notice Duration (in blocks) of the voting period
    uint256 public votingPeriod;

    /// @notice Minimum quorum in basis points (e.g. 2000 = 20%)
    uint256 public quorumBps;

    /// @notice Minimum voting power required to create a proposal
    uint256 public proposalThreshold;

    /// @notice Mapping of proposal ID to proposal data
    mapping(uint256 => Proposal) public proposals;

    /// @notice Tracks whether an address has voted on a proposal
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a proposal is created
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        uint256 snapshotBlock,
        uint256 deadlineBlock
    );

    /// @notice Emitted when a vote is cast
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        uint8 support,
        uint256 weight
    );

    /// @notice Emitted when a proposal is queued
    event ProposalQueued(uint256 indexed proposalId);

    /// @notice Emitted when a proposal is executed
    event ProposalExecuted(uint256 indexed proposalId);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the governance system
     * @param _votesToken Address of the governance ERC20Votes token
     * @param admin Address granted admin & governor roles
     * @param _votingDelay Delay before voting starts (blocks)
     * @param _votingPeriod Duration of voting (blocks)
     * @param _quorumBps Quorum threshold in basis points
     * @param _proposalThreshold Minimum votes required to propose
     */
    constructor(
        GovernanceVotes _votesToken,
        address admin,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumBps,
        uint256 _proposalThreshold
    ) {
        require(address(_votesToken) != address(0), "Gov: votes token zero");
        require(admin != address(0), "Gov: admin zero");
        require(_votingPeriod >= MIN_VOTING_PERIOD, "Gov: voting period too short");
        require(_quorumBps <= 10_000, "Gov: quorum > 100%");

        votesToken = _votesToken;
        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        quorumBps = _quorumBps;
        proposalThreshold = _proposalThreshold;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                        PROPOSAL CREATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new governance proposal
     * @dev Caller must meet proposal threshold based on snapshot voting power
     * @return proposalId Unique identifier of the created proposal
     */
    function propose()
        external
        onlyRole(GOVERNOR_ROLE)
        returns (uint256 proposalId)
    {
        uint256 proposerVotes =
            votesToken.getPastVotes(msg.sender, block.number - 1);

        require(
            proposerVotes >= proposalThreshold,
            "Gov: proposer votes below threshold"
        );

        uint256 snapshot = block.number + votingDelay;
        uint256 deadline = snapshot + votingPeriod;

        proposalCount++;
        proposals[proposalCount] = Proposal({
            proposer: msg.sender,
            snapshotBlock: snapshot,
            deadlineBlock: deadline,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            executed: false,
            queued: false
        });

        emit ProposalCreated(
            proposalCount,
            msg.sender,
            snapshot,
            deadline
        );

        return proposalCount;
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Casts a vote on an active proposal
     * @param proposalId ID of the proposal
     * @param support Vote choice (0 = Against, 1 = For, 2 = Abstain)
     * @dev Voting power is determined via ERC20Votes snapshot
     */
    function castVote(uint256 proposalId, uint8 support)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(support <= 2, "Gov: invalid support");

        Proposal storage proposal = proposals[proposalId];

        require(state(proposalId) == ProposalState.Active, "Gov: voting closed");
        require(!hasVoted[proposalId][msg.sender], "Gov: already voted");

        uint256 weight =
            votesToken.getPastVotes(msg.sender, proposal.snapshotBlock);

        require(weight > 0, "Gov: no voting power");

        hasVoted[proposalId][msg.sender] = true;

        if (support == 0) {
            proposal.againstVotes += weight;
        } else if (support == 1) {
            proposal.forVotes += weight;
        } else {
            proposal.abstainVotes += weight;
        }

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /*//////////////////////////////////////////////////////////////
                          PROPOSAL STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current state of a proposal
     * @param proposalId ID of the proposal
     */
    function state(uint256 proposalId)
        public
        view
        returns (ProposalState)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.snapshotBlock != 0, "Gov: invalid proposal");

        if (proposal.executed) return ProposalState.Executed;
        if (proposal.queued) return ProposalState.Queued;
        if (block.number < proposal.snapshotBlock) return ProposalState.Pending;
        if (block.number <= proposal.deadlineBlock) return ProposalState.Active;

        uint256 totalSupplyAtSnapshot =
            votesToken.getPastTotalSupply(proposal.snapshotBlock);

        uint256 quorumVotes =
            Math.mulDiv(totalSupplyAtSnapshot, quorumBps, 10_000);

        uint256 totalParticipating =
            proposal.forVotes +
            proposal.againstVotes +
            proposal.abstainVotes;

        if (
            totalParticipating < quorumVotes ||
            proposal.forVotes <= proposal.againstVotes
        ) {
            return ProposalState.Defeated;
        }

        return ProposalState.Succeeded;
    }

    /*//////////////////////////////////////////////////////////////
                      QUEUE & EXECUTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Queues a succeeded proposal for execution
     * @param proposalId ID of the proposal
     */
    function queue(uint256 proposalId)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "Gov: proposal not succeeded"
        );

        proposals[proposalId].queued = true;
        emit ProposalQueued(proposalId);
    }

    /**
     * @notice Marks a queued proposal as executed
     * @param proposalId ID of the proposal
     */
    function execute(uint256 proposalId)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(
            state(proposalId) == ProposalState.Queued,
            "Gov: proposal not queued"
        );

        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }
}
