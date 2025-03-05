import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart';

class OrganizationsPage extends StatefulWidget {
  final String walletAddress;
  const OrganizationsPage({super.key, required this.walletAddress});

  @override
  _OrganizationsPageState createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x02b0d417D48eEA64Aae9AdA80570783034ED6839';

  late Web3Client _client;
  late DeployedContract _contract;
  List<Map<String, dynamic>> organizations = [];
  bool isLoading = true;
  TextEditingController _searchController =
      TextEditingController(); // Declare the controller

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
      { "name": "websites", "type": "string[]" },
      { "name": "descriptions", "type": "string[]" },
      { "name": "licenseNumbers", "type": "string[]" },
      { "name": "establishmentDates", "type": "string[]" }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  String _searchQuery = ''; // Search query variable

  @override
  void initState() {
    super.initState();
    _client = Web3Client(rpcUrl, Client());
    _loadContract();
  }

  @override
  void dispose() {
    _searchController
        .dispose(); // Dispose the controller when the widget is disposed
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
      List<dynamic> descriptions = result[6]; // New field
      List<dynamic> licenseNumbers = result[7]; // New field
      List<dynamic> establishmentDates = result[8]; // New field

      List<Map<String, dynamic>> tempOrganizations = [];
      for (int i = 0; i < wallets.length; i++) {
        tempOrganizations.add({
          "wallet": wallets[i].toString(),
          "name": names[i],
          "email": emails[i],
          "phone": phones[i],
          "city": cities[i],
          "website": websites[i],
          "description": descriptions[i], // Adding description
          "licenseNumber": licenseNumbers[i], // Adding license number
          "establishmentDate":
              establishmentDates[i], // Adding establishment date
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
        return organization["name"]
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
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
      backgroundColor:
          Color.fromRGBO(24, 71, 137, 1), // Background matches app bar
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
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20)), // Round top corners
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Search bar at the top
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: TextField(
                      controller:
                          _searchController, // Bind the controller to the search bar
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search Organizations',
                        hintStyle: TextStyle(color: Colors.black),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.black),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.black),
                                onPressed: () {
                                  _searchController
                                      .clear(); // Clears the text input
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
                          ? const Center(
                              child: Text("No registered charities found."))
                          : Expanded(
                              child: ListView.builder(
                                itemCount: _getFilteredOrganizations().length,
                                itemBuilder: (context, index) {
                                  var charity =
                                      _getFilteredOrganizations()[index];
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          12), // Rounded corners
                                      side: BorderSide(
                                          color: Color.fromRGBO(24, 71, 137, 1),
                                          width: 2),
                                    ),
                                    color: Color.fromARGB(255, 239, 236, 236),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      leading: SizedBox(
                                        width: 60, // Increased width
                                        height: 100, // Increased height
                                        child: CircleAvatar(
                                          radius: 40, // Increased avatar size
                                          backgroundColor: Colors.transparent,
                                          child: Icon(Icons.account_circle,
                                              size: 75,
                                              color: Colors
                                                  .grey), // Increased icon size
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            charity["name"],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  20, // Increased font size
                                            ),
                                          ),
                                          const SizedBox(
                                              height:
                                                  6), // Adds spacing between name and subtitle
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.location_on,
                                                  size: 25, color: Colors.grey),
                                              SizedBox(
                                                  width:
                                                      4), // Adds spacing between the icon and text
                                              Text(
                                                " ${charity["city"]}",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize:
                                                      16, // Increased font size
                                                  fontWeight: FontWeight
                                                      .w500, // Optional: Make it slightly bolder
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Icon(Icons.email,
                                                  size: 25, color: Colors.grey),
                                              SizedBox(
                                                  width:
                                                      4), // Adds spacing between the icon and text
                                              Text(
                                                " ${charity["email"]}",
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize:
                                                      16, // Increased font size
                                                  fontWeight: FontWeight
                                                      .w500, // Optional: Make it slightly bolder
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.flag,
                                            color: Colors.grey,
                                            size: 36), // Increased icon size
                                        iconSize:
                                            38, // Ensures the button itself is larger
                                        onPressed: () {
                                          // Implement report functionality
                                        },
                                      ),
                                      onTap: () {
                                        // Navigate to Organization Profile Page
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                OrganizationProfilePage(
                                                    organization: charity),
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
    // Get the address and validate it before passing
    String orgAddress = organization["wallet"];
    print("Organization Wallet Address: $orgAddress");
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
              child: Icon(Icons.account_circle,
                  size: 120, color: Colors.grey), // Enlarged profile icon
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(Icons.contact_phone, "Contact Information"),
            _buildInfoRow(Icons.phone, "Phone", organization["phone"]),
            _buildInfoRow(Icons.email, "Email", organization["email"]),
            _buildInfoRow(Icons.location_city, "City", organization["city"]),

            const SizedBox(height: 16),

            _buildSectionTitle(Icons.business, "Organization Details"),
            _buildInfoRow(
                Icons.badge, "License Number", organization["licenseNumber"]),
            _buildInfoRow(Icons.public, "Website", organization["website"],
                isLink: true),
            _buildInfoRow(Icons.calendar_today, "Established",
                organization["establishmentDate"]),

            const SizedBox(height: 16),

            _buildSectionTitle(Icons.info_outline, "About Us"),
            _buildInfoRow(
                Icons.description, "About Us", organization["description"]),

            const Spacer(), // Push button to bottom

            Center(
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to the View Projects page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewProjectsPage(
                        orgAddress: organization["wallet"],
                        orgName: organization["name"] ??
                            "Organization", // Pass org name
                      ),
                    ),
                  );
                },
                child: const Text(
                  "View Projects",
                  style: TextStyle(
                    fontSize: 20,

                    color: Colors.white, // Ensuring text is white
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(
                      24, 71, 137, 1), // Matching theme color
                  padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 100), // Increased padding for a longer button
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

  Widget _buildInfoRow(IconData icon, String label, String? value,
      {bool isLink = false}) {
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
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ViewProjectsPage extends StatefulWidget {
  final String orgAddress;
  final String orgName; // Add organization name

  ViewProjectsPage({required this.orgAddress, required this.orgName});

  @override
  _ViewProjectsPageState createState() => _ViewProjectsPageState();
}

class _ViewProjectsPageState extends State<ViewProjectsPage> {
  late Future<List<Map<String, dynamic>>> projects;

  @override
  void initState() {
    super.initState();
    print("Fetching projects for organization address: ${widget.orgAddress}");
    projects = BlockchainService().fetchOrganizationProjects(widget.orgAddress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(
          24, 71, 137, 1), // Background color behind the white container

      appBar: AppBar(
        toolbarHeight:
            70, // Increase the height of the AppBar to move elements down
        title: Padding(
          padding: EdgeInsets.only(bottom: 1), // Move the title slightly down
          child: Text(
            "${widget.orgName}'s Projects", // Display the organization name
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold, // Make text bold
              fontSize: 25, // Increase font size
            ),
          ),
        ),
        centerTitle: true, // Center the title
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        elevation: 0, // Remove shadow for a smooth transition
        iconTheme: IconThemeData(
          color: Colors.white, // Set back arrow color to white
          size: 30, // Increase icon size
          weight: 800, // Make arrow bold
        ),
        leading: Padding(
          padding: EdgeInsets.only(
              left: 10, bottom: 1), // Move the arrow slightly down
          child: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),

      body: Stack(
        children: [
          Positioned(
            top:
                16, // Adjust this value to control how high the white page starts
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:
                      Radius.circular(20), // Rounded corners only at the top
                  topRight: Radius.circular(20),
                ),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: projects,
                builder: (context, snapshot) {
                  print("FutureBuilder State: ${snapshot.connectionState}");

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    print("Waiting for data...");
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    print("Error occurred: ${snapshot.error}");
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    print("No data found.");
                    return Center(
                        child: Text(
                      "Currently, there are no projects available.",
                      style: TextStyle(
                          fontSize: 18,
                          color: const Color.fromARGB(255, 10, 0, 0)),
                    ));
                  }

                  // Display the list of projects
                  final projectList = snapshot.data!;
                  print("Fetched ${projectList.length} projects.");

                  return ListView.builder(
                    padding: EdgeInsets.only(
                        top: 16), // Add padding to avoid overlap
                    itemCount: projectList.length,
                    itemBuilder: (context, index) {
                      final project = projectList[index];
                      print("Project ${index + 1}: ${project['title']}");

                      final deadline = project['endDate'] != null
                          ? (project['endDate'] is DateTime
                              ? DateFormat('yyyy-MM-dd')
                                  .format(project['endDate'])
                              : project['endDate'])
                          : 'No deadline available';

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Color.fromRGBO(
                                24, 71, 137, 1), // Set border color
                            width: 3, // Border width
                          ),
                        ),
                        elevation: 2,
                        margin:
                            EdgeInsets.symmetric(vertical: 6, horizontal: 24),
                        child: Container(
                          color: Colors.grey[
                              200], // Set the background color to light gray
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 10), // Remove vertical padding
                            title: Text(
                              project['name'] ?? 'Untitled',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color.fromRGBO(
                                    24, 71, 137, 1), // Set title color
                                height:
                                    1.5, // Adjust height to add space between lines
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    height:
                                        16), // Add space between project name and deadline
                                RichText(
                                  text: TextSpan(
                                    text: 'Deadline: ',
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: const Color.fromRGBO(238, 100, 90,
                                          1), // 'Deadline' text color to red
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '$deadline',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Colors
                                              .grey, // Deadline value color to gray
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetails(
                                    projectName: project['name'],
                                    description: project['description'],
                                    startDate: project['startDate'].toString(),
                                    deadline: project['endDate'].toString(),
                                    totalAmount:
                                        project['totalAmount'].toString(),
                                    projectType: project['projectType'],
                                    projectCreatorWallet:
                                        project['organization'] ?? '',
                                  ),
                                ),
                              );
                              print("Tapped on project: ${project['name']}");
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
