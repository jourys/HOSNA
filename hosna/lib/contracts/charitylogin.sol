// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./CharityRegistration.sol"; // Import CharityRegistration contract

contract CharityAuth {
    CharityRegistration private charityRegistry;

    constructor(address _charityRegistryAddress) {
        charityRegistry = CharityRegistration(_charityRegistryAddress);
    }

function loginCharity(
    string memory _email,
    string memory _password
) external view returns (bool) {
    bytes32 hashedEmail = keccak256(abi.encodePacked(_toLowerCase(_email)));
    address charityAddress = charityRegistry.getCharityAddressByEmail(hashedEmail);
    require(charityAddress != address(0), "Charity email not found!");

    // ✅ Retrieve the stored hash from registration
    bytes32 storedPasswordHash = charityRegistry.getPasswordHash(charityAddress);
    require(storedPasswordHash != bytes32(0), "Password not set!");

    // ✅ Hash the provided password ONCE (No need to hash it twice!)
    if (storedPasswordHash == keccak256(abi.encodePacked(_password))) {
        return true; // ✅ Only return true here if password matches
    }






        return false;
    }

    // ✅ Debug function to verify email hash
    function debugCharityEmailHash(
        string memory _email
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(_toLowerCase(_email)));
    }

    // ✅ Debug function to verify stored password hash
    function debugCharityPasswordHash(
        address _wallet
    ) external view returns (bytes32) {
        return charityRegistry.getPasswordHash(_wallet);
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
