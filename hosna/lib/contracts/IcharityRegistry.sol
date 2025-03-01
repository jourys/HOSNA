// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CharityRegistration.sol"; // Import the CharityRegistration contract

contract CharityEmailFetcher {
    CharityRegistration charityRegistration;

    // ✅ Set the address of the CharityRegistration contract in the constructor
    constructor(address _charityRegistrationAddress) {
        charityRegistration = CharityRegistration(_charityRegistrationAddress);
    }

    // ✅ Function to get the charity wallet address based on email
    function getCharityWalletAddressByEmail(
        string memory _email
    ) public view returns (address) {
        // 🔍 Convert email to lowercase before hashing it (Ensures consistency)
        bytes32 hashedEmail = keccak256(abi.encodePacked(_toLowerCase(_email)));
        return charityRegistration.getCharityAddressByEmail(hashedEmail);
    }

    // 🔹 Helper function to convert string to lowercase
    function _toLowerCase(
        string memory str
    ) private pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((bStr[i] >= 0x41) && (bStr[i] <= 0x5A)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
   

}
