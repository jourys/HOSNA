// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPostProject {
    enum ProjectState {
        Upcoming,
        Active,
        InProgress,
        Completed,
        Failed,
        Voting
    }

    function getProject(
        uint _id
    )
        external
        view
        returns (
            string memory name,
            string memory description,
            uint startDate,
            uint endDate,
            uint256 totalAmount,
            uint256 donatedAmount,
            address organization,
            string memory projectType,
            ProjectState state
        );

    function updateProjectStateExternal(
        uint _id,
        ProjectState newState
    ) external;
}

contract VotingContract {
    struct VoteOption {
        uint projectId; // 0 means "Request Refund"
        uint voteCount;
    }

    struct Voting {
        uint votingId;
        uint originalProjectId;
        address initiator;
        uint startTime;
        uint endTime;
        bool finalized;
        mapping(uint => VoteOption) options;
        uint[] optionIds;
        mapping(address => bool) hasVoted;
    }

    IPostProject public postProject;
    uint public votingCounter;
    mapping(uint => Voting) public votings; // votingId => Voting
    mapping(uint => uint) public projectToVoting; // originalProjectId => votingId
    mapping(uint => mapping(address => bool)) public eligibleVoters; // projectId => donor => isEligible

    event VotingStarted(uint votingId, uint originalProjectId);
    event Voted(uint votingId, uint optionId, address voter);

    constructor(address _postProjectAddress) {
        postProject = IPostProject(_postProjectAddress);
    }

    function setEligibleVoters(
        uint projectId,
        address[] memory donors
    ) external {
        for (uint i = 0; i < donors.length; i++) {
            eligibleVoters[projectId][donors[i]] = true;
        }
    }

    function initiateVote(
        uint projectId,
        uint[] memory optionProjectIds,
        uint startTime,
        uint endTime
    ) external {
        require(startTime < endTime, "Invalid voting period");
        require(
            projectToVoting[projectId] == 0,
            "Vote already exists for this project"
        );

        (
            ,
            ,
            ,
            ,
            ,
            ,
            address organization,
            ,
            IPostProject.ProjectState state
        ) = postProject.getProject(projectId);
        require(
            state == IPostProject.ProjectState.Failed,
            "Project must be failed"
        );
        require(
            msg.sender == organization,
            "Only organization can initiate vote"
        );

        votingCounter++;
        Voting storage v = votings[votingCounter];
        v.votingId = votingCounter;
        v.originalProjectId = projectId;
        v.initiator = msg.sender;
        v.startTime = startTime;
        v.endTime = endTime;

        // Store the project options
        for (uint i = 0; i < optionProjectIds.length; i++) {
            v.options[optionProjectIds[i]] = VoteOption({
                projectId: optionProjectIds[i],
                voteCount: 0
            });
            v.optionIds.push(optionProjectIds[i]);
        }

        // Add "Request Refund" option with projectId = 0
        v.options[0] = VoteOption({projectId: 0, voteCount: 0});
        v.optionIds.push(0);

        projectToVoting[projectId] = votingCounter;
        postProject.updateProjectStateExternal(
            projectId,
            IPostProject.ProjectState.Voting
        );

        emit VotingStarted(votingCounter, projectId);
    }

    function vote(uint votingId, uint optionId) external {
        Voting storage v = votings[votingId];
        require(
            block.timestamp >= v.startTime && block.timestamp <= v.endTime,
            "Voting not active"
        );
        require(!v.hasVoted[msg.sender], "Already voted");
        require(
            eligibleVoters[v.originalProjectId][msg.sender],
            "Not eligible to vote"
        );

        v.options[optionId].voteCount++;
        v.hasVoted[msg.sender] = true;

        emit Voted(votingId, optionId, msg.sender);
    }

    function getVoteResults(
        uint votingId
    ) external view returns (uint[] memory optionIds, uint[] memory counts) {
        Voting storage v = votings[votingId];
        uint len = v.optionIds.length;
        optionIds = new uint[](len);
        counts = new uint[](len);

        for (uint i = 0; i < len; i++) {
            uint optionId = v.optionIds[i];
            optionIds[i] = optionId;
            counts[i] = v.options[optionId].voteCount;
        }
        return (optionIds, counts);
    }

    function getAvailableOptions(
        uint votingId
    ) external view returns (uint[] memory projectIds) {
        return votings[votingId].optionIds;
    }
}
