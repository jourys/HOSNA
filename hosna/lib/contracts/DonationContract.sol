// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "./postProject.sol"; // Import the PostProject contract

contract DonationContract {
    PostProject public postProject; // Reference to the PostProject contract

    struct Donor {
        uint256 totalDonatedAnonymous;
        uint256 totalDonatedNonAnonymous;
        bool exists;
    }

    // **Track donations for each donor per project**
    mapping(uint256 => mapping(address => Donor)) private projectDonorsInfo;
    mapping(uint256 => uint256) public projectDonations;
    mapping(uint256 => address[]) public projectDonors; // Store donor addresses per project

    event DonationReceived(
        address indexed donor,
        uint256 amount,
        address indexed projectCreator,
        uint256 projectId,
        bool isAnonymous
    );

    event FundsTransferred(address indexed projectCreator, uint256 amount);

    constructor(address _postProjectAddress) {
        postProject = PostProject(_postProjectAddress);
    }

    function donate(uint256 projectId, bool isAnonymous) public payable {
        require(msg.value > 0, "Donation must be greater than zero");

        // Fetch project details from PostProject contract
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

        require(block.timestamp >= startDate, "Project has not started");
        require(block.timestamp <= endDate, "Project has ended");
        require(
            donatedAmount + msg.value <= totalAmount,
            "Donation exceeds total amount"
        );

        address donorAddress = msg.sender;

        // **Ensure donor is registered for this project**
        if (!projectDonorsInfo[projectId][donorAddress].exists) {
            projectDonorsInfo[projectId][donorAddress].exists = true;
            projectDonors[projectId].push(donorAddress); // Add donor to project
        }

        // **Update donation amount specific to this project**
        if (isAnonymous) {
            projectDonorsInfo[projectId][donorAddress]
                .totalDonatedAnonymous += msg.value;
        } else {
            projectDonorsInfo[projectId][donorAddress]
                .totalDonatedNonAnonymous += msg.value;
        }

        // **Update total project donations**
        projectDonations[projectId] += msg.value;

        // **Update the donated amount in PostProject contract**
        postProject.updateDonatedAmount(projectId, msg.value);

        // **If fully funded, transfer total to the organization**
        if (projectDonations[projectId] >= totalAmount) {
            uint256 totalDonation = projectDonations[projectId];
            projectDonations[projectId] = 0;

            (bool success, ) = payable(organization).call{value: totalDonation}(
                ""
            );
            require(success, "Transfer failed");

            emit FundsTransferred(organization, totalDonation);
        }

        emit DonationReceived(
            donorAddress,
            msg.value,
            organization,
            projectId,
            isAnonymous
        );
        emit FundsTransferred(organization, msg.value);
    }

    // **Get donor addresses and their donations for a specific project**
    function getProjectDonorsWithAmounts(
        uint256 projectId
    )
        external
        view
        returns (address[] memory, uint256[] memory, uint256[] memory)
    {
        uint256 donorCount = projectDonors[projectId].length;
        address[] memory addresses = new address[](donorCount);
        uint256[] memory amountsAnonymous = new uint256[](donorCount);
        uint256[] memory amountsNonAnonymous = new uint256[](donorCount);

        for (uint256 i = 0; i < donorCount; i++) {
            address donor = projectDonors[projectId][i];
            addresses[i] = donor;
            amountsAnonymous[i] = projectDonorsInfo[projectId][donor]
                .totalDonatedAnonymous;
            amountsNonAnonymous[i] = projectDonorsInfo[projectId][donor]
                .totalDonatedNonAnonymous;
        }

        return (addresses, amountsAnonymous, amountsNonAnonymous);
    }

    // **Get total donations for a specific project**
    function getProjectDonations(
        uint256 projectId
    ) external view returns (uint256) {
        return projectDonations[projectId];
    }

    // **Get donor's total donations in a project**
    function getDonorInfo(
        uint256 projectId,
        address donor
    ) external view returns (uint256, uint256) {
        return (
            projectDonorsInfo[projectId][donor].totalDonatedAnonymous,
            projectDonorsInfo[projectId][donor].totalDonatedNonAnonymous
        );
    }

    // **Get contract balance (for debugging)**
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function transferProjectFundsToAnother(
        uint256 fromProjectId,
        uint256 toProjectId
    ) external {
        (, , , , uint256 totalAmountFrom, , , , ) = postProject.getProject(
            fromProjectId
        );

        (
            ,
            ,
            uint startDateTo,
            uint endDateTo,
            uint256 totalAmountTo,
            uint256 donatedAmountTo,
            ,
            ,

        ) = postProject.getProject(toProjectId);

        require(block.timestamp >= startDateTo, "Target project not started");
        require(block.timestamp <= endDateTo, "Target project ended");

        uint256 amountToTransfer = projectDonations[fromProjectId];
        require(amountToTransfer > 0, "No funds to transfer");

        // Reset source project donations
        projectDonations[fromProjectId] = 0;

        // Update target project donation tracking
        projectDonations[toProjectId] += amountToTransfer;
        postProject.updateDonatedAmount(toProjectId, amountToTransfer);

        // If target project is now fully funded, transfer
        if (projectDonations[toProjectId] >= totalAmountTo) {
            address toOrganization;
            (, , , , , , toOrganization, , ) = postProject.getProject(
                toProjectId
            );

            uint256 totalDonation = projectDonations[toProjectId];
            projectDonations[toProjectId] = 0;

            (bool success, ) = payable(toOrganization).call{
                value: totalDonation
            }("");
            require(success, "Transfer to target organization failed");

            emit FundsTransferred(toOrganization, totalDonation);
        }
    }
}
