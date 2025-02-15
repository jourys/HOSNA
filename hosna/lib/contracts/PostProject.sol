// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PostProject {
    struct Project {
        uint id;
        string name;
        string description;
        uint startDate;  // Unix timestamp
        uint endDate;    // Unix timestamp
        uint totalAmount;
        address organization; // Address of the organization that posted the project
        string projectType;   
    }

    Project[] public projects;
    mapping(uint => address) public projectToOrganization; // Mapping project ID to organization

    event ProjectCreated(
        uint id,
        string name,
        string description,
        uint startDate,
        uint endDate,
        uint totalAmount,
        address indexed organization,
        string projectType 
    );

    function addProject(
        string memory _name, 
        string memory _description, 
        uint _startDate, 
        uint _endDate, 
        uint _totalAmount,
        string memory _projectType // New parameter
    ) public {
        require(_startDate < _endDate, "Start date must be before end date");
        require(_totalAmount > 0, "Total amount must be greater than zero");

        uint projectId = projects.length;
        projects.push(Project(projectId, _name, _description, _startDate, _endDate, _totalAmount, msg.sender, _projectType));
        projectToOrganization[projectId] = msg.sender;

        emit ProjectCreated(projectId, _name, _description, _startDate, _endDate, _totalAmount, msg.sender, _projectType);
    }

    function getProject(uint _id) public view returns (
        string memory name,
        string memory description,
        uint startDate,
        uint endDate,
        uint totalAmount,
        address organization,
        string memory projectType // New return value
    ) {
        require(_id < projects.length, "Invalid project ID");
        Project storage proj = projects[_id];
        return (proj.name, proj.description, proj.startDate, proj.endDate, proj.totalAmount, proj.organization, proj.projectType);
    }

    function getProjectCount() public view returns (uint) {
        return projects.length;
    }

    function getOrganizationProjects(address _organization) public view returns (uint[] memory) {
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