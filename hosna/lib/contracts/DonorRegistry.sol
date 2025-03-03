// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract DonorRegistry {
    struct Donor {
        string firstName;
        string lastName;
        string email;
        string phone;
        bytes32 passwordHash; // Securely storing hashed password
        address walletAddress;
        bool registered;
    }

    mapping(address => Donor) public donors;
    mapping(string => address) public emailToAddress; // Ensuring unique emails
    mapping(string => address) public phoneToAddress; // Ensuring unique phone numbers

    event DonorRegistered(
        address indexed walletAddress,
        string firstName,
        string lastName,
        string email,
        string phone
    );
  event DonorUpdated(
        address indexed walletAddress,
        string firstName,
        string lastName,
        string email,
        string phone
    );
    modifier uniquePhoneNumber(string memory _phone) {
        require(
            phoneToAddress[_phone] == address(0),
            "Phone number already registered"
        );
        _;
    }

    modifier uniqueEmail(string memory _email) {
        require(
            emailToAddress[_email] == address(0),
            "Email already registered"
        );
        _;
    }

    function registerDonor(
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _phone,
        string memory _password,
        address _wallet
    )
        public
        uniqueEmail(_email) // Ensure email is unique
        uniquePhoneNumber(_phone) // Ensure phone number is unique
    {
        require(bytes(_firstName).length > 0, "First name required");
        require(bytes(_lastName).length > 0, "Last name required");
        require(bytes(_email).length > 0, "Email required");
        require(bytes(_phone).length == 10, "Phone must be 10 digits");
        require(_wallet != address(0), "Invalid wallet address");

        bytes32 passwordHash = keccak256(abi.encodePacked(_password)); // Hashing password

        donors[_wallet] = Donor(
            _firstName,
            _lastName,
            _email,
            _phone,
            passwordHash,
            _wallet,
            true
        );

        emailToAddress[_email] = _wallet;
        phoneToAddress[_phone] = _wallet;

        emit DonorRegistered(_wallet, _firstName, _lastName, _email, _phone);
    }

    function getDonor(
        address _wallet
    )
        public
        view
        returns (
            string memory,
            string memory,
            string memory,
            string memory,
            address,
            bool
        )
    {
        Donor memory donor = donors[_wallet];
        require(donor.registered, "Donor not found");
        return (
            donor.firstName,
            donor.lastName,
            donor.email,
            donor.phone,
            donor.walletAddress,
            donor.registered
        );
    }

    // Add this function to get the password hash for a donor
    function getPasswordHash(address _wallet) public view returns (bytes32) {
        Donor memory donor = donors[_wallet];
        require(donor.registered, "Donor not found");
        return donor.passwordHash;
} function updateDonor(
        address _wallet,
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _phone
    ) public {
        require(donors[_wallet].registered, "Donor not registered");

        Donor storage donor = donors[_wallet];

        donor.firstName = _firstName;
        donor.lastName = _lastName;
        donor.email = _email;
        donor.phone = _phone;

        // ✅ Added event for updates
        emit DonorUpdated(_wallet, _firstName, _lastName, _email, _phone);
    }

}
