// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./postProject.sol"; // Import the PostProject contract

contract DonationContract {
    PostProject public postProject; // Reference to the PostProject contract

    struct Donor {
        uint256 totalDonated;
    }

    mapping(address => Donor) private donors; // Track total donations by each donor
    mapping(uint256 => uint256) public projectDonations; // Track donations for each project

    event DonationReceived(
        address indexed donor,
        uint256 amount,
        address indexed projectCreator,
        uint256 projectId
    );

    event FundsTransferred(address indexed projectCreator, uint256 amount);

    constructor(address _postProjectAddress) {
        postProject = PostProject(_postProjectAddress); // Initialize the PostProject contract
    }

    function donate(uint256 projectId) public payable {
        require(msg.value > 0, "Donation must be greater than zero");

        // Fetch project details from the PostProject contract
        (
            ,
            ,
            uint startDate,
            uint endDate,
            uint256 totalAmount,
            uint256 donatedAmount,
            address organization,
            ,
            PostProject.ProjectState state 
        ) = postProject.getProject(projectId);
        state;

        require(block.timestamp >= startDate, "Project has not started");
        require(block.timestamp <= endDate, "Project has ended");
        require(
            donatedAmount + msg.value <= totalAmount,
            "Donation exceeds total amount"
        );

        // Update donor information
        donors[msg.sender].totalDonated += msg.value;

        // Update project donations
        projectDonations[projectId] += msg.value;

        // Update the donated amount in the PostProject contract **before** transferring funds
        postProject.updateDonatedAmount(projectId, msg.value);

        // Transfer funds to the project creator
        (bool success, ) = payable(organization).call{value: msg.value}("");
        require(success, "Transfer failed");

        emit DonationReceived(msg.sender, msg.value, organization, projectId);
        emit FundsTransferred(organization, msg.value);
    }

    // Get donor details
    function getDonorInfo(address donor) external view returns (uint256) {
        return donors[donor].totalDonated;
    }

    // Get total donations for a project
    function getProjectDonations(
        uint256 projectId
    ) external view returns (uint256) {
        return projectDonations[projectId];
    }

    // Check contract balance (for debugging)
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
