// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "./GovernanceVotes.sol";

contract GovernanceCore is AccessControl {
    using Math for uint256;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Queued,
        Executed
    }

    struct Proposal {
        address proposer;
        uint256 snapshotBlock;
        uint256 deadlineBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;

        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        bytes32 descriptionHash;
    }

    GovernanceVotes public immutable votesToken;
    TimelockController public immutable timelock;

    uint256 public proposalCount;
    uint256 public votingDelay;
    uint256 public votingPeriod;
    uint256 public quorumBps;
    uint256 public proposalThreshold;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 proposalId);
    event VoteCast(address voter, uint256 proposalId, uint8 support, uint256 weight);
    event ProposalQueued(uint256 proposalId);
    event ProposalExecuted(uint256 proposalId);

    constructor(
        GovernanceVotes _votesToken,
        TimelockController _timelock,
        address admin,
        uint256 _votingDelay,
        uint256 _votingPeriod,
        uint256 _quorumBps,
        uint256 _proposalThreshold
    ) {
        votesToken = _votesToken;
        timelock = _timelock;

        votingDelay = _votingDelay;
        votingPeriod = _votingPeriod;
        quorumBps = _quorumBps;
        proposalThreshold = _proposalThreshold;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            NON-LINEAR VOTING
    //////////////////////////////////////////////////////////////*/

    function _sqrt(uint256 x) internal pure returns (uint256) {
        return Math.sqrt(x);
    }

    function _votingPower(address voter, uint256 snapshotBlock)
        internal
        view
        returns (uint256)
    {
        uint256 linearVotes = votesToken.getPastVotes(voter, snapshotBlock);
        return _sqrt(linearVotes);
    }

    /*//////////////////////////////////////////////////////////////
                            PROPOSE
    //////////////////////////////////////////////////////////////*/

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external onlyRole(GOVERNOR_ROLE) returns (uint256 proposalId) {

        require(targets.length > 0, "No actions");
        require(
            targets.length == values.length &&
            targets.length == calldatas.length,
            "Length mismatch"
        );

        uint256 proposerVotes =
            votesToken.getPastVotes(msg.sender, block.number - 1);

        require(proposerVotes >= proposalThreshold, "Below threshold");

        uint256 snapshot = block.number + votingDelay;
        uint256 deadline = snapshot + votingPeriod;

        proposalCount++;
        proposalId = proposalCount;

        proposals[proposalId] = Proposal({
            proposer: msg.sender,
            snapshotBlock: snapshot,
            deadlineBlock: deadline,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            targets: targets,
            values: values,
            calldatas: calldatas,
            descriptionHash: keccak256(bytes(description))
        });

        emit ProposalCreated(proposalId);
    }

    /*//////////////////////////////////////////////////////////////
                            VOTE
    //////////////////////////////////////////////////////////////*/

    function castVote(uint256 proposalId, uint8 support)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(support <= 2, "Invalid support");
        require(state(proposalId) == ProposalState.Active, "Not active");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        Proposal storage proposal = proposals[proposalId];

        uint256 weight = _votingPower(msg.sender, proposal.snapshotBlock);
        require(weight > 0, "No power");

        hasVoted[proposalId][msg.sender] = true;

        if (support == 0) proposal.againstVotes += weight;
        else if (support == 1) proposal.forVotes += weight;
        else proposal.abstainVotes += weight;

        emit VoteCast(msg.sender, proposalId, support, weight);
    }

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    function state(uint256 proposalId)
        public
        view
        returns (ProposalState)
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.snapshotBlock != 0, "Invalid proposal");

        bytes32 idHash = _hashProposal(proposalId);

        if (timelock.isOperationDone(idHash))
            return ProposalState.Executed;

        if (timelock.isOperationPending(idHash))
            return ProposalState.Queued;

        if (block.number < proposal.snapshotBlock)
            return ProposalState.Pending;

        if (block.number <= proposal.deadlineBlock)
            return ProposalState.Active;

        uint256 totalSupply =
            votesToken.getPastTotalSupply(proposal.snapshotBlock);

        // Apply sqrt to total supply for fair quorum comparison
        uint256 sqrtSupply = totalSupply.sqrt();

        uint256 quorumVotes =
            Math.mulDiv(sqrtSupply, quorumBps, 10_000);
        uint256 totalVotes =
            proposal.forVotes +
            proposal.againstVotes +
            proposal.abstainVotes;

        if (
            totalVotes < quorumVotes ||
            proposal.forVotes <= proposal.againstVotes
        ) return ProposalState.Defeated;

        return ProposalState.Succeeded;
    }

    /*//////////////////////////////////////////////////////////////
                        TIMELOCK INTEGRATION
    //////////////////////////////////////////////////////////////*/

    function queue(uint256 proposalId)
        external
        onlyRole(GOVERNOR_ROLE)
    {
        require(state(proposalId) == ProposalState.Succeeded, "Not succeeded");

        Proposal storage proposal = proposals[proposalId];

        timelock.scheduleBatch(
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            bytes32(0),
            proposal.descriptionHash,
            timelock.getMinDelay()
        );

        emit ProposalQueued(proposalId);
    }

    function execute(uint256 proposalId)
        external
        payable
        onlyRole(GOVERNOR_ROLE)
    {
        Proposal storage proposal = proposals[proposalId];

        timelock.executeBatch{value: msg.value}(
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            bytes32(0),
            proposal.descriptionHash
        );

        emit ProposalExecuted(proposalId);
    }

    function _hashProposal(uint256 proposalId)
        internal
        view
        returns (bytes32)
    {
        Proposal storage proposal = proposals[proposalId];

        return timelock.hashOperationBatch(
            proposal.targets,
            proposal.values,
            proposal.calldatas,
            bytes32(0),
            proposal.descriptionHash
        );
    }
}