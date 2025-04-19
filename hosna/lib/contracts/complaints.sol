// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// Import the existing DonorRegistry and CharityRegistration contracts
import "./DonorRegistry.sol";
import "./CharityRegistration.sol";

contract ComplaintRegistry {
    // Define the Complaint structure
    struct Complaint {
        string title;
        string description;
        address complainant;
        address targetCharity;
        uint256 timestamp;
        bool resolved; // To track if the complaint has been resolved
        bool isDonorComplaint; // To check if it's a complaint against a donor
    }

    // Store complaints by complaint ID
    mapping(uint256 => Complaint) public complaints;
    uint256 public complaintCount;

    // Reference to the DonorRegistry and CharityRegistration contracts
    DonorRegistry donorRegistry;
    CharityRegistration charityRegistration;

    // Event for new complaints
    event ComplaintCreated(
        uint256 indexed complaintId,
        string title,
        address indexed complainant,
        address indexed targetCharity,
        uint256 timestamp,
        bool resolved,
        bool isDonorComplaint // Add this field to indicate it's a donor complaint
    );

    // Event for deleted complaints

    // Constructor to initialize contract addresses
    constructor(address _donorRegistry, address _charityRegistration) {
        donorRegistry = DonorRegistry(_donorRegistry);
        charityRegistration = CharityRegistration(_charityRegistration);
    }

    // Function to submit a complaint
    function submitComplaint(
        string memory _title,
        string memory _description,
        address _targetCharity
    ) public {
        // Create the complaint
        complaintCount++;
        complaints[complaintCount] = Complaint({
            title: _title,
            description: _description,
            complainant: msg.sender,
            targetCharity: _targetCharity,
            timestamp: block.timestamp,
            resolved: false,
            isDonorComplaint: false // Not a donor-related complaint
        });

        // Emit the event
        emit ComplaintCreated(
            complaintCount,
            _title,
            msg.sender,
            _targetCharity,
            block.timestamp,
            false, // Explicitly set resolved to false
            false // Explicitly set isDonorComplaint to false
        );
    }

    // Function for charity to report a donor (new feature)
    function submitReportAgainstDonor(
        string memory _title,
        string memory _description,
        address _targetDonor
    ) public {
        // Create the complaint
        complaintCount++;
        complaints[complaintCount] = Complaint({
            title: _title,
            description: _description,
            complainant: msg.sender,
            targetCharity: address(0), // No charity involved, as this is a report against a donor
            timestamp: block.timestamp,
            resolved: false,
            isDonorComplaint: true // This is a donor-related complaint
        });

        // Emit the event
        emit ComplaintCreated(
            complaintCount,
            _title,
            msg.sender,
            address(0), // No charity involved
            block.timestamp,
            false, // Explicitly set resolved to false
            true // Explicitly set isDonorComplaint to true
        );
    }

    // Function to view a complaint by ID
    function viewComplaint(
        uint256 _complaintId
    )
        public
        view
        returns (
            string memory title,
            string memory description,
            address complainant,
            address targetCharity,
            uint256 timestamp,
            bool resolved,
            bool isDonorComplaint // Include this field in the view
        )
    {
        Complaint memory complaint = complaints[_complaintId];
        return (
            complaint.title,
            complaint.description,
            complaint.complainant,
            complaint.targetCharity,
            complaint.timestamp,
            complaint.resolved,
            complaint.isDonorComplaint // Return the isDonorComplaint field
        );
    }

    // Function to get all complaints
    function fetchAllComplaints()
        public
        view
        returns (
            uint256[] memory ids,
            string[] memory titles,
            string[] memory descriptions,
            address[] memory complainants,
            address[] memory targetCharities,
            uint256[] memory timestamps,
            bool[] memory resolvedStatuses,
            bool[] memory isDonorComplaints // Add this array to store the status of donor complaints
        )
    {
        uint256 total = complaintCount;

        ids = new uint256[](total);
        titles = new string[](total);
        descriptions = new string[](total);
        complainants = new address[](total);
        targetCharities = new address[](total);
        timestamps = new uint256[](total);
        resolvedStatuses = new bool[](total);
        isDonorComplaints = new bool[](total);

        for (uint256 i = 0; i < total; i++) {
            uint256 complaintId = i + 1; // Ensuring correct indexing
            Complaint storage c = complaints[complaintId];

            ids[i] = complaintId;
            titles[i] = c.title;
            descriptions[i] = c.description;
            complainants[i] = c.complainant;
            targetCharities[i] = c.targetCharity;
            timestamps[i] = c.timestamp;
            resolvedStatuses[i] = c.resolved;
            isDonorComplaints[i] = c.isDonorComplaint; // Store whether it's a donor complaint
        }
    }

    // Function to get the total number of complaints
    function getTotalComplaints() public view returns (uint256) {
        return complaintCount;
    }

    // Function for the admin to mark a complaint as resolved
    event ComplaintResolved(uint256 complaintId);

    function resolveComplaint(uint256 _complaintId) public {
        require(
            _complaintId > 0 && _complaintId <= complaintCount,
            "Invalid complaint ID"
        );

        // Ensure complaint exists
        require(
            bytes(complaints[_complaintId].title).length > 0,
            "Complaint does not exist"
        );

        // Update resolved status permanently
        complaints[_complaintId].resolved = true;

        // Emit event for frontend
        emit ComplaintResolved(_complaintId);
    }

    // Function to delete a complaint
    event ComplaintDeleted(uint256 complaintId);

    function deleteComplaint(uint256 _complaintId) public {
        // Ensure the complaint exists
        require(
            _complaintId > 0 && _complaintId <= complaintCount,
            "Complaint does not exist"
        );

        // Ensure the complaint is valid
        require(
            bytes(complaints[_complaintId].title).length > 0,
            "Complaint already deleted"
        );

        // Move last complaint into deleted spot (if it's not the last one)
        if (_complaintId != complaintCount) {
            complaints[_complaintId] = complaints[complaintCount]; // Swap with last
        }

        // Delete last complaint & update count
        delete complaints[complaintCount];
        complaintCount--;

        // Emit event to notify frontend
        emit ComplaintDeleted(_complaintId);
    }
}
