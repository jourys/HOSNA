// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Hosna {
    // Role definitions
    enum Role { None, Charity, Donor, Admin }
    
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
        string encryptedPrivateKey;
    }
    
    struct Donor {
        string firstName;
        string lastName;
        string email;
        string phone;
        address wallet;
        bool registered;
        string encryptedPrivateKey;
    }
    
    struct Admin {
        string name;
        string email;
        address wallet;
        bool isActive;
    }

    // Storage variables
    mapping(address => Charity) private charities;
    mapping(bytes32 => address) private charityEmailToAddress;
    address[] private registeredCharities;
    
    mapping(address => Donor) private donors;
    mapping(bytes32 => address) private donorEmailToAddress;
    address[] private registeredDonors;
    
    mapping(address => Admin) private admins;
    mapping(bytes32 => address) private adminEmailToAddress;
    address[] private registeredAdmins;
    
    mapping(address => bytes32) private passwordHashes;
    mapping(address => Role) private userRoles;
    
    address private owner;

    // Events
    event CharityRegistered(address indexed wallet, string name, string email);
    event DonorRegistered(address indexed wallet, string firstName, string lastName, string email);
    event UserUpdated(address indexed wallet, Role role);

    constructor() {
        owner = msg.sender;
        _registerAdmin(
            "System Admin",
            "Admin@gmail.com",
            msg.sender,
            "Pass@12345678"
        );
    }

    // =============== MODIFIERS ===============
    
    modifier onlyAdmin() {
        require(userRoles[msg.sender] == Role.Admin, "Hosna: caller is not an admin");
        _;
    }
    
    modifier validAddress(address _wallet) {
        require(_wallet != address(0), "Hosna: invalid address");
        _;
    }
    
    modifier validRole(Role _role) {
        require(_role == Role.Charity || _role == Role.Donor || _role == Role.Admin, "Hosna: invalid role");
        _;
    }

    // =============== CHARITY FUNCTIONS ===============

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
        string memory _password,
        string memory _encryptedPrivateKey
    ) external validAddress(_wallet) {
        require(userRoles[_wallet] == Role.None, "Hosna: wallet already registered");
        bytes32 emailHash = _getEmailHash(_email);
        require(charityEmailToAddress[emailHash] == address(0), "Hosna: email already registered");
        require(bytes(_name).length > 0, "Hosna: name cannot be empty");
        require(bytes(_email).length > 0, "Hosna: email cannot be empty");
        require(bytes(_phone).length > 0, "Hosna: phone cannot be empty");

        // Create charity record
        charities[_wallet] = Charity({
            name: _name,
            email: _email,
            phone: _phone,
            licenseNumber: _licenseNumber,
            city: _city,
            description: _description,
            website: _website,
            establishmentDate: _establishmentDate,
            wallet: _wallet,
            registered: true,
            encryptedPrivateKey: _encryptedPrivateKey
        });

        // Set mappings
        charityEmailToAddress[emailHash] = _wallet;
        passwordHashes[_wallet] = keccak256(abi.encodePacked(_password));
        registeredCharities.push(_wallet);
        userRoles[_wallet] = Role.Charity;

        emit CharityRegistered(_wallet, _name, _email);
    }

    function updateCharity(
        address _wallet,
        string memory _name,
        string memory _email,
        string memory _phone,
        string memory _licenseNumber,
        string memory _city,
        string memory _description,
        string memory _website,
        string memory _establishmentDate,
        string memory _encryptedPrivateKey
    ) external validAddress(_wallet) {
        require(userRoles[_wallet] == Role.Charity, "Hosna: not a registered charity");
        require(charities[_wallet].registered, "Hosna: charity not active");
        require(bytes(_name).length > 0, "Hosna: name cannot be empty");
        require(bytes(_email).length > 0, "Hosna: email cannot be empty");
        require(bytes(_phone).length > 0, "Hosna: phone cannot be empty");

        Charity storage charity = charities[_wallet];

        // Remove old email mapping
        bytes32 oldEmailHash = _getEmailHash(charity.email);
        delete charityEmailToAddress[oldEmailHash];

        // Set new email mapping
        bytes32 newEmailHash = _getEmailHash(_email);
        require(charityEmailToAddress[newEmailHash] == address(0) || charityEmailToAddress[newEmailHash] == _wallet, 
            "Hosna: email already registered to another charity");
        charityEmailToAddress[newEmailHash] = _wallet;

        // Update charity data
        charity.name = _name;
        charity.email = _email;
        charity.phone = _phone;
        charity.licenseNumber = _licenseNumber;
        charity.city = _city;
        charity.description = _description;
        charity.website = _website;
        charity.establishmentDate = _establishmentDate;
        
        if (bytes(_encryptedPrivateKey).length > 0) {
            charity.encryptedPrivateKey = _encryptedPrivateKey;
        }

        emit UserUpdated(_wallet, Role.Charity);
    }

    // =============== DONOR FUNCTIONS ===============
    
    function registerDonor(
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _phone,
        address _wallet,
        string memory _password,
        string memory _encryptedPrivateKey
    ) external validAddress(_wallet) {
        require(userRoles[_wallet] == Role.None, "Hosna: wallet already registered");
        
        bytes32 emailHash = _getEmailHash(_email);
        require(donorEmailToAddress[emailHash] == address(0), "Hosna: email already registered");
        require(bytes(_firstName).length > 0, "Hosna: first name cannot be empty");
        require(bytes(_lastName).length > 0, "Hosna: last name cannot be empty");
        require(bytes(_email).length > 0, "Hosna: email cannot be empty");
        require(bytes(_phone).length > 0, "Hosna: phone cannot be empty");

        // Create donor record
        donors[_wallet] = Donor({
            firstName: _firstName,
            lastName: _lastName,
            email: _email,
            phone: _phone,
            wallet: _wallet,
            registered: true,
            encryptedPrivateKey: _encryptedPrivateKey
        });

        // Set mappings
        donorEmailToAddress[emailHash] = _wallet;
        passwordHashes[_wallet] = keccak256(abi.encodePacked(_password));
        registeredDonors.push(_wallet);
        userRoles[_wallet] = Role.Donor;

        emit DonorRegistered(_wallet, _firstName, _lastName, _email);
    }

    function updateDonor(
        address _wallet,
        string memory _firstName,
        string memory _lastName,
        string memory _email,
        string memory _phone,
        string memory _encryptedPrivateKey
    ) external validAddress(_wallet) {
        require(userRoles[_wallet] == Role.Donor, "Hosna: not a registered donor");
        require(donors[_wallet].registered, "Hosna: donor not active");
        require(bytes(_firstName).length > 0, "Hosna: first name cannot be empty");
        require(bytes(_lastName).length > 0, "Hosna: last name cannot be empty");
        require(bytes(_email).length > 0, "Hosna: email cannot be empty");
        require(bytes(_phone).length > 0, "Hosna: phone cannot be empty");

        Donor storage donor = donors[_wallet];

        // Remove old email mapping
        bytes32 oldEmailHash = _getEmailHash(donor.email);
        delete donorEmailToAddress[oldEmailHash];

        // Set new email mapping
        bytes32 newEmailHash = _getEmailHash(_email);
        require(donorEmailToAddress[newEmailHash] == address(0) || donorEmailToAddress[newEmailHash] == _wallet, 
            "Hosna: email already registered to another donor");
        donorEmailToAddress[newEmailHash] = _wallet;

        donor.firstName = _firstName;
        donor.lastName = _lastName;
        donor.email = _email;
        donor.phone = _phone;
        
        if (bytes(_encryptedPrivateKey).length > 0) {
            donor.encryptedPrivateKey = _encryptedPrivateKey;
        }

        emit UserUpdated(_wallet, Role.Donor);
    }

    // =============== ADMIN FUNCTIONS ===============
    
    // Private admin registration function (only used in constructor)
    function _registerAdmin(
        string memory _name,
        string memory _email,
        address _wallet,
        string memory _password
    ) private {
        bytes32 emailHash = _getEmailHash(_email);
        
        // Create admin record
        admins[_wallet] = Admin({
            name: _name,
            email: _email,
            wallet: _wallet,
            isActive: true
        });

        // Set mappings
        adminEmailToAddress[emailHash] = _wallet;
        passwordHashes[_wallet] = keccak256(abi.encodePacked(_password));
        registeredAdmins.push(_wallet);
        userRoles[_wallet] = Role.Admin;

    }

    // =============== AUTHENTICATION FUNCTIONS ===============

    function login(
        string memory _email,
        string memory _password,
        Role _role
    ) external view validRole(_role) returns (bool success, address wallet, string memory encryptedPrivateKey) {
        bytes32 hashedEmail = _getEmailHash(_email);
        address userAddress;
        
        // Get user address based on role
        if (_role == Role.Charity) {
            userAddress = charityEmailToAddress[hashedEmail];
            require(userAddress != address(0), "Hosna: charity email not found");
            require(charities[userAddress].registered, "Hosna: charity not active");
        } else if (_role == Role.Donor) {
            userAddress = donorEmailToAddress[hashedEmail];
            require(userAddress != address(0), "Hosna: donor email not found");
            require(donors[userAddress].registered, "Hosna: donor not active");
        } else { // Role.Admin
            userAddress = adminEmailToAddress[hashedEmail];
            require(userAddress != address(0), "Hosna: admin email not found");
            require(admins[userAddress].isActive, "Hosna: admin not active");
        }
        
        // Verify password
        bytes32 storedPasswordHash = passwordHashes[userAddress];
        require(storedPasswordHash != bytes32(0), "Hosna: password not set");
        
        success = storedPasswordHash == keccak256(abi.encodePacked(_password));
        wallet = success ? userAddress : address(0);
        
        // Get encrypted private key (only for charity and donor)
        if (success) {
            if (_role == Role.Charity) {
                encryptedPrivateKey = charities[userAddress].encryptedPrivateKey;
            } else if (_role == Role.Donor) {
                encryptedPrivateKey = donors[userAddress].encryptedPrivateKey;
            } else {
                encryptedPrivateKey = "";
            }
        }
        
        return (success, wallet, encryptedPrivateKey);
    }

    function resetPassword(
        address _wallet,
        string memory _newPassword
    ) external {
        require(userRoles[_wallet] != Role.None, "Hosna: user not registered");
        
        require(bytes(_newPassword).length >= 6, "Hosna: password too short");
        
        passwordHashes[_wallet] = keccak256(abi.encodePacked(_newPassword));
    }

    // =============== QUERY FUNCTIONS ===============

    function getAllCharities()
        external
        view
        returns (
            address[] memory wallets,
            string[] memory names,
            string[] memory emails,
            string[] memory phones,
            string[] memory cities,
            string[] memory websites
        )
    {
        uint256 count = registeredCharities.length;
        require(count > 0, "Hosna: no charities registered");

        wallets = new address[](count);
        names = new string[](count);
        emails = new string[](count);
        phones = new string[](count);
        cities = new string[](count);
        websites = new string[](count);

        uint256 activeCount = 0;
        for (uint256 i = 0; i < count; i++) {
            address charityWallet = registeredCharities[i];
            if (charities[charityWallet].registered) {
                Charity storage charity = charities[charityWallet];
                wallets[activeCount] = charity.wallet;
                names[activeCount] = charity.name;
                emails[activeCount] = charity.email;
                phones[activeCount] = charity.phone;
                cities[activeCount] = charity.city;
                websites[activeCount] = charity.website;
                activeCount++;
            }
        }

        // Truncate arrays to active count if needed
        if (activeCount < count) {
            assembly {
                mstore(wallets, activeCount)
                mstore(names, activeCount)
                mstore(emails, activeCount)
                mstore(phones, activeCount)
                mstore(cities, activeCount)
                mstore(websites, activeCount)
            }
        }

        return (wallets, names, emails, phones, cities, websites);
    }
    
    function getCharityDetails(address _wallet)
        external
        view
        returns (
            string memory description,
            string memory licenseNumber,
            string memory establishmentDate
        )
    {
        require(userRoles[_wallet] == Role.Charity, "Hosna: not a charity");
        require(charities[_wallet].registered, "Hosna: charity not active");
        
        Charity storage charity = charities[_wallet];
        return (
            charity.description,
            charity.licenseNumber,
            charity.establishmentDate
        );
    }
    
    function getAllDonors() 
        external 
        view 
        onlyAdmin
        returns (
            address[] memory wallets,
            string[] memory firstNames,
            string[] memory lastNames,
            string[] memory emails,
            string[] memory phones
        )
    {
        uint256 count = registeredDonors.length;
        require(count > 0, "Hosna: no donors registered");

        wallets = new address[](count);
        firstNames = new string[](count);
        lastNames = new string[](count);
        emails = new string[](count);
        phones = new string[](count);

        uint256 activeCount = 0;
        for (uint256 i = 0; i < count; i++) {
            address donorWallet = registeredDonors[i];
            if (donors[donorWallet].registered) {
                Donor storage donor = donors[donorWallet];
                wallets[activeCount] = donor.wallet;
                firstNames[activeCount] = donor.firstName;
                lastNames[activeCount] = donor.lastName;
                emails[activeCount] = donor.email;
                phones[activeCount] = donor.phone;
                activeCount++;
            }
        }

        // Truncate arrays to active count if needed
        if (activeCount < count) {
            assembly {
                mstore(wallets, activeCount)
                mstore(firstNames, activeCount)
                mstore(lastNames, activeCount)
                mstore(emails, activeCount)
                mstore(phones, activeCount)
            }
        }

        return (wallets, firstNames, lastNames, emails, phones);
    }

    function getCharity(address _wallet)
        external
        view
        returns (
            string memory name,
            string memory email,
            string memory phone,
            string memory city,
            string memory website,
            bool registered
        )
    {
        require(userRoles[_wallet] == Role.Charity, "Hosna: not a charity");
        
        Charity storage charity = charities[_wallet];
        return (
            charity.name,
            charity.email,
            charity.phone,
            charity.city,
            charity.website,
            charity.registered
        );
    }
    
    function getDonor(address _wallet)
        external
        view
        returns (
            string memory firstName,
            string memory lastName,
            string memory email,
            string memory phone,
            bool registered
        )
    {
        require(userRoles[_wallet] == Role.Donor, "Hosna: not a donor");
        
        Donor storage donor = donors[_wallet];
        return (
            donor.firstName,
            donor.lastName,
            donor.email,
            donor.phone,
            donor.registered
        );
    }
    
    function getUserRole(address _wallet) external view returns (Role) {
        return userRoles[_wallet];
    }

    function getCounts() external view returns (uint256 charityCount, uint256 donorCount, uint256 adminCount) {
        return (registeredCharities.length, registeredDonors.length, registeredAdmins.length);
    }

    function getCharityAddressByEmail(
        string memory _email
    ) public view returns (address) {
        return charityEmailToAddress[_getEmailHash(_email)];
    }

    function getDonorAddressByEmail(
        string memory _email
    ) public view returns (address) {
        return donorEmailToAddress[_getEmailHash(_email)];
    }

    function getAdminAddressByEmail(
        string memory _email
    ) public view returns (address) {
        return adminEmailToAddress[_getEmailHash(_email)];
    }

    // =============== UTILITY FUNCTIONS ===============
    
    function _getEmailHash(string memory _email) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(_toLowerCase(_email)));
    }
    
    function _toLowerCase(string memory str) private pure returns (string memory) {
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