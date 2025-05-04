import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/ViewComplaintsPage.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:convert';
import 'AdminSidebar.dart';
// Assuming the profile page is here

class AdminBrowseOrganizations extends StatefulWidget {
  const AdminBrowseOrganizations({super.key});

  @override
  _AdminBrowseOrganizationsState createState() =>
      _AdminBrowseOrganizationsState();
}

class _AdminBrowseOrganizationsState extends State<AdminBrowseOrganizations> {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7';

  late Web3Client _client;
  late DeployedContract _contract;
  List<Map<String, dynamic>> organizations = [];
  bool isLoading = true;
  final TextEditingController _searchController =
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
  bool isSidebarVisible = true;

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

      for (var doc in snapshot.docs) {
        walletAddresses.add(doc['walletAddress']);
      }
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

        if (approvedWallets.contains(wallet)) {
          // Fetch profile picture from Firestore
          String? profilePictureUrl;
          try {
            var doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(wallet)
                .get();
            if (doc.exists && doc.data()!.containsKey('profilePicture')) {
              profilePictureUrl = doc['profilePicture'];
            }
          } catch (e) {
            print("Error fetching profile picture for $wallet: $e");
          }

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
            "profilePicture": profilePictureUrl,
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
      body: Container(
        color: Colors.white, // Change this to your desired color
        child: Row(
          children: [
            // Sidebar (Toggleable visibility)
            AdminSidebar(),
            // Main content (Organizations list and search)
            Expanded(
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Browse Organizations', // Page title
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(
                            24, 71, 137, 1), // Customize the color
                      ),
                    ),
                  ),
                  // Toggle button for sidebar visibility
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon:
                          Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                      onPressed: () {
                        setState(() {
                          isSidebarVisible = !isSidebarVisible;
                        });
                      },
                    ),
                  ),
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
                                      color: Color.fromRGBO(24, 71, 137, 1),
                                      width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                  borderSide: BorderSide(
                                      color: Color.fromRGBO(24, 71, 137, 1),
                                      width: 2),
                                ),
                                prefixIcon:
                                    Icon(Icons.search, color: Colors.black),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            color: Colors.black),
                                        onPressed: () {
                                          _searchController
                                              .clear(); // Clears the text input
                                          _onSearchChanged(
                                              ''); // Reset search filter
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
                                      child: Text(
                                          "No registered charities found."))
                                  : Expanded(
                                      child: ListView.builder(
                                        itemCount:
                                            _getFilteredOrganizations().length,
                                        itemBuilder: (context, index) {
                                          var charity =
                                              _getFilteredOrganizations()[
                                                  index];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 10, horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      12), // Rounded corners
                                              side: BorderSide(
                                                  color: Color.fromRGBO(
                                                      24, 71, 137, 1),
                                                  width: 2),
                                            ),
                                            color: Color.fromARGB(
                                                255, 239, 236, 236),
                                            child: ListTile(
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                              leading: SizedBox(
                                                width: 60,
                                                height: 60,
                                                child: ClipOval(
                                                  child: charity[
                                                              "profilePicture"] !=
                                                          null
                                                      ? Image.network(
                                                          charity[
                                                              "profilePicture"],
                                                          fit: BoxFit.cover,
                                                          errorBuilder:
                                                              (context, error,
                                                                  stackTrace) {
                                                            return Icon(
                                                                Icons
                                                                    .account_circle,
                                                                size: 60,
                                                                color: Colors
                                                                    .grey);
                                                          },
                                                        )
                                                      : Icon(
                                                          Icons.account_circle,
                                                          size: 60,
                                                          color: Colors.grey),
                                                ),
                                              ),
                                              title: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    charity["name"],
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                          size: 25,
                                                          color: Colors.grey),
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
                                                          size: 25,
                                                          color: Colors.grey),
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
                                              onTap: () {
                                                // Navigate to Organization Profile Page
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        OrganizationProfile(
                                                            walletAddress:
                                                                charity[
                                                                    "wallet"]),
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
            ),
          ],
        ),
      ),
    );
  }

  // Sidebar item widget
  Widget _buildSidebarItem(
      BuildContext context, String title, VoidCallback onTap,
      {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
    return ListTile(
      title: Center(
        // Center the text
        child: Text(
          title,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }

  // Sidebar button widget
  Widget _buildSidebarButton({
    required String title,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            side: BorderSide(
                color: borderColor, width: 2), // Set border thickness here
            padding: EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(
            title,
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// class OrganizationProfilePage extends StatelessWidget {
//   final Map<String, dynamic> organization;

//   const OrganizationProfilePage({super.key, required this.organization});



//   @override
//   Widget build(BuildContext context) {
//     // Get the address and validate it before passing
//     String orgAddress = organization["wallet"];
//     print("Organization Wallet Address: $orgAddress");
//     return Scaffold(
//       backgroundColor: Colors.white, // Top bar color
//       appBar: PreferredSize(
//         preferredSize: const Size.fromHeight(80), // Increased app bar height
//         child: AppBar(
//           backgroundColor: Colors.white,
//           elevation: 0, // Remove shadow
//           leading: Padding(
//             padding: const EdgeInsets.only(top: 20), // Adjust icon position
//             child: IconButton(
//               icon: const Icon(
//                 Icons.arrow_back,
//                 color: Color.fromRGBO(24, 71, 137, 1),
//                 size: 30, // Adjusted size
//               ),
//               onPressed: () {
//                 Navigator.pop(context); // Navigate back
//               },
//             ),
//           ),
//           flexibleSpace: Padding(
//             padding: const EdgeInsets.only(bottom: 20), // Moves text down
//             child: Align(
//               alignment: Alignment.bottomCenter,
//               child: Text(
//                 organization["name"] ?? "Unknown Organization",
//                 style: const TextStyle(
//                   color: Color.fromRGBO(24, 71, 137, 1),
//                   fontSize: 24, // Increased size
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     body: Stack(
//   children: [
//     Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//       ),
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Center(
//             child: Icon(Icons.account_circle,
//                 size: 120, color: Colors.grey), // Enlarged profile icon
//           ),
//           const SizedBox(height: 40),

//       Padding(
//   padding: const EdgeInsets.only(left: 500.0), // Adjust the value as needed
//   child: Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       _buildSectionTitle(Icons.contact_phone, "Contact Information"),
//       _buildInfoRow(Icons.phone, "Phone", organization["phone"]),
//       _buildInfoRow(Icons.email, "Email", organization["email"]),
//       _buildInfoRow(Icons.location_city, "City", organization["city"]),

//       const SizedBox(height: 16),

//       _buildSectionTitle(Icons.business, "Organization Details"),
//       _buildInfoRow(
//           Icons.badge, "License Number", organization["licenseNumber"]),
//       _buildInfoRow(Icons.public, "Website", organization["website"],
//           isLink: true),
//       _buildInfoRow(Icons.calendar_today, "Established",
//           organization["establishmentDate"]),

//       const SizedBox(height: 16),

//       _buildSectionTitle(Icons.info_outline, "About Us"),
//       _buildInfoRow(
//           Icons.description, "About Us", organization["description"]),
//     ],
//   ),
// )
// ,

//           const Spacer(), // Push button to bottom

//           Center(
//             child: ElevatedButton(
//               onPressed: () {
//                 // Navigate to the View Projects page
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => ViewProjectsPage(
//                       orgAddress: organization["wallet"],
//                       orgName: organization["name"] ??
//                           "Organization", // Pass org name
//                     ),
//                   ),
//                 );
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: const Color.fromRGBO(
//                     24, 71, 137, 1), // Matching theme color
//                 padding: const EdgeInsets.symmetric(
//                     vertical: 16,
//                     horizontal: 100), // Increased padding for a longer button
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//               child: const Text(
//                 "View Projects",
//                 style: TextStyle(
//                   fontSize: 20,
//                   color: Colors.white, // Ensuring text is white
//                 ),
//               ),
//             ),
//           ),

//           const SizedBox(height: 20), // Add spacing at bottom
//         ],
//       ),
//     ),
   
//   ],
// ),
//     );
//   }
//   Widget _buildSectionTitle(IconData icon, String title) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 8),
//       child: Row(
//         children: [
//           // Icon(icon, size: 28, color: Colors.blueGrey),
//           const SizedBox(width: 8),
//           Text(
//             title,
//             style: const TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInfoRow(IconData icon, String label, String? value,
//       {bool isLink = false}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         children: [
//           Icon(icon, size: 26, color: Colors.blueGrey), // Adjusted icon size
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               value ?? "N/A",
//               style: TextStyle(
//                 fontSize: 18, // Increased text size
//                 color: isLink ? Colors.blue : Colors.black87,
//                 decoration:
//                     isLink ? TextDecoration.underline : TextDecoration.none,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class ViewProjectsPage extends StatefulWidget {
//   final String orgAddress;
//   final String orgName;

//   const ViewProjectsPage({super.key, required this.orgAddress, required this.orgName});

//   @override
//   _ViewProjectsPageState createState() => _ViewProjectsPageState();
// }

// class _ViewProjectsPageState extends State<ViewProjectsPage> {
//   late Future<List<Map<String, dynamic>>> projects;

//   @override
//   void initState() {
//     super.initState();
//     projects = BlockchainService().fetchOrganizationProjects(widget.orgAddress);
//   }

//   String _getProjectState(Map<String, dynamic> project) {
//     DateTime now = DateTime.now();

//     DateTime startDate = project['startDate'] != null
//         ? DateTime.parse(project['startDate'].toString())
//         : now;

//     DateTime endDate = project['endDate'] != null
//         ? DateTime.parse(project['endDate'].toString())
//         : now;

//     double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
//     double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

//     if (now.isBefore(startDate)) {
//       return "upcoming";
//     } else if (donatedAmount >= totalAmount && now.isBefore(endDate)) {
//       return "completed";
//     } else if (now.isAfter(endDate) && donatedAmount < totalAmount) {
//       return "failed";
//     } else {
//       return "active";
//     }
//   }

//   Color _getStateColor(String state) {
//     switch (state) {
//       case "active":
//         return Colors.green;
//       case "failed":
//         return Colors.red;
//       case "completed":
//         return Colors.blue;
//       case "upcoming":
//         return Colors.orange;
//       default:
//         return Colors.grey;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color.fromRGBO(24, 71, 137, 1),
//       appBar: AppBar(
//         toolbarHeight: 70,
//         title: Padding(
//           padding: EdgeInsets.only(bottom: 1),
//           child: Text(
//             "${widget.orgName}'s Projects",
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 25,
//             ),
//           ),
//         ),
//         centerTitle: true,
//         backgroundColor: Color.fromRGBO(24, 71, 137, 1),
//         elevation: 0,
//         iconTheme: IconThemeData(
//           color: Colors.white,
//           size: 30,
//           weight: 800,
//         ),
//         leading: Padding(
//           padding: EdgeInsets.only(left: 10, bottom: 1),
//           child: IconButton(
//             icon: Icon(Icons.arrow_back),
//             onPressed: () {
//               Navigator.pop(context);
//             },
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           Positioned(
//             top: 16,
//             left: 0,
//             right: 0,
//             bottom: 0,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   topRight: Radius.circular(20),
//                 ),
//               ),
//               child: FutureBuilder<List<Map<String, dynamic>>>(
//                 future: projects,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.waiting) {
//                     return Center(child: CircularProgressIndicator());
//                   } else if (snapshot.hasError) {
//                     return Center(child: Text("Error: ${snapshot.error}"));
//                   } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//                     return Center(
//                         child: Text(
//                             "Currently, there are no projects available."));
//                   }

//                   final projectList = snapshot.data!;

//                   return ListView.builder(
//                     padding: EdgeInsets.all(16),
//                     itemCount: projectList.length,
//                     itemBuilder: (context, index) {
//                       final project = projectList[index];
//                       final projectState = _getProjectState(project);
//                       final stateColor = _getStateColor(projectState);
//                       final deadline = project['endDate'] != null
//                           ? DateFormat('yyyy-MM-dd').format(
//                               DateTime.parse(project['endDate'].toString()))
//                           : 'No deadline available';
//                       final double progress =
//                           project['donatedAmount'] / project['totalAmount'];

//                       return Card(
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(10),
//                           side: BorderSide(
//                               color: Color.fromRGBO(24, 71, 137, 1), width: 3),
//                         ),
//                         elevation: 2,
//                         margin:
//                             EdgeInsets.symmetric(vertical: 6, horizontal: 16),
//                         child: ListTile(
//                           tileColor: Colors.grey[200],
//                           contentPadding:
//                               EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//                           title: Text(
//                             project['name'] ?? 'Untitled',
//                             style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: 18,
//                                 color: Color.fromRGBO(24, 71, 137, 1)),
//                           ),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               SizedBox(height: 8),
//                               RichText(
//                                 text: TextSpan(
//                                   text: 'Deadline: ',
//                                   style: TextStyle(
//                                       fontSize: 17,
//                                       color: Color.fromRGBO(238, 100, 90, 1)),
//                                   children: [
//                                     TextSpan(
//                                       text: deadline,
//                                       style: TextStyle(
//                                           fontSize: 17, color: Colors.grey),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               SizedBox(height: 8),
//                               LinearProgressIndicator(
//                                 value: progress,
//                                 backgroundColor: Colors.grey[200],
//                                 valueColor:
//                                     AlwaysStoppedAnimation<Color>(stateColor),
//                               ),
//                               SizedBox(height: 8),
//                               Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Text(
//                                     '${(progress * 100).toStringAsFixed(0)}%',
//                                     style: TextStyle(color: Colors.grey[600]),
//                                   ),
//                                   Container(
//                                     padding: EdgeInsets.symmetric(
//                                         horizontal: 8, vertical: 4),
//                                     decoration: BoxDecoration(
//                                       color: stateColor.withOpacity(0.2),
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Text(
//                                       projectState,
//                                       style: TextStyle(
//                                           color: stateColor,
//                                           fontWeight: FontWeight.bold),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                           onTap: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ProjectDetails(
//                                   projectName: project['name'],
//                                   description: project['description'],
//                                   startDate: project['startDate'].toString(),
//                                   deadline: project['endDate'].toString(),
//                                   totalAmount: project['totalAmount'],
//                                   projectType: project['projectType'],
//                                   projectCreatorWallet:
//                                       project['organization'] ?? '',
//                                   donatedAmount: project['donatedAmount'],
//                                   projectId: project['id'],
//                                   progress: progress,
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



