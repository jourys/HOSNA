// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CharityRegistration.sol"; // Import the CharityRegistration contract

contract CharityEmailFetcher {
    CharityRegistration charityRegistration;

    // Set the address of the CharityRegistration contract
    constructor(address _charityRegistrationAddress) {
        charityRegistration = CharityRegistration(_charityRegistrationAddress);
    }

    // Function to get the charity wallet address based on email
    function getCharityWalletAddressByEmail(
        string memory _email
    ) public view returns (address) {
        // Hash the email and get the corresponding charity wallet address
        bytes32 hashedEmail = keccak256(abi.encodePacked(_email));
        return charityRegistration.getCharityAddressByEmail(hashedEmail);
    }
}
