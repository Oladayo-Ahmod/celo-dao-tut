
# A Comprehensive Guide for Establishing a Decentralised Autonomous Organisation (DAO) on Celo

This tutorial provides a step-by-step method for creating and implementing a Decentralised Autonomous Organisation (DAO) on the Celo blockchain using hardhat deploy. The provided Solidity smart contract utilizes OpenZeppelin components for improved functionality and security.

## Table of Contents

- [Section 1: Recognising the Fundamentals](#section-1-recognising-the-fundamentals)
  - [1.1 Overview of Celo Blockchain and DAOs](#11-overview-of-celo-blockchain-and-daos)
- [Section 2: Smart Contract Development](#section-2-smart-contract-development)
  - [2.1 The Basics of Smart Contracts](#21-the-basics-of-smart-contracts)
- [Section 3: Code Explanation of the Smart Contracts](#section-3-code-explanation-of-the-smart-contracts)
  - [3.1 The Control of Roles and Access](#31-the-control-of-roles-and-access)
  - [3.2 Formulation of Proposals](#32-formulation-of-proposals)
- [Section 4: Involvement of Stakeholders](#section-4-involvement-of-stakeholders)
  - [4.1 Supporting the DAO](#41-supporting-the-dao)
  - [4.2 The Voting Process](#42-the-voting-process)
- [Section 5: Proposal Execution and Payments](#section-5-proposal-execution-and-payments)
  - [5.1 Payment Logic](#51-payment-logic).
  - [5.2 Single Proposal](#52-single-proposal)
  - [5.3 All proposals](#53-all-proposals)
  - [5.4 Proposal Vote](#54-proposal-votes)
- [Section 6: Stakeholders and Contributors](#section-6-stakeholders-and-contributors)
  - [6.1 Stakeholder Votes](#61-stakeholder-votes)
  - [6.2 Stakeholder Balance](#62-stakeholder-balance)
  - [6.3 DAO Total Balance](#63-dao-total-balance)
  - [6.4 Stakeholder Status](#64-stakeholder-status)
  - [6.5 Contributor Status](#65-contributor-status)
  - [6.6 Contributor Balance](#66-contributor-balance)
  - [6.7 Deployer Address](#67-deployer-address)
- [Section 7: Deploying the DAO on Celo using hardhat deploy](#7-deploying-the-dao-on-celo-using-hardhat-deploy)
  - [7.1 Install dependencies](#71-install-dependencies)
  - [7.2 Replace Lock.sol](#72-replace-lock.sol)
  - [7.3 Compile and Deploy](#73-compile-and-deploy)
## Section 1: Recognising the Fundamentals

### 1.1 Overview of Celo Blockchain and DAOs

Decentralized Autonomous Organisations (DAOs) revolutionize community-driven decision-making. This section discusses the importance of DAOs and highlights the unique characteristics of the Celo blockchain.

## Section 2: Smart Contract Development

### 2.1 The Basics of Smart Contracts

To begin, understand the basic framework of the Solidity-written DAO smart contract. The code incorporates the AccessControl and ReentrancyGuard libraries from OpenZeppelin, adding access control methods and defense against reentrancy attacks.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CeloDao is AccessControl, ReentrancyGuard {

    uint256 totalProposals;
    uint256 balance;

    uint256 immutable STAKEHOLDER_MIN_CONTRIBUTION = 0.1 ether;
    uint256 immutable MIN_VOTE_PERIOD = 5 minutes;
    bytes32 private immutable COLLABORATOR_ROLE = keccak256("collaborator");
    bytes32 private immutable STAKEHOLDER_ROLE = keccak256("stakeholder");

    mapping(uint256 => Proposals) private raisedProposals;
    mapping(address => uint256[]) private stakeholderVotes;
    mapping(uint256 => Voted[]) private votedOn;
    mapping(address => uint256) private contributors;

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

    struct Voted {
        address voter;
        uint256 timestamp;
        bool chosen;
    }

    modifier stakeholderOnly(string memory message) {
        require(hasRole(STAKEHOLDER_ROLE,msg.sender),message);
        _;
    }
    modifier contributorOnly(string memory message){
        require(hasRole(COLLABORATOR_ROLE,msg.sender),message);
        _;
    }

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

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // proposal creation
    function createProposal (
        string calldata title,
        string calldata description,
        address beneficiary,
        uint256 amount
    )external stakeholderOnly("Only stakeholders are allowed to create Proposals") returns(Proposals memory){
        uint256 currentID = totalProposals++;
        Proposals storage StakeholderProposal = raisedProposals[currentID];
        StakeholderProposal.id = currentID;
        StakeholderProposal.amount = amount;
        StakeholderProposal.title = title;
        StakeholderProposal.description = description;
        StakeholderProposal.beneficiary = payable(beneficiary);
        StakeholderProposal.duration = block.timestamp + MIN_VOTE_PERIOD;

        emit ProposalAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            'Proposal Raised',
            beneficiary,
            amount
        );
        return StakeholderProposal;
    }

    // voting
    function performVote(uint256 proposalId,bool chosen) external
    stakeholderOnly("Only stakeholders can perform voting")
    {
        Proposals storage StakeholderProposal = raisedProposals[proposalId];
        handleVoting(StakeholderProposal);
        if(chosen) StakeholderProposal.upVote++;
        else StakeholderProposal.downVotes++;

        stakeholderVotes[msg.sender].push(
            StakeholderProposal.id
        );
        votedOn[StakeholderProposal.id].push(
            Voted(
                msg.sender,
                block.timestamp,
                chosen
            )
        );

        emit VoteAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL VOTE",
            StakeholderProposal.beneficiary,
            StakeholderProposal.amount,
            StakeholderProposal.upVote,
            StakeholderProposal.downVotes,
            chosen
        );
    }

    // handling vote
    function handleVoting(Proposals storage proposal) private {
        if (proposal.passed || proposal.duration <= block.timestamp) {
            proposal.passed = true;
            revert("Time has already passed");
        }
        uint256[] memory tempVotes = stakeholderVotes[msg.sender];
        for (uint256 vote = 0; vote < tempVotes.length; vote++) {
            if (proposal.id == tempVotes[vote])
                revert("double voting is not allowed");
        }

    }

    // pay beneficiary
    function payBeneficiary(uint proposalId) external
    stakeholderOnly("Only stakeholders can make payment") nonReentrant() {
        Proposals storage stakeholderProposal = raisedProposals[proposalId];
        require(balance >= stakeholderProposal.amount, "insufficient fund");
        if(stakeholderProposal.paid == true) revert("payment already made");
        if(stakeholderProposal.upVote <= stakeholderProposal.downVotes) revert("insufficient votes");

        pay(stakeholderProposal.amount,stakeholderProposal.beneficiary);
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
    }

    // payment functionality
    function pay(uint256 amount,address to) internal {
        (bool success,) = payable(to).call{value : amount}("");
        require(success, "payment failed");
    }

    // contribution functionality
    function contribute() payable external returns(uint256){
        require(msg.value > 0 ether, "invalid amount");
        if (!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContributions = contributors[msg.sender] + msg.value;

            if (totalContributions >= STAKEHOLDER_MIN_CONTRIBUTION) {
                contributors[msg.sender] += msg.value;
                 _grantRole(STAKEHOLDER_ROLE,msg.sender);
                 _grantRole(COLLABORATOR_ROLE, msg.sender);
            }
            else {
                contributors[msg.sender] += msg.value;
                 _grantRole(COLLABORATOR_ROLE,msg.sender);
            }
        }
        else{
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

    // get single proposal
    function getProposals(uint256 proposalID) external view returns(Proposals memory) {
        return raisedProposals[proposalID];
    }

    // get all proposals
    function getAllProposals() external view returns(Proposals[] memory props){
        props = new Proposals;
        for (uint i = 0; i < totalProposals; i++) {
            props[i] = raisedProposals[i];
        }

    }

    // get a specific proposal votes
    function getProposalVote(uint256 proposalID) external view returns(Voted[] memory){
        return votedOn[proposalID];
    }

    // get stakeholders votes
    function getStakeholdersVotes() stakeholderOnly("Unauthorized") external view returns(uint256[] memory){
        return stakeholderVotes[msg.sender];
    }

    // get stakeholders balances
    function getStakeholdersBalances() stakeholderOnly("unauthorized") external view returns(uint256){
        return contributors[msg.sender];
    }

    // get total balance
    function getTotalBalance() external view returns(uint256){
        return balance;
    }

    // check if stakeholder
    function stakeholderStatus() external view returns(bool){
        return contributors[msg.sender] >= STAKEHOLDER_MIN_CONTRIBUTION;
    }

    // check if contributor
    function isContributor() external view returns(bool){
        return contributors[msg.sender] > 0;
    }

    // check contributors balance
    function getContributorsBalance() contributorOnly("unathorized") external view returns(uint256){
        return contributors[msg.sender];
    }
}


```

## Section 3: Code Explanation of the Smart Contracts

### 3.1 The Control of Roles and Access

Utilize OpenZeppelin's AccessControl package, providing role-based access control for secure interactions with collaborators and stakeholders.

```solidity
  import "@openzeppelin/contracts/access/AccessControl.sol";
  import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
```

### 3.2 Formulation of Proposals

this function allows stakeholders to create proposals by providing essential details such as `title` `description`, `beneficiary`, and `amount`. The function ensures that only `stakeholders` can initiate proposals, and it emits an event to notify external applications about the proposal creation.

```solidity
  function createProposal (
        string calldata title,
        string calldata description,
        address beneficiary,
        uint256 amount
    )external stakeholderOnly("Only stakeholders are allowed to create Proposals") returns(Proposals memory){
        uint256 currentID = totalProposals++;
        Proposals storage StakeholderProposal = raisedProposals[currentID];
        StakeholderProposal.id = currentID;
        StakeholderProposal.amount = amount;
        StakeholderProposal.title = title;
        StakeholderProposal.description = description;
        StakeholderProposal.beneficiary = payable(beneficiary);
        StakeholderProposal.duration = block.timestamp + MIN_VOTE_PERIOD;

        emit ProposalAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            'Proposal Raised',
            beneficiary,
            amount
        );
        return StakeholderProposal;
    }
```

## Section 4: Involvement of Stakeholders

### 4.1 Supporting the DAO

this function allows contributors to send Ether to the contract. If the contributor is not a stakeholder, it checks whether their total contributions meet the minimum requirement. If so, the contributor becomes a stakeholder and collaborator; otherwise, they become a collaborator only.

```solidity
    function contribute() payable external returns(uint256){
        require(msg.value > 0 ether, "invalid amount");
        if (!hasRole(STAKEHOLDER_ROLE, msg.sender)) {
            uint256 totalContributions = contributors[msg.sender] + msg.value;

            if (totalContributions >= STAKEHOLDER_MIN_CONTRIBUTION) {
                contributors[msg.sender] += msg.value;
                 _grantRole(STAKEHOLDER_ROLE,msg.sender);
                 _grantRole(COLLABORATOR_ROLE, msg.sender);
            }
            else {
                contributors[msg.sender] += msg.value;
                 _grantRole(COLLABORATOR_ROLE,msg.sender);
            }
        }
        else{
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
```

### 4.2 The Voting Process

this function facilitates the voting process for stakeholders, updating proposal details, 
recording votes, and emitting an event to notify external applications about the voting action.

```solidity
 function performVote(uint256 proposalId,bool chosen) external
    stakeholderOnly("Only stakeholders can perform voting")
    {
        Proposals storage StakeholderProposal = raisedProposals[proposalId];
        handleVoting(StakeholderProposal);
        if(chosen) StakeholderProposal.upVote++;
        else StakeholderProposal.downVotes++;

        stakeholderVotes[msg.sender].push(
            StakeholderProposal.id
        );
        votedOn[StakeholderProposal.id].push(
            Voted(
                msg.sender,
                block.timestamp,
                chosen
            )
        );

        emit VoteAction(
            msg.sender,
            STAKEHOLDER_ROLE,
            "PROPOSAL VOTE",
            StakeholderProposal.beneficiary,
            StakeholderProposal.amount,
            StakeholderProposal.upVote,
            StakeholderProposal.downVotes,
            chosen
        );
    }
```

## Section 5: Proposal Execution and Payments

### 5.1 Payment Logic

this function ensures the necessary conditions are met before making a payment to the beneficiary of a proposal. It records the payment details, updates the contract's balance, and emits an event to inform external applications about the successful payment action.

```solidity
    function payBeneficiary(uint proposalId) external
      stakeholderOnly("Only stakeholders can make payment") nonReentrant() {
          Proposals storage stakeholderProposal = raisedProposals[proposalId];
          require(balance >= stakeholderProposal.amount, "insufficient fund");
          if(stakeholderProposal.paid == true) revert("payment already made");
          if(stakeholderProposal.upVote <= stakeholderProposal.downVotes) revert("insufficient votes");
  
          pay(stakeholderProposal.amount,stakeholderProposal.beneficiary);
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
     }
```

### 5.2 Single proposal

this function retrieves single proposal using `proposalID`
```solidity
 function getProposals(uint256 proposalID) external view returns(Proposals memory) {
        return raisedProposals[proposalID];
    }
```

### 5.3 All proposals

this function retrieves all proposals
```solidity
 function getAllProposals() external view returns(Proposals[] memory props){
        props = new Proposals;
        for (uint i = 0; i < totalProposals; i++) {
            props[i] = raisedProposals[i];
        }
```

### 5.4 Proposal Votes

this function retrieves proposal votes
```solidity
  function getProposalVote(uint256 proposalID) external view returns(Voted[] memory){
        return votedOn[proposalID];
    }
```

## Section 6: Stakeholders and Contributors

### 6.1 Stakeholder Votes

this function retrieves stakeholder votes
```solidity
function getStakeholdersVotes() stakeholderOnly("Unauthorized") external view returns(uint256[] memory){
        return stakeholderVotes[msg.sender];
    }  
```

### 6.2 Stakeholder Balance

this function retrieves stakeholder balance
```solidity
 function getStakeholdersBalances() stakeholderOnly("unauthorized") external view returns(uint256){
        return contributors[msg.sender];
    }
```

### 6.3 DAO Total Balance

this function retrieves the balance of the DAO
```solidity
 function getTotalBalance() external view returns(uint256){
        return balance;
    }
```

### 6.4 Stakeholder Status

this function checks stakeholder status
```solidity
 function stakeholderStatus() external view returns(bool){
        return contributors[msg.sender] >= STAKEHOLDER_MIN_CONTRIBUTION;
    }

```

### 6.5 Contributor Status

this function checks the contributor status
```solidity
 function isContributor() external view returns(bool){
        return contributors[msg.sender] > 0;
    }
```

### 6.6 Contributor Balance

this function retrieves the contributor's balance
```solidity
    function getContributorsBalance() contributorOnly("unathorized") external view returns(uint256){
        return contributors[msg.sender];
    }
```

### 6.7 Deployer Address

this function returns the deployer address
```solidity
function getDeployer()external view returns(address){
        return deployer;

    }
```

## Section 7: Deploying the DAO on Celo using hardhat deploy

### 7.1 Install dependencies
Open your terminal and run the following commands

Create folder `mkdir celo-tut-dao`

Enter the folder `cd celo-tut-dao`

Initialize a node js project `npm init -y`

Install hardhat `npm install --save-dev hardhat`

Initialize hardhat `npx hardhat init`

Select `create a JavaScript project`
![hardhat](https://github.com/Oladayo-Ahmod/celo-dao-tutorial/assets/57647734/ba2e567f-8ddf-4f3f-81a8-d6648b757102)

install required dependencies `npm install --save-dev "hardhat@^2.19.2" "dotenv" "@nomicfoundation/hardhat-toolbox@^4.0.0" "@openzeppelin/contracts" "hardhat-deploy"`

replace your `hardhat.config.js` with the following code
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy")
require("dotenv").config()

/** @type import('hardhat/config').HardhatUserConfig */

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"

module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
        chainId: 31337,
    },
    localhost: {
        chainId: 31337,
    },
    alfajores: {
        url: "https://alfajores-forno.celo-testnet.org",
        accounts: [PRIVATE_KEY],
        chainId: 44787
      },
      celo: {
      url:  "https://forno.celo.org",
      accounts: [PRIVATE_KEY],
      chainId: 42220
    }
},
 namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },

    },

};

```

### 7.2 Replace Lock.sol
 Replace `Lock.sol` in the contract folder with `Dao.sol` and the code.
  ![dao-celo](https://github.com/Oladayo-Ahmod/celo-dao-tutorial/assets/57647734/873a9b19-a03c-43aa-90cb-d022552bd0b9)

  Add your private key to the `.env` file.
  ![api](https://github.com/Oladayo-Ahmod/celo-dao-tutorial/assets/57647734/f2719f73-b45b-4de0-ae60-960da8a6ff9a)



### 7.3 Compile and Deploy
run `npx hardhat compile` to compile the contract

create `deploy` folder, add `deploy.js` file to it and paste the following.

```javascript
module.exports = async ({getNamedAccounts, deployments}) => {
    const {deploy} = deployments;
    const {deployer} = await getNamedAccounts();
    await deploy('CeloDao', {
      from: deployer,
      args: [],
      log: true,
    });
  };
  module.exports.tags = ['CeloDao'];

```
run `npx hardhat deploy --network alfajores` to deploy to alfajores testnet

run `npx hardhat deploy --network celo` to deploy to celo mainnet


![dao-deploy](https://github.com/Oladayo-Ahmod/celo-dao-tutorial/assets/57647734/f0c046c1-2b76-4470-8ac2-4e75fc2e255b)
Congratulations! You have successfully deployed your DAO on the Celo blockchain using `hardhat deploy`. Feel free to explore further and test the various functionalities of your DAO.
