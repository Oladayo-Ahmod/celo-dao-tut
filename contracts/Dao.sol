// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CeloDao is AccessControl, ReentrancyGuard {
    // Constants
    uint256 immutable STAKEHOLDER_MIN_CONTRIBUTION = 0.1 ether;
    uint256 immutable MIN_VOTE_PERIOD = 5 minutes;
    bytes32 private immutable COLLABORATOR_ROLE = keccak256("collaborator");
    bytes32 private immutable STAKEHOLDER_ROLE = keccak256("stakeholder");

    // State variables
    uint256 totalProposals;
    uint256 balance;
    address deployer;

    // Proposal structure
    struct Proposals {
        uint256 id;
        uint256 amount;
        uint256 upVote;
        uint256 downVotes;
        uint256 duration;
        string title;
        string description;
        bool paid;
        bool passed;
        address payable beneficiary;
        address propoper;
        address executor;
    }

    // Vote structure
    struct Voted {
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    // Proposal mapping
    mapping(uint256 => Proposals) private raisedProposals;

    // Voter mappings
    mapping(address => uint256[]) private stakeholderVotes;
    mapping(uint256 => Voted[]) private votedOn;

    // Contributor and stakeholder mappings
    mapping(address => uint256) private contributors;
    mapping(address => uint256) private stakeholders;

    // Modifiers
    modifier stakeholderOnly(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE, msg.sender), message);
        _;
    }

    modifier contributorOnly(string memory message) {
        require(hasRole(COLLABORATOR_ROLE, msg.sender), message);
        _;
    }

    modifier onlyDeployer(string memory message) {
        require(msg.sender == deployer, message);
        _;
    }

    // Events
    event ProposalAction(
        address indexed creator,
        bytes32 role,
        string message,
        address indexed beneficiary,
        uint256 amount
    );

    event VoteAction(
        address indexed creator,
        bytes32 role,
        string message,
        address indexed beneficiary,
        uint256 amount,
        uint256 upVote,
        uint256 downVotes,
        bool chosen
    );

    // Constructor
    constructor() {
        deployer = msg.sender;
    }

    // Proposal creation function
    function createProposal(
        string calldata title,
        string calldata description,
        address beneficiary,
        uint256 amount
    ) external stakeholderOnly("Only stakeholders can create Proposals") returns (Proposals memory) {
        uint256 currentID = totalProposals++;
        Proposals storage stakeholderProposal = raisedProposals[currentID];
        stakeholderProposal.id = currentID;
        stakeholderProposal.amount = amount;
        stakeholderProposal.title = title;
        stakeholderProposal.description = description;
        stakeholderProposal.beneficiary = payable(beneficiary);
        stakeholderProposal.duration = block.timestamp + MIN_VOTE_PERIOD;

        emit ProposalAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            'Proposal Raised',
            beneficiary,
            amount
        );
        return stakeholderProposal;
    }

    // Voting function
    function performVote(uint256 proposalId, bool chosen)
        external
        stakeholderOnly("Only stakeholders can perform voting")
        returns (Voted memory)
    {
        Proposals storage stakeholderProposal = raisedProposals[proposalId];
        handleVoting(stakeholderProposal);
        if (chosen) stakeholderProposal.upVote++;
        else stakeholderProposal.downVotes++;

        stakeholderVotes[msg.sender].push(stakeholderProposal.id);
        votedOn[stakeholderProposal.id].push(Voted(msg.sender, block.timestamp, chosen));

        emit VoteAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL VOTE",
            stakeholderProposal.beneficiary,
            stakeholderProposal.amount,
            stakeholderProposal.upVote,
            stakeholderProposal.downVotes,
            chosen
        );

        return Voted(msg.sender, block.timestamp, chosen);
    }

    // Handling vote function
    function handleVoting(Proposals storage proposal) private {
        require(!proposal.passed, "Proposal has already passed");
        require(proposal.duration > block.timestamp, "Voting period has ended");
        uint256[] memory tempVotes = stakeholderVotes[msg.sender];
        for (uint256 vote = 0; vote < tempVotes.length; vote++) {
            require(proposal.id != tempVotes[vote], "Double voting is not allowed");
        }
    }

    // Pay beneficiary function
    function payBeneficiary(uint proposalId)
        external
        stakeholderOnly("Only stakeholders can make payment")
        onlyDeployer("Only deployer can make payment")
        nonReentrant()
        returns (uint256)
    {
        Proposals storage stakeholderProposal = raisedProposals[proposalId];
        require(balance >= stakeholderProposal.amount, "Insufficient funds");
        require(!stakeholderProposal.paid, "Payment already made");
        require(stakeholderProposal.upVote > stakeholderProposal.downVotes, "Insufficient votes");

        pay(stakeholderProposal.amount, stakeholderProposal.beneficiary);
        stakeholderProposal.paid = true;
        stakeholderProposal.executor = msg.sender;
        balance -= stakeholderProposal.amount;

        emit ProposalAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PAYMENT SUCCESSFULLY MADE!",
            stakeholderProposal.beneficiary,
            stakeholderProposal.amount
        );

        return balance;
    }

    // Payment function
    function pay(uint256 amount, address to) internal returns (bool) {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Payment failed");
        return true;
    }

    // Contribution function
    function contribute() payable external returns (uint256) {
        require(msg.value > 0 ether, "Invalid amount");
        if (!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContributions = contributors[msg.sender] + msg.value;

            if (totalContributions >= STAKEHOLDER_MIN_CONTRIBUTION) {
                stakeholders[msg.sender] = msg.value;
                contributors[msg.sender] += msg.value;
                _grantRole(STAKEHOLDER_ROLE, msg.sender);
                _grantRole(COLLABORATOR_ROLE, msg.sender);
            } else {
                contributors[msg.sender] += msg.value;
                _grantRole(COLLABORATOR_ROLE, msg.sender);
            }
        } else {
            stakeholders[msg.sender] += msg.value;
            contributors[msg.sender] += msg.value;
        }

        balance += msg.value;
        emit ProposalAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            "CONTRIBUTION SUCCESSFULLY RECEIVED!",
            address(this),
            msg.value
        );

        return balance;
    }

    // Get single proposal function
    function getProposals(uint256 proposalID) external view returns (Proposals memory) {
        return raisedProposals[proposalID];
    }

    // Get all proposals function
    function getAllProposals() external view returns (Proposals[] memory props
    ) {
        props = new Proposals[](totalProposals);
        for (uint256 i = 0; i < totalProposals; i++) {
            props[i] = raisedProposals[i];
        }
    }

    // Get specific proposal votes function
    function getProposalVote(uint256 proposalID) external view returns (Voted[] memory) {
        return votedOn[proposalID];
    }

    // Get stakeholder votes function
    function getStakeholdersVotes() stakeholderOnly("Unauthorized") external view returns (uint256[] memory) {
        return stakeholderVotes[msg.sender];
    }

    // Get stakeholder balances function
    function getStakeholdersBalances() stakeholderOnly("Unauthorized") external view returns (uint256) {
        return stakeholders[msg.sender];
    }

    // Get total balance function
    function getTotalBalance() external view returns (uint256) {
        return balance;
    }

    // Check if stakeholder function
    function stakeholderStatus() external view returns (bool) {
        return stakeholders[msg.sender] > 0;
    }

    // Check if contributor function
    function isContributor() external view returns (bool) {
        return contributors[msg.sender] > 0;
    }

    // Check contributors balance function
    function getContributorsBalance() contributorOnly("Unauthorized") external view returns (uint256) {
        return contributors[msg.sender];
    }

    // Get deployer address function
    function getDeployer() external view returns (address) {
        return deployer;
    }
}
