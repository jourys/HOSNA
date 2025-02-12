// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract CharityRegistration {
    struct Charity {
        string name;
        string email;
        string phone;
        string licenseNumber;
        string city;
        string description;
        string website;
        string establishmentDate;
        address wallet;
        bool registered;
    }

    mapping(address => Charity) private charities;
    mapping(bytes32 => address) private emailToAddress; // Hash emails for security
    mapping(bytes32 => address) private phoneToAddress; // Hash phone numbers for security
    mapping(address => bytes32) private passwordHashes; // Store hashed passwords

    event CharityRegistered(
        address indexed wallet,
        string name,
        string email,
        string phone
    );

    event Debug(string message);

    modifier uniqueEmail(string memory _email) {
        require(
            emailToAddress[keccak256(abi.encodePacked(_email))] == address(0),
            "Email already registered"
        );
        _;
    }

    modifier uniquePhone(string memory _phone) {
        require(
            phoneToAddress[keccak256(abi.encodePacked(_phone))] == address(0),
            "Phone number already registered"
        );
        _;
    }

    function isEmailRegistered(
        string memory _email
    ) public view returns (bool) {
        address charityAddress = emailToAddress[
            keccak256(abi.encodePacked(_email))
        ];
        return
            charityAddress != address(0) &&
            charities[charityAddress].registered;
    }

    function registerCharity(
        string memory _name,
        string memory _email,
        string memory _phone,
        string memory _licenseNumber,
        string memory _city,
        string memory _description,
        string memory _website,
        string memory _establishmentDate,
        address _wallet,
        string memory _password
    ) public uniqueEmail(_email) uniquePhone(_phone) {
        require(_wallet != address(0), "Invalid wallet address");
        require(bytes(_password).length > 0, "Password cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(bytes(_phone).length > 0, "Phone number cannot be empty");

        charities[_wallet] = Charity(
            _name,
            _email,
            _phone,
            _licenseNumber,
            _city,
            _description,
            _website,
            _establishmentDate,
            _wallet,
            true
        );

        passwordHashes[_wallet] = keccak256(abi.encodePacked(_password));

        // ✅ Convert email to lowercase before hashing it
        emailToAddress[
            keccak256(abi.encodePacked(_toLowerCase(_email)))
        ] = _wallet;
        phoneToAddress[keccak256(abi.encodePacked(_phone))] = _wallet;
    }

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

    function getCharity(
        address _wallet
    )
        public
        view
        returns (
            string memory name,
            string memory email,
            string memory phone,
            string memory licenseNumber,
            string memory city,
            string memory description,
            string memory website,
            string memory establishmentDate,
            address wallet,
            bool registered
        )
    {
        require(charities[_wallet].registered, "Charity not found");
        Charity memory c = charities[_wallet];
        return (
            c.name,
            c.email,
            c.phone,
            c.licenseNumber,
            c.city,
            c.description,
            c.website,
            c.establishmentDate,
            c.wallet,
            c.registered
        );
    }

    function getCharityAddressByEmail(
        bytes32 _hashedEmail
    ) public view returns (address) {
        return emailToAddress[_hashedEmail];
    }

    function getPasswordHash(address _wallet) external view returns (bytes32) {
        require(charities[_wallet].registered, "Charity not found");
        return passwordHashes[_wallet];
    }

    function debugPasswordHash(
        address _wallet
    ) external view returns (bytes32) {
        require(charities[_wallet].registered, "Charity not found");
        return passwordHashes[_wallet];
    }

    function checkCharityExists(
        string memory _email
    ) external view returns (bool) {
        return
            emailToAddress[keccak256(abi.encodePacked(_email))] != address(0);
    }
}
