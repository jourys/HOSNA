// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./DonorRegistry.sol";

contract DonorAuth {
    DonorRegistry private donorRegistry;

    constructor(address _donorRegistryAddress) {
        donorRegistry = DonorRegistry(_donorRegistryAddress);
    }

    function loginDonor(
        string memory _email,
        string memory _password
    ) external view returns (bool) {
        // Ensure the email is registered
        address donorAddress = donorRegistry.emailToAddress(_email);
        require(donorAddress != address(0), "Email not registered");

        // Ensure the password is registered for the donor
        bytes32 storedPasswordHash = donorRegistry.getPasswordHash(donorAddress);
        require(storedPasswordHash != bytes32(0), "Password not set");

        // Hash the provided password and compare it with the stored one
        bytes32 providedPasswordHash = keccak256(abi.encodePacked(_password));
        require(storedPasswordHash == providedPasswordHash, "Invalid password");

        // If both the email and password are correct, authentication is successful
        return true;
    }
}
