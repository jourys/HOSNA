import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

class OrganizationsPage extends StatefulWidget {
  final String walletAddress;
  const OrganizationsPage({super.key, required this.walletAddress});

  @override
  _OrganizationsPageState createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final String rpcUrl = 'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xdCa2F9A0040A0eD1eE2Df11bA027bf6270910eBF';

  late Web3Client _client;
  late DeployedContract _contract;
  List<Map<String, dynamic>> organizations = [];
  bool isLoading = true;
  TextEditingController _searchController = TextEditingController(); // Declare the controller

  final String abiString = '''
  [
    {
      "constant": true,
      "inputs": [],
      "name": "getAllCharities",
      "outputs": [
        { "name": "wallets", "type": "address[]" },
        { "name": "names", "type": "string[]" },
        { "name": "emails", "type": "string[]" },
        { "name": "phones", "type": "string[]" },
        { "name": "cities", "type": "string[]" },
        { "name": "websites", "type": "string[]" }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  String _searchQuery = '';  // Search query variable

  @override
  void initState() {
    super.initState();
    _client = Web3Client(rpcUrl, Client());
    _loadContract();
  }

  @override
  void dispose() {
    _searchController.dispose(); // Dispose the controller when the widget is disposed
    super.dispose();
  }

  Future<void> _loadContract() async {
    try {
      var abi = jsonDecode(abiString);
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), "CharityRegistration"),
        EthereumAddress.fromHex(contractAddress),
      );
      await _fetchCharities();
    } catch (e) {
      print("Error loading contract: $e");
    }
  }

  Future<void> _fetchCharities() async {
    try {
      final function = _contract.function("getAllCharities");
      final result = await _client.call(
        contract: _contract,
        function: function,
        params: [],
      );

      List<dynamic> wallets = result[0];
      List<dynamic> names = result[1];
      List<dynamic> emails = result[2];
      List<dynamic> phones = result[3];
      List<dynamic> cities = result[4];
      List<dynamic> websites = result[5];

      List<Map<String, dynamic>> tempOrganizations = [];
      for (int i = 0; i < wallets.length; i++) {
        tempOrganizations.add({
          "wallet": wallets[i].toString(),
          "name": names[i],
          "email": emails[i],
          "phone": phones[i],
          "city": cities[i],
          "website": websites[i],
        });
      }

      setState(() {
        organizations = tempOrganizations;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching charities: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to filter organizations based on search query
  List<Map<String, dynamic>> _getFilteredOrganizations() {
    if (_searchQuery.isEmpty) {
      return organizations;
    } else {
      return organizations.where((organization) {
        return organization["name"].toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  // Function to handle search query input
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background matches app bar
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80), // Increase app bar height
        child: AppBar(
          backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
          elevation: 0, // Remove shadow
          automaticallyImplyLeading: false, // Remove back arrow
          flexibleSpace: Padding(
            padding: EdgeInsets.only(bottom: 20), // Move text down
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                "Organizations",
                style: TextStyle(
                  color: Colors.white, // Make text white
                  fontSize: 24, // Increase font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
     body: Column(
  children: [
   
    Expanded(
   child: Container(
  decoration: const BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Round top corners
  ),
  padding: const EdgeInsets.all(16.0),
  child: Column(
    children: [
      // Search bar at the top
      Padding(
        padding: const EdgeInsets.all(6.0),
        child: TextField(
          controller: _searchController, // Bind the controller to the search bar
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search Organizations',
            hintStyle: TextStyle(color: Colors.black),
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
            ),
            prefixIcon: Icon(Icons.search, color: Colors.black),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.black),
                    onPressed: () {
                      _searchController.clear(); // Clears the text input
                      _onSearchChanged(''); // Reset search filter
                    },
                  )
                : null,
          ),
          style: TextStyle(color: Colors.black),
        ),
      ),
      
      // Loading or organizations list
      isLoading
          ? const Center(child: CircularProgressIndicator())
          : _getFilteredOrganizations().isEmpty
              ? const Center(child: Text("No registered charities found."))
              : Expanded(
                  child: ListView.builder(
                    itemCount: _getFilteredOrganizations().length,
                    itemBuilder: (context, index) {
                      var charity = _getFilteredOrganizations()[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), // Rounded corners
                          side: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                        ),
                        color: Color.fromARGB(255, 239, 236, 236),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          leading: SizedBox(
                            width: 60, // Increased width
                            height: 100, // Increased height
                            child: CircleAvatar(
                              radius: 40, // Increased avatar size
                              backgroundColor: Colors.transparent,
                              child: Icon(Icons.account_circle, size: 75, color: Colors.grey), // Increased icon size
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                charity["name"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20, // Increased font size
                                ),
                              ),
                              const SizedBox(height: 6), // Adds spacing between name and subtitle
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 25, color: Colors.grey),
                                  SizedBox(width: 4), // Adds spacing between the icon and text
                                  Text(
                                    " ${charity["city"]}",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16, // Increased font size
                                      fontWeight: FontWeight.w500, // Optional: Make it slightly bolder
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.email, size: 25, color: Colors.grey),
                                  SizedBox(width: 4), // Adds spacing between the icon and text
                                  Text(
                                    " ${charity["email"]}",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16, // Increased font size
                                      fontWeight: FontWeight.w500, // Optional: Make it slightly bolder
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.flag, color: Colors.grey, size: 36), // Increased icon size
                            iconSize: 38, // Ensures the button itself is larger
                            onPressed: () {
                              // Implement report functionality
                            },
                          ),
                          onTap: () {
                            // Navigate to Organization Profile Page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrganizationProfilePage(organization: charity),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    ],
  ),
),

          ),
        ],
      ),
    );
  }
}



class OrganizationProfilePage extends StatelessWidget {
  final Map<String, dynamic> organization;

  const OrganizationProfilePage({super.key, required this.organization});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1), // Top bar color
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80), // Increased app bar height
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0, // Remove shadow
          leading: Padding(
            padding: const EdgeInsets.only(top: 20), // Adjust icon position
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 30, // Adjusted size
              ),
              onPressed: () {
                Navigator.pop(context); // Navigate back
              },
            ),
          ),
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(bottom: 20), // Moves text down
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                organization["name"] ?? "Unknown Organization",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24, // Increased size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.account_circle, size: 120, color: Colors.grey), // Enlarged profile icon
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(Icons.contact_phone, "Contact Information"),
            _buildInfoRow(Icons.phone, "Phone", organization["phone"]),
            _buildInfoRow(Icons.email, "Email", organization["email"]),
            _buildInfoRow(Icons.location_city, "City", organization["city"]),

            const SizedBox(height: 16),

            _buildSectionTitle(Icons.business, "Organization Details"),
            _buildInfoRow(Icons.badge, "License Number", organization["licenseNumber"]),
            _buildInfoRow(Icons.public, "Website", organization["website"], isLink: true),
            _buildInfoRow(Icons.calendar_today, "Established", organization["establishmentDate"]),

            const SizedBox(height: 16),

            _buildSectionTitle(Icons.info_outline, "About Us"),
            _buildInfoRow(Icons.description, "About Us", organization["description"]),

            const Spacer(), // Push button to bottom

           Center(
 child: ElevatedButton(
                onPressed: () async {
  try {
    // Call the loadProjects() method
    await loadProjects();

    // Navigate to projects page (replace with actual navigation)
    Navigator.pushNamed(
      context,
      '/projects',
      arguments: organization["id"],
    );
  } catch (e) {
    // Handle any errors that occur during project loading
    print("Error occurred: $e");
    // Optionally, show a dialog or Snackbar to notify the user about the error
  }
},


    child: const Text(
      "View Projects",
      style: TextStyle(
        fontSize: 20,
       
        color: Colors.white, // Ensuring text is white
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1), // Matching theme color
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 100), // Increased padding for a longer button
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
),

            const SizedBox(height: 20), // Add spacing at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icon(icon, size: 28, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value, {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.blueGrey), // Adjusted icon size
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? "N/A",
              style: TextStyle(
                fontSize: 18, // Increased text size
                color: isLink ? Colors.blue : Colors.black87,
                decoration: isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
Future<void> loadProjects() async {
  BlockchainService blockchainService = BlockchainService();
  String organizationAddress = "0x25f30375f43dce255c8261ab6baf64f4ab62a87c"; // Replace with actual address
  try {
    List<Map<String, dynamic>> projects = await blockchainService.fetchOrganizationProjects(organizationAddress);

    for (var project in projects) {
      var name = project["name"];
      var totalAmount = project["totalAmount"];
      
      // Check if totalAmount is valid and convert it to int
      int totalAmountInt = totalAmount != null ? int.tryParse(totalAmount.toString()) ?? 0 : 0;

      print("Project Name: $name, Total Amount: $totalAmountInt");
    }
  } catch (e) {
    print("Error loading projects: $e");
  }
}



}
class ProjectsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Projects")),
      body: Center(child: Text("Projects List")),
    );
  }
}
