// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./DonorRegistry.sol";

contract DonorAuth {
    DonorRegistry private donorRegistry;

    // Constructor initializes the DonorRegistry contract
    constructor(address _donorRegistryAddress) {
        donorRegistry = DonorRegistry(_donorRegistryAddress);
    }

    // Login function, accepts email and password for donor authentication
    function loginDonor(
        string memory _email,
        string memory _password
    ) external view returns (bool) {
        // Ensure the email is registered and map it to the donor's address
        address donorAddress = donorRegistry.emailToAddress(_email);
        require(donorAddress != address(0), "Email not registered");

        // Ensure the password is set for the donor
        bytes32 storedPasswordHash = donorRegistry.getPasswordHash(
            donorAddress
        );
        require(storedPasswordHash != bytes32(0), "Password not set");

        // Hash the provided password and compare it with the stored one
        bytes32 providedPasswordHash = keccak256(abi.encodePacked(_password));
        require(storedPasswordHash == providedPasswordHash, "Invalid password");

        // Return true if authentication is successful
        return true;
    }
}
