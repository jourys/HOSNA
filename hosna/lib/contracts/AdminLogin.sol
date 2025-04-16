// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract AdminAccount {
    string public adminEmail;  // Store plaintext email
    bytes32 private adminPasswordHash;  // Store hashed password
    address public admin;

    event AdminUpdated(string newEmail);
    event AdminDeleted(address deletedAdmin);

    constructor(string memory _email, string memory _password) {
        admin = msg.sender;
        adminEmail = _toLowerCase(_email);  // Convert to lowercase before storing
        adminPasswordHash = keccak256(abi.encodePacked(_password)); // Hash password before storing
    }

    function getAdminEmail() public view returns (string memory) {
        require(msg.sender == admin, "Only admin can view email");
        return adminEmail;
    }

    function updateAdminCredentials(string memory _newEmail, string memory _newPassword) public {
        require(msg.sender == admin, "Only the admin can update credentials");

        adminEmail = _toLowerCase(_newEmail);  // Convert to lowercase before storing
        adminPasswordHash = keccak256(abi.encodePacked(_newPassword));

        emit AdminUpdated(_newEmail);
    }

    function verifyLogin(string memory _email, string memory _password) public view returns (bool) {
        return (
            keccak256(abi.encodePacked(_password)) == adminPasswordHash &&
            keccak256(abi.encodePacked(_toLowerCase(_email))) == keccak256(abi.encodePacked(adminEmail))
        );
    }

    // ✅ Delete account function
    function deleteAccount() public {
        require(msg.sender == admin, "Only the admin can delete their account");

        // Reset all data
        adminEmail = "";
        adminPasswordHash = bytes32(0);
        admin = address(0);

        emit AdminDeleted(msg.sender);
    }

    // 🔧 Helper to convert strings to lowercase
        function _toLowerCase(string memory str) internal pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint i = 0; i < bStr.length; i++) {
            if ((bStr[i] >= 0x41) && (bStr[i] <= 0x5A)) {  // A-Z ASCII check
                bLower[i] = bytes1(uint8(bStr[i]) + 32);  // Convert to lowercase
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }
}
