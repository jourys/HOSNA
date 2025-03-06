// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PostProject {
    enum ProjectState {
        Upcoming,
        Active,
        InProgress,
        Completed,
        Failed
    }

    struct Project {
        uint id;
        string name;
        string description;
        uint startDate; // Unix timestamp
        uint endDate; // Unix timestamp
        uint256 totalAmount; // Total amount in Wei
        uint256 donatedAmount; // Donated amount in Wei
        address organization; // Organization that posted the project
        string projectType;
        ProjectState state; // Project status
    }

    Project[] public projects;
    mapping(uint => address) public projectToOrganization;

    event ProjectCreated(
        uint id,
        string name,
        string description,
        uint startDate,
        uint endDate,
        uint256 totalAmount, // Now stored in Wei
        address indexed organization,
        string projectType
    );

    event DonationReceived(
        uint indexed projectId,
        address indexed donor,
        uint256 amount // Amount in Wei
    );

    function addProject(
        string memory _name,
        string memory _description,
        uint _startDate,
        uint _endDate,
        uint256 _totalAmountInWei, // Amount passed in ETH
        string memory _projectType
    ) public {
        require(_startDate < _endDate, "Start date must be before end date");
        require(
            _totalAmountInWei > 0,
            "Total amount must be greater than zero"
        );

        uint projectId = projects.length;
        projects.push(
            Project(
                projectId,
                _name,
                _description,
                _startDate,
                _endDate,
                _totalAmountInWei, // Store in Wei
                0, // Initial donated amount (0 Wei)
                msg.sender,
                _projectType,
                ProjectState.Upcoming // Initial state
            )
        );
        projectToOrganization[projectId] = msg.sender;

        emit ProjectCreated(
            projectId,
            _name,
            _description,
            _startDate,
            _endDate,
            _totalAmountInWei,
            msg.sender,
            _projectType
        );
    }

    function updateDonatedAmount(
        uint _projectId,
        uint256 _amountInWei
    ) external {
        require(_projectId < projects.length, "Invalid project ID");

        Project storage project = projects[_projectId];

        project.donatedAmount += _amountInWei;

        updateProjectState(_projectId);

        emit DonationReceived(_projectId, msg.sender, _amountInWei);
    }

    function updateProjectState(uint _projectId) internal {
        Project storage project = projects[_projectId];

        if (block.timestamp < project.startDate) {
            project.state = ProjectState.Upcoming;
        } else if (block.timestamp > project.endDate) {
            if (project.donatedAmount >= project.totalAmount) {
                project.state = ProjectState.Completed;
            } else {
                project.state = ProjectState.Failed;
            }
        } else {
            if (project.donatedAmount >= project.totalAmount) {
                project.state = ProjectState.InProgress;
            } else {
                project.state = ProjectState.Active;
            }
        }
    }

    function getProject(
        uint _id
    )
        public
        view
        returns (
            string memory name,
            string memory description,
            uint startDate,
            uint endDate,
            uint256 totalAmount, // Amount in Wei
            uint256 donatedAmount, // Amount in Wei
            address organization,
            string memory projectType,
            ProjectState state
        )
    {
        require(_id < projects.length, "Invalid project ID");
        Project storage proj = projects[_id];
        return (
            proj.name,
            proj.description,
            proj.startDate,
            proj.endDate,
            proj.totalAmount,
            proj.donatedAmount,
            proj.organization,
            proj.projectType,
            proj.state
        );
    }

    function getProjectCount() public view returns (uint) {
        return projects.length;
    }

    function getOrganizationProjects(
        address _organization
    ) public view returns (uint[] memory) {
        uint count = 0;
        for (uint i = 0; i < projects.length; i++) {
            if (projects[i].organization == _organization) {
                count++;
            }
        }

        uint[] memory result = new uint[](count);
        uint index = 0;
        for (uint i = 0; i < projects.length; i++) {
            if (projects[i].organization == _organization) {
                result[index] = projects[i].id;
                index++;
            }
        }

        return result;
    }
}
