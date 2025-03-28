import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/web3dart.dart' as web3;


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



Future<List<String>> fetchApprovedCharities() async {
  List<String> walletAddresses = [];

  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus', isEqualTo: 'approved')
        .where('userType', isEqualTo: 1)
        .get();

    snapshot.docs.forEach((doc) {
      walletAddresses.add(doc['walletAddress']);
    });
  } catch (e) {
    print("Error fetching charity wallet addresses: $e");
  }

  return walletAddresses;
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
    // Fetch approved wallet addresses from Firestore
    List<String> approvedWallets = await fetchApprovedCharities();

    // Fetch all organizations from the smart contract
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
    List<dynamic> descriptions = result[6];
    List<dynamic> licenseNumbers = result[7];
    List<dynamic> establishmentDates = result[8];

    List<Map<String, dynamic>> tempOrganizations = [];
    
    for (int i = 0; i < wallets.length; i++) {
      String wallet = wallets[i].toString();

      // Only include charities that are approved in Firestore
      if (approvedWallets.contains(wallet)) {
        tempOrganizations.add({
          "wallet": wallet,
          "name": names[i],
          "email": emails[i],
          "phone": phones[i],
          "city": cities[i],
          "website": websites[i],
          "description": descriptions[i],
          "licenseNumber": licenseNumbers[i],
          "establishmentDate": establishmentDates[i],
        });
      }
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
    resizeToAvoidBottomInset: false, // Prevent UI from resizing when keyboard appears
    backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background matches app bar
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(70), // Increase app bar height
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
  body: SingleChildScrollView( // Wrap the entire body content in SingleChildScrollView
    child: Column(
      children: [
      ClipRRect(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Rounded top corners only
  child: Container(
    color: Colors.white, // Set the background to white
    width: double.infinity, // Make it stretch across the full width
    height: MediaQuery.of(context).size.height, // Make it fill the screen height
    child: Column(
      children: [
        // Search bar at the top
        Padding(
          padding: const EdgeInsets.all(16.0),
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
                        _searchController.clear(); // Clears the text input
                        _onSearchChanged(''); // Reset search filter
                      },
                    )
                  : null,
            ),
            style: TextStyle(color: Colors.black),
          ),
        ),
        // Increased white space under the search bar

        // Loading or organizations list
        isLoading
             ? Expanded(
              
                 child: Center(
                   child: CircularProgressIndicator(),
                 ),
               )
        : _getFilteredOrganizations().isEmpty
            ? Expanded(
                child: const Center(child: Text("No registered charities found.")),
              )
            : Expanded(
              
                child: ListView.builder(
                  
                  shrinkWrap: true, // Prevents infinite scrolling
                  physics: NeverScrollableScrollPhysics(), // Disable scrolling for ListView inside SingleChildScrollView
                  itemCount: _getFilteredOrganizations().length,
                  itemBuilder: (context, index) {
                    var charity = _getFilteredOrganizations()[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // Rounded corners
                        side: BorderSide(
                            color: Color.fromRGBO(24, 71, 137, 1),
                            width: 2),
                      ),
                      color: Color.fromARGB(174, 255, 255, 255),
                      child: ListTile(
                        
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        leading: SizedBox(
                          width: 80, // Increased width
                          height: 60, // Increased height
                          child: CircleAvatar(
                            radius: 40, // Increased avatar size
                            backgroundColor: Colors.transparent,
                            child: Icon(Icons.account_circle,
                                size: 75, color: Colors.grey),
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
                            const SizedBox(height: 6),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 25, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  " ${charity["city"]}",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Icon(Icons.email, size: 25, color: Colors.grey),
                                SizedBox(width: 4),
                                Text(
                                  " ${charity["email"]}",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          // Navigate to Organization Profile Page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  OrganizationProfilePage(organization: charity),
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
)

,
      ],
    ),
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
    body: Stack(
  children: [
    Container(
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
    Positioned(
      top: 16,
      right: 16,
      child: IconButton(
        icon: const Icon(Icons.flag, color: Colors.grey, size: 40), // Increased icon size
        iconSize: 38, // Ensures the button itself is larger
        onPressed: () {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ReportPopup(organization: organization); // Pass organization data
        },
      );
    },
      ),
    ),
  ],
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
  final String orgName;

  ViewProjectsPage({required this.orgAddress, required this.orgName});

  @override
  _ViewProjectsPageState createState() => _ViewProjectsPageState();
}

class _ViewProjectsPageState extends State<ViewProjectsPage> {
  late Future<List<Map<String, dynamic>>> projects;

  @override
  void initState() {
    super.initState();
    projects = BlockchainService().fetchOrganizationProjects(widget.orgAddress);
  }

  String _getProjectState(Map<String, dynamic> project) {
    DateTime now = DateTime.now();

    DateTime startDate = project['startDate'] != null
        ? DateTime.parse(project['startDate'].toString())
        : now;

    DateTime endDate = project['endDate'] != null
        ? DateTime.parse(project['endDate'].toString())
        : now;

    double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming";
    } else if (donatedAmount >= totalAmount && now.isBefore(endDate)) {
      return "completed";
    } else if (now.isAfter(endDate) && donatedAmount < totalAmount) {
      return "failed";
    } else {
      return "active";
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "completed":
        return Colors.blue;
      case "upcoming":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
      appBar: AppBar(
        toolbarHeight: 70,
        title: Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: Text(
            "${widget.orgName}'s Projects",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 30,
          weight: 800,
        ),
        leading: Padding(
          padding: EdgeInsets.only(left: 10, bottom: 1),
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
            top: 16,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: projects,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text(
                            "Currently, there are no projects available."));
                  }

                  final projectList = snapshot.data!;

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: projectList.length,
                    itemBuilder: (context, index) {
                      final project = projectList[index];
                      final projectState = _getProjectState(project);
                      final stateColor = _getStateColor(projectState);
                      final deadline = project['endDate'] != null
                          ? DateFormat('yyyy-MM-dd').format(
                              DateTime.parse(project['endDate'].toString()))
                          : 'No deadline available';
                      final double progress =
                          project['donatedAmount'] / project['totalAmount'];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1), width: 3),
                        ),
                        elevation: 2,
                        margin:
                            EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: ListTile(
                          tileColor: Colors.grey[200],
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          title: Text(
                            project['name'] ?? 'Untitled',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color.fromRGBO(24, 71, 137, 1)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  text: 'Deadline: ',
                                  style: TextStyle(
                                      fontSize: 17,
                                      color: Color.fromRGBO(238, 100, 90, 1)),
                                  children: [
                                    TextSpan(
                                      text: '$deadline',
                                      style: TextStyle(
                                          fontSize: 17, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[200],
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(stateColor),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: stateColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      projectState,
                                      style: TextStyle(
                                          color: stateColor,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
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
                                  totalAmount: project['totalAmount'],
                                  projectType: project['projectType'],
                                  projectCreatorWallet:
                                      project['organization'] ?? '',
                                  donatedAmount: project['donatedAmount'],
                                  projectId: project['id'],
                                  progress: progress,
                                ),
                              ),
                            );
                          },
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







class ReportPopup extends StatefulWidget {
  final Map<String, dynamic> organization;

  const ReportPopup({super.key, required this.organization});

  @override
  _ReportPopupState createState() => _ReportPopupState();
}

class _ReportPopupState extends State<ReportPopup> {
  late String targetCharityAddress; 
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  int titleLength = 0;
  int descriptionLength = 0;
  final int titleMax = 30;
  final int descriptionMax = 300;

  // Flags for validation
  bool isTitleEmpty = false;
  bool isDescriptionEmpty = false;

  @override
  void initState() {
    super.initState();
 // Assign the wallet address from the organization data
    targetCharityAddress = widget.organization["wallet"] ?? "";
    print("Target Charity Address: $targetCharityAddress"); // Debugging print
    titleController.addListener(() {
      setState(() {
        titleLength = titleController.text.length;
        isTitleEmpty = titleController.text.isEmpty;
      });
    });

    descriptionController.addListener(() {
      setState(() {
        descriptionLength = descriptionController.text.length;
        isDescriptionEmpty = descriptionController.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    // Get the address and validate it before passing
    String orgAddress = widget.organization["wallet"] ?? "Unknown";
    print("Organization Wallet Address: $orgAddress");


  return AlertDialog(
    
    backgroundColor: Colors.white,
   title: Stack(
    
  children: [


    Center(
      child: const Text(
        "Report",
        style: TextStyle(
          color: Color.fromRGBO(24, 71, 137, 1),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),

    content: Column(
      mainAxisSize: MainAxisSize.min,
      
      children: [
        SizedBox(height: 20),
        TextField(
          controller: titleController,
          maxLength: titleMax,
          decoration: InputDecoration(
            labelText: "Title*",
            labelStyle: const TextStyle(color: Colors.grey),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            counterText: "$titleLength/$titleMax", // Dynamic counter
            counterStyle: TextStyle(color: titleLength >= titleMax ? Colors.red : Colors.grey),
          ),
        ),
        const SizedBox(height: 1),
        if (isTitleEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 130),
            child: Text(
              "Title is required.",
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: descriptionController,
          maxLength: descriptionMax,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: "Description*",
            labelStyle: const TextStyle(color: Colors.grey),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.only(top: 20, left: 12, right: 12, bottom: 12),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            counterText: "$descriptionLength/$descriptionMax", // Dynamic counter
            counterStyle: TextStyle(color: descriptionLength >= descriptionMax ? Colors.red : Colors.grey),
          ),
        ),
        if (isDescriptionEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 100),
            child: Text(
              "Description is required.",
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    ),
   actions: [
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      OutlinedButton(
        onPressed: () async {
      bool leave = await _showLeaveConfirmationDialog(context);
      if (leave) {
        Navigator.pop(context); // Close the report popup and leave
      }
    },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Color.fromRGBO(24, 71, 137, 1), // Border color
            width: 2.5, // Increase the border width here
          ),
           backgroundColor:  Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20) ), // Rounded border
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Padding
        ),
        child: const Text(
          " Cancel ",
          style: TextStyle(color: Color.fromRGBO(24, 71, 137, 1),  fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      const SizedBox(width: 20),
      ElevatedButton(
        onPressed: () async {
          if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
            setState(() {
              isTitleEmpty = titleController.text.isEmpty;
              isDescriptionEmpty = descriptionController.text.isEmpty;
            });
          } else {
            await _showSendConfirmationDialog(context);
            
               Navigator.pop(context, true);
 showSuccessPopup(context); // Call the popup here
            
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded border
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Padding
        ),
        child: const Text(
          "  Send  ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    ],
  ),
],

  );
}


  Future<bool> _showLeaveConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Confirm Leaving',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to leave without sending the report?',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(212, 63, 63, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(212, 63, 63, 1),
                  ),
                  child: const Text(
                    '   Yes   ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(vertical: 10),
        );
      },
    ) ??
        false;
  }

  Future<bool> _showSendConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Confirm Sending',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to send the report?',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3.5,
                    ),
                    backgroundColor:  Colors.white,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color.fromRGBO(24, 71, 137, 1),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                onPressed: () async {
  // Validate input fields
  if (titleController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
    print("Title or description is empty");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter both title and description')),
    );
    return;
  }

  // Prepare the complaint details
  String title = titleController.text.trim();
  String description = descriptionController.text.trim();
  String targetCharityAddress = widget.organization["wallet"] ?? "";

  print("Submitting complaint...");
  print("Title: $title");
  print("Description: $description");
  print("Target Charity Address: $targetCharityAddress");

  if (targetCharityAddress.isEmpty) {
    print("Error: Charity wallet address is missing!");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Charity wallet address is missing!')),
    );
    return;
  }

  try {
    // Create an instance of ComplaintService
    final complaintService = ComplaintService(
      rpcUrl: 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1' , // Replace securely
      contractAddress: '0xc23C7DCCEFFD3CFBabED29Bd7eE28D75FF7612D4', // Replace securely
    );

    // Call the sendComplaint function and get the transaction hash
    String result = await complaintService.sendComplaint(
      title: title,
      description: description,
      targetCharityAddress: targetCharityAddress,
    );

    // Handle the response
    if (result.startsWith('Error')) {
      print('Failed to send complaint: $result');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send complaint: $result')),
      );
    } else {
      print('Complaint sent successfully. Transaction hash: $result');
      // After the complaint is sent successfully
 
      
      Navigator.pop(context, true);
    }
  } catch (e) {
    print('Exception occurred: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('An error occurred: $e')),
    );
  }
},


                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: const Text(
                    '   Yes   ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(vertical: 10),
        );
      },
    ) ??
        false;
  }
  void showSuccessPopup(BuildContext context) {

  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Complaint send successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  );

  // Automatically dismiss the dialog after 3 seconds
  Future.delayed(const Duration(seconds: 3), () {
    Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
  Navigator.of(context, rootNavigator: true).pop(); 
   });
}



}





class ComplaintService {
  final Web3Client _web3Client;
  final String _contractAddress;
  late final DeployedContract _complaintContract;
  late final ContractFunction _submitComplaint;

  // The ABI as a string (replace with actual ABI content)
  final String _complaintContractABI = '''
  [
    {
      "constant": false,
      "inputs": [
        { "name": "_title", "type": "string" },
        { "name": "_description", "type": "string" },
        { "name": "_targetCharity", "type": "address" }
      ],
      "name": "submitComplaint",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [{ "name": "_complaintId", "type": "uint256" }],
      "name": "viewComplaint",
      "outputs": [
        { "name": "title", "type": "string" },
        { "name": "description", "type": "string" },
        { "name": "complainant", "type": "address" },
        { "name": "targetCharity", "type": "address" },
        { "name": "timestamp", "type": "uint256" },
        { "name": "resolved", "type": "bool" }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  ComplaintService({
    required String rpcUrl, // The rpcUrl passed into the constructor
    required String contractAddress, // Replace with your smart contract address
  })  : _contractAddress = contractAddress,
        _web3Client = Web3Client(rpcUrl, http.Client()) {
    _initializeContract();
  }

  // Initialize the contract and its functions
  void _initializeContract() {
    print('Initializing contract...');
    try {
      _complaintContract = DeployedContract(
        ContractAbi.fromJson(_complaintContractABI, 'ComplaintRegistry'),
        EthereumAddress.fromHex(_contractAddress),
      );
      print('Contract initialized successfully.');
    } catch (e) {
      print('Error initializing contract: $e');
    }
    _submitComplaint = _complaintContract.function('submitComplaint');
    print('Contract function "submitComplaint" initialized.');
  }

  // Method to send a complaint
 Future<String> sendComplaint({
  required String title, 
  required String description,
  required String targetCharityAddress,
}) async {
  print('🛠 Preparing to send complaint...');

  // Load the wallet address and private key from SharedPreferences
  final privateKey = await _loadPrivateKey();
  if (privateKey == null) {
    print('❌ Error: Private key not found!');
    return 'Error: Private key not found!';
  }

  print('✅ Private key successfully loaded: ${privateKey.substring(0, 6)}... (hidden for security)');

  // Fetch the credentials from the private key
  final credentials = EthPrivateKey.fromHex(privateKey);
  print('🔑 Credentials created from private key.');

  // Set up the parameters
  final params = [
    title,
    description,
    EthereumAddress.fromHex(targetCharityAddress),
  ];

  print('📡 Connecting to blockchain...');
  try {
    print('📤 Sending transaction to contract...');

    final transaction = await _web3Client.sendTransaction(
      credentials,
      web3.Transaction.callContract(
        contract: _complaintContract,
        function: _submitComplaint,
        parameters: params,
        maxGas: 1000000, // Increased gas limit
      ),
      chainId: 11155111, // Ensure this is correct (Ethereum Mainnet = 1, Sepolia = 11155111, etc.)
    );

    print('✅ Transaction sent successfully!');
    
    print('🔗 Transaction Hash: $transaction');
    return transaction;
  } catch (e) {
    print('❌ Error sending transaction: $e');
    return 'Error: $e';
  }
}


  // Fetch credentials using the private key from shared preferences
  Future<String?> _loadPrivateKey() async {
    print('Loading private key...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('Error: Wallet address not found.');
        return null;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
        print('✅ Private key $privateKey');
        return privateKey;
      } else {
        print('❌ Private key not found for wallet $walletAddress');
        return null;
      }
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
      return null;
    }
  }

  // Method to load the wallet address from SharedPreferences
  Future<String?> _loadWalletAddress() async {
    print('Loading wallet address...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("Error: Wallet address not found. Please log in again.");
        return null;
      }

      print('Wallet address loaded successfully: $walletAddress');
      return walletAddress;
    } catch (e) {
      print("Error loading wallet address: $e");
      return null;
    }
  }
}
