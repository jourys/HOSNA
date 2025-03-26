// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./postProject.sol"; // Import the PostProject contract

contract DonationContract {
    PostProject public postProject; // Reference to the PostProject contract

    struct Donor {
        uint256 totalDonated;
        bool exists; // Track if donor is already added to projectDonors
    }

    mapping(address => Donor) private donors; // Track total donations by each donor
    mapping(uint256 => uint256) public projectDonations; // Track donations for each project
    mapping(uint256 => address[]) public projectDonors; // Track unique donor addresses per project

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

        // Update donor's total donated amount
        donors[msg.sender].totalDonated += msg.value;

        // Update project donations
        projectDonations[projectId] += msg.value;

        // **Ensure donor is only added once to projectDonors**
        if (!donors[msg.sender].exists) {
            projectDonors[projectId].push(msg.sender);
            donors[msg.sender].exists = true;
        }

        // Update the donated amount in the PostProject contract **before** transferring funds
        postProject.updateDonatedAmount(projectId, msg.value);

        // Transfer funds to the project creator
        (bool success, ) = payable(organization).call{value: msg.value}("");
        require(success, "Transfer failed");

        emit DonationReceived(msg.sender, msg.value, organization, projectId);
        emit FundsTransferred(organization, msg.value);
    }

    // **Get all donor addresses & their total donated amount for a project**
    function getProjectDonorsWithAmounts(
        uint256 projectId
    ) external view returns (address[] memory, uint256[] memory) {
        uint256 donorCount = projectDonors[projectId].length;
        address[] memory addresses = new address[](donorCount);
        uint256[] memory amounts = new uint256[](donorCount);

        for (uint256 i = 0; i < donorCount; i++) {
            address donor = projectDonors[projectId][i];
            addresses[i] = donor;
            amounts[i] = donors[donor].totalDonated;
        }

        return (addresses, amounts);
    }

    // Get total donations for a project
    function getProjectDonations(
        uint256 projectId
    ) external view returns (uint256) {
        return projectDonations[projectId];
    }

    // Get total amount donated by a specific donor
    function getDonorInfo(address donor) external view returns (uint256) {
        return donors[donor].totalDonated;
    }

    // Check contract balance (for debugging)
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
