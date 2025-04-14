// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

contract CharityVoting {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    struct Project {
        uint256 id;
        string name;
        uint256 funds;
        uint256 votes;
    }

    struct VotingSession {
        uint256 votingEndDate;
        uint256 totalVotes;
        uint256 totalProjects;
        bool isCanceled;
        Project[] projects; // Dynamic array to store project data
        mapping(address => bool) hasVoted;
        mapping(address => uint256) donorVotes;
    }

    uint256 public votingCounter;
    mapping(uint256 => VotingSession) public votingSessions;

    event VotingInitiated(uint256 votingId, uint256 votingEndDate);
    event Voted(uint256 votingId, address donor, uint256 projectId);
    event VotingEnded(uint256 votingId, uint256 winningProjectId);
    event FundsTransferred(uint256 votingId, uint256 projectId, uint256 amount);
    event VotingCanceled(uint256 votingId);

    modifier onlyDuringVoting(uint256 votingId) {
        require(
            block.timestamp < votingSessions[votingId].votingEndDate &&
                !votingSessions[votingId].isCanceled,
            "Voting ended or canceled"
        );
        _;
    }

    modifier onlyAfterVoting(uint256 votingId) {
        require(
            block.timestamp >= votingSessions[votingId].votingEndDate,
            "Voting ongoing"
        );
        _;
    }

    modifier onlyIfNotCanceled(uint256 votingId) {
        require(
            !votingSessions[votingId].isCanceled,
            "Voting session is canceled"
        );
        _;
    }

    modifier onlyIfNotAlreadyVoted(uint256 votingId) {
        require(
            !votingSessions[votingId].hasVoted[msg.sender],
            "Already voted"
        );
        _;
    }

    function initiateVoting(
        uint256 _votingDuration,
        uint256[] memory _projectIds,
        string[] memory _projectNames
    ) public returns (uint256) {
        // Add return type uint256
        require(
            _projectIds.length == _projectNames.length,
            "IDs and names mismatch"
        );

        votingCounter++;
        VotingSession storage session = votingSessions[votingCounter];
        session.votingEndDate = block.timestamp + _votingDuration;
        session.isCanceled = false;

        for (uint256 i = 0; i < _projectIds.length; i++) {
            session.projects.push(
                Project({
                    id: _projectIds[i],
                    name: _projectNames[i],
                    funds: 0,
                    votes: 0
                })
            );
            session.totalProjects++;
        }

        emit VotingInitiated(votingCounter, session.votingEndDate);
        return votingCounter; // Return the voting ID
    }

    function vote(
        uint256 votingId,
        uint256 projectIndex
    )
        public
        onlyDuringVoting(votingId)
        onlyIfNotCanceled(votingId)
        onlyIfNotAlreadyVoted(votingId)
    {
        VotingSession storage session = votingSessions[votingId];
        require(projectIndex < session.totalProjects, "Invalid project");

        session.hasVoted[msg.sender] = true;
        session.donorVotes[msg.sender] = projectIndex;
        session.projects[projectIndex].votes++;
        session.totalVotes++;

        emit Voted(votingId, msg.sender, projectIndex);
    }

    function endVoting(uint256 votingId) public onlyAfterVoting(votingId) {
        VotingSession storage session = votingSessions[votingId];
        uint256 highestVotes = 0;
        uint256 winningProjectIndex = 0;

        // Identify the project with the highest votes
        for (uint256 i = 0; i < session.totalProjects; i++) {
            if (session.projects[i].votes > highestVotes) {
                highestVotes = session.projects[i].votes;
                winningProjectIndex = i;
            }
        }

        // Transfer funds from losing projects to the winning project
        for (uint256 i = 0; i < session.totalProjects; i++) {
            if (i != winningProjectIndex) {
                uint256 funds = session.projects[i].funds;
                session.projects[winningProjectIndex].funds += funds;
                session.projects[i].funds = 0;

                emit FundsTransferred(votingId, i, funds);
            }
        }

        emit VotingEnded(votingId, winningProjectIndex);
    }

    // No owner restriction for canceling the voting session
    function cancelVoting(uint256 votingId) public {
        VotingSession storage session = votingSessions[votingId];
        require(
            block.timestamp < session.votingEndDate,
            "Voting already ended"
        );
        session.isCanceled = true;
        emit VotingCanceled(votingId);
    }

    function fundProject(
        uint256 votingId,
        uint256 projectIndex
    ) public payable {
        require(msg.value > 0, "Send funds");
        VotingSession storage session = votingSessions[votingId];
        require(projectIndex < session.totalProjects, "Invalid project");
        session.projects[projectIndex].funds += msg.value;
    }

    function getVotingDetails(
        uint256 votingId
    )
        public
        view
        returns (
            string[] memory projectNames,
            uint256[] memory percentages,
            uint256 remainingMonths,
            uint256 remainingDays,
            uint256 remainingHours,
            uint256 remainingMinutes
        )
    {
        VotingSession storage session = votingSessions[votingId];
        uint256 projectCount = session.totalProjects;

        projectNames = new string[](projectCount);
        percentages = new uint256[](projectCount);

        for (uint256 i = 0; i < projectCount; i++) {
            projectNames[i] = session.projects[i].name;
            percentages[i] = session.totalVotes > 0
                ? (session.projects[i].votes * 100) / session.totalVotes
                : 0;
        }

        uint256 timeLeft = session.votingEndDate > block.timestamp
            ? session.votingEndDate - block.timestamp
            : 0;

        remainingMonths = timeLeft / 30 days;
        remainingDays = (timeLeft % 30 days) / 1 days;
        remainingHours = (timeLeft % 1 days) / 1 hours;
        remainingMinutes = (timeLeft % 1 hours) / 1 minutes;
    }
}
