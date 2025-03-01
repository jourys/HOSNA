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
    mapping(bytes32 => address) private emailToAddress;
    mapping(bytes32 => address) private phoneToAddress;
    mapping(address => bytes32) private passwordHashes;
    address[] private registeredCharities; // Stores addresses of registered charities

    event CharityRegistered(
        address indexed wallet,
        string name,
        string email,
        string phone
    );
    event CharityUpdated(
        address indexed wallet,
        string name,
        string email,
        string phone
    );
    event Debug(string message);

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
    ) public {
        require(_wallet != address(0), "Invalid wallet address");

        // 🔍 Hash email and store correctly
        bytes32 emailHash = keccak256(abi.encodePacked(_toLowerCase(_email)));

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

        emailToAddress[emailHash] = _wallet;
        passwordHashes[_wallet] = keccak256(abi.encodePacked(_password));
        registeredCharities.push(_wallet); // Store registered charity wallet

        emit CharityRegistered(_wallet, _name, _email, _phone);
    }
    function getAllCharities() public view returns (
        address[] memory wallets,
        string[] memory names,
        string[] memory emails,
        string[] memory phones,
        string[] memory cities,
        string[] memory websites
    ) {
        uint count = registeredCharities.length;
        
        wallets = new address[](count);
        names = new string[](count);
        emails = new string[](count);
        phones = new string[](count);
        cities = new string[](count);
        websites = new string[](count);

        for (uint i = 0; i < count; i++) {
            address charityWallet = registeredCharities[i];
            Charity storage charity = charities[charityWallet];

            wallets[i] = charity.wallet;
            names[i] = charity.name;
            emails[i] = charity.email;
            phones[i] = charity.phone;
            cities[i] = charity.city;
            websites[i] = charity.website;
        }

        return (wallets, names, emails, phones, cities, websites);
    }

    // ✅ **Force Link Email to Wallet (Fix for your issue)**
    function forceLinkEmailToWallet(
        string memory _email,
        address _wallet
    ) public {
        require(_wallet != address(0), "Invalid wallet address");
        require(charities[_wallet].registered, "Charity not registered");

        bytes32 emailHash = keccak256(abi.encodePacked(_toLowerCase(_email)));
        emailToAddress[emailHash] = _wallet;
    }

    function getCharityAddressByEmail(
        bytes32 _hashedEmail
    ) public view returns (address) {
        return emailToAddress[_hashedEmail];
    }

    function debugStoredEmailHash(
        string memory _email
    ) public view returns (address) {
        return
            emailToAddress[keccak256(abi.encodePacked(_toLowerCase(_email)))];
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

    function checkCharityExists(
        string memory _email
    ) external view returns (bool) {
        return
            emailToAddress[keccak256(abi.encodePacked(_toLowerCase(_email)))] !=
            address(0);
    }

    // ✅ **Fixed `updateCharity` Placement (Now Inside the Contract)**
    function updateCharity(
        address _wallet,
        string memory _name,
        string memory _email,
        string memory _phone,
        string memory _licenseNumber,
        string memory _city,
        string memory _description,
        string memory _website,
        string memory _establishmentDate
    ) public {
        require(charities[_wallet].registered, "Charity not registered");

        Charity storage charity = charities[_wallet];

        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(bytes(_phone).length > 0, "Phone cannot be empty");

        charity.name = _name;
        charity.email = _email;
        charity.phone = _phone;
        charity.licenseNumber = _licenseNumber;
        charity.city = _city;
        charity.description = _description;
        charity.website = _website;
        charity.establishmentDate = _establishmentDate;

        emit CharityUpdated(_wallet, _name, _email, _phone);
    }

    function getPasswordHash(address _wallet) public view returns (bytes32) {
        require(charities[_wallet].registered, "Charity not found");
        return passwordHashes[_wallet];
    }

    function debugEmailMapping(
        string memory _email
    ) public view returns (address) {
        bytes32 emailHash = keccak256(abi.encodePacked(_toLowerCase(_email)));
        return emailToAddress[emailHash];
    }

    function debugCharityMapping(
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
            bool registered
        )
    {
        require(charities[_wallet].registered, "Charity not found");
        Charity storage charity = charities[_wallet];
        return (
            charity.name,
            charity.email,
            charity.phone,
            charity.licenseNumber,
            charity.city,
            charity.description,
            charity.website,
            charity.establishmentDate,
            charity.registered
        );
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
            string memory establishmentDate
        )
    {
        require(charities[_wallet].registered, "Charity not found");
        Charity storage charity = charities[_wallet];
        return (
            charity.name,
            charity.email,
            charity.phone,
            charity.licenseNumber,
            charity.city,
            charity.description,
            charity.website,
            charity.establishmentDate
        );
    }
}
