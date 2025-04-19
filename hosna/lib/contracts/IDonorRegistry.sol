// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDonorRegistry {
    function emailToAddress(
        string memory _email
    ) external view returns (address);
}

contract DonorLookup {
    IDonorRegistry public donorRegistry;

    constructor(address _donorRegistryAddress) {
        require(
            _donorRegistryAddress != address(0),
            "Invalid registry address"
        );
        donorRegistry = IDonorRegistry(_donorRegistryAddress);
    }

    function getWalletAddressByEmail(
        string memory _email
    ) public view returns (address) {
        address wallet = donorRegistry.emailToAddress(_email);
        require(wallet != address(0), "No donor found with this email");
        return wallet;
    }
}
