// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DonationContract {
    struct Donor {
        uint256 totalDonated;
    }

    mapping(address => Donor) private donors;

    event DonationReceived(
        address indexed donor,
        uint amount,
        address indexed projectCreator
    );

    event FundsTransferred(address indexed projectCreator, uint amount);

    event DonationInitiated(address indexed donor, address indexed projectCreator, uint256 amount); // Debugging Event

    function donate(address payable projectCreator) public payable {
        require(msg.value > 0, "Donation must be greater than zero");
        require(projectCreator != address(0), "Invalid project creator address");

        // Store donor information
        Donor storage donor = donors[msg.sender]; // Reference to the Donor struct for the sender
        donor.totalDonated += msg.value;

        // Emit donation initiated event for debugging
        emit DonationInitiated(msg.sender, projectCreator, msg.value); 

        // Transfer funds to the project creator
        (bool success, ) = projectCreator.call{value: msg.value}("");
        require(success, "Transfer failed");

        emit DonationReceived(msg.sender, msg.value, projectCreator);
        emit FundsTransferred(projectCreator, msg.value);
    }

    // Get donor details
    function getDonorInfo(address donor) external view returns (uint256 totalDonated) {
        require(donors[donor].totalDonated > 0, "Donor not found");

        return donors[donor].totalDonated;
    }

    // Optional: Check contract balance (for debugging)
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
