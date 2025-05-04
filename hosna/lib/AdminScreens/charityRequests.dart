import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For jsonDecode & jsonEncode
import 'package:http/http.dart'; // For Client
import 'package:web3dart/web3dart.dart'; // For Web3
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore

class CharityRequests extends StatefulWidget {
  @override
  _CharityRequestsState createState() => _CharityRequestsState();
}

class _CharityRequestsState extends State<CharityRequests> {
  List<String> pendingWalletAddresses = [];
  Map<String, Map<String, dynamic>> charityDetails = {};
  bool isSidebarVisible = true;
  @override
  void initState() {
    super.initState();
    _loadCharityRequests();
  }

  Future<List<String>> fetchPendingCharities() async {
    List<String> walletAddresses = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountStatus', isEqualTo: 'pending')
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
bool hasLoadedCharityRequests = false;
bool hasNoCharityRequests = false;

  Future<void> _loadCharityRequests() async {
  print("🔄 Fetching pending charity wallet addresses...");

  List<String> walletAddresses = await fetchPendingCharities();

  print("✅ Wallet addresses fetched: $walletAddresses");

  final charityService = CharityService(
    rpcUrl: 'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac',
    contractAddress: '0x25ef93ac312D387fdDeFD62CD852a29328c4B122',
  );

  await charityService.initialize();

  setState(() {
    pendingWalletAddresses = walletAddresses;
    hasLoadedCharityRequests = true;
    hasNoCharityRequests = walletAddresses.isEmpty;
  });

  for (String walletAddress in walletAddresses) {
    print("🔍 Fetching charity details for wallet: $walletAddress");

    var details = await charityService.getCharityDetails(walletAddress);

    if (details != null) {
      print("📄 Details fetched for wallet $walletAddress: $details");

      setState(() {
        charityDetails[walletAddress] = details;
      });

      print("✅ Charity details for wallet $walletAddress added to state.");
    } else {
      print("⚠️ No details found for wallet: $walletAddress");
    }
  }

  print("🎉 Charity request loading complete!");
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(), // Sidebar added
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Charity Requests', // Page title
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(24, 71, 137, 1), // Custom color
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                    onPressed: () {
                      setState(() {
                        isSidebarVisible = !isSidebarVisible;
                      });
                    },
                  ),
                ),
                Expanded(
                  child:  hasLoadedCharityRequests
        ? hasNoCharityRequests
            ? Center(
                child: Text(
                  "No pending charity requests found.",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
            : ListView.builder(
                          padding: EdgeInsets.all(16.0),
                          itemCount: pendingWalletAddresses.length,
                          itemBuilder: (context, index) {
                            String walletAddress =
                                pendingWalletAddresses[index];
                            var details = charityDetails[walletAddress];

                            if (details == null) return SizedBox.shrink();
                            return GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Dialog(
                                      backgroundColor:
                                          Colors.white, // Background color
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            15), // Optional: Rounded corners
                                      ),
                                      child: Container(
                                        width: 800, // Set a fixed square width
                                        height:
                                            800, // Set a fixed square height        padding: EdgeInsets.all(20), // Padding around content
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment
                                              .center, // Center align title
                                          children: [
                                            // Title with Charity Name, Centered
                                            SizedBox(
                                                height:
                                                    35), // Space below title
                                            Text(
                                              details['name'] ?? 'Charity Name',
                                              textAlign: TextAlign
                                                  .center, // Ensure text is centered
                                              style: TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.bold,
                                                color: Color.fromRGBO(
                                                    24, 71, 137, 1),
                                              ),
                                            ),
                                            SizedBox(
                                                height:
                                                    50), // Space below title

                                            // Charity Details (Shifted slightly to the right)
                                            Align(
                                              alignment: Alignment
                                                  .centerLeft, // Align text to left
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                    left:
                                                        30), // Slight right shift
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildDetailRow('Email:',
                                                        details['email']),
                                                    _buildDetailRow('Phone:',
                                                        details['phone']),
                                                    _buildDetailRow(
                                                        'License Number:',
                                                        details[
                                                            'licenseNumber']),
                                                    _buildDetailRow('City:',
                                                        details['city']),
                                                    _buildDetailRow(
                                                        'Website:',
                                                        details['website'] ??
                                                            'N/A'),
                                                    _buildDetailRow(
                                                        'Description:',
                                                        details['description']),
                                                    _buildDetailRow(
                                                        'Establishment Date:',
                                                        details[
                                                            'establishmentDate']),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            SizedBox(
                                                height:
                                                    80), // Space before buttons

                                            // Centered Buttons
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Color.fromARGB(
                                                        255,
                                                        197,
                                                        47,
                                                        36), // Reject button color
                                                    minimumSize: Size(120, 50),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 18,
                                                            horizontal: 22),
                                                    textStyle:
                                                        TextStyle(fontSize: 18),
                                                  ),
                                                  onPressed: () async {
                                                    if (walletAddress != null &&
                                                        walletAddress
                                                            .isNotEmpty) {
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'users') // Collection name: users
                                                            .doc(
                                                                walletAddress) // Document ID: walletAddress
                                                            .update({
                                                          'accountStatus':
                                                              'rejected'
                                                        });

                                                        print(
                                                            'Account status updated successfully.');
                                                      } catch (e) {
                                                        print(
                                                            'Error updating account status: $e');
                                                      }
                                                    }

                                                    showStatusSuccessPopup(
                                                        context);
                                                  },
                                                  child: Text('Reject',
                                                      style: TextStyle(
                                                          color: Colors.white)),
                                                ),
                                                SizedBox(
                                                    width:
                                                        60), // Space between buttons
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: Color.fromARGB(
                                                        255,
                                                        54,
                                                        142,
                                                        57), // Approve button color
                                                    minimumSize: Size(120, 50),
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 18,
                                                            horizontal: 22),
                                                    textStyle:
                                                        TextStyle(fontSize: 18),
                                                  ),
                                                  onPressed: () async {
                                                    if (walletAddress != null &&
                                                        walletAddress
                                                            .isNotEmpty) {
                                                      try {
                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'users') // Collection name: users
                                                            .doc(
                                                                walletAddress) // Document ID: walletAddress
                                                            .update({
                                                          'accountStatus':
                                                              'approved'
                                                        });

                                                        print(
                                                            'Account status updated successfully.');
                                                      } catch (e) {
                                                        print(
                                                            'Error updating account status: $e');
                                                      }
                                                    }

                                                    showStatusSuccessPopup(
                                                        context);
                                                  },
                                                  child: Text('Approve',
                                                      style: TextStyle(
                                                          color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                margin: EdgeInsets.symmetric(
                                    horizontal: 15.0, vertical: 10.0),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20.0,
                                    vertical: 20.0), // Increased padding
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      12.0), // Increased border radius
                                  border: Border.all(
                                    color: Color.fromRGBO(24, 71, 137, 1),
                                    width: 3.0, // Slightly thicker border
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    details['name'] ?? 'No name',
                                    style: TextStyle(
                                      color: Color.fromRGBO(24, 71, 137, 1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20.0, // Larger font size
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ) : Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showStatusSuccessPopup(BuildContext context) {
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding:
              EdgeInsets.all(20), // Add padding around the dialog content
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15), // Rounded corners for a better look
          ),
          content: SizedBox(
            width: 250, // Set a custom width for the dialog
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Ensure the column only takes the required space
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color.fromARGB(255, 54, 142, 57),
                  size: 50, // Bigger icon
                ),
                SizedBox(height: 20), // Add spacing between the icon and text
                Text(
                  'Account status updated successfully!',
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
    });
  }

// Helper function for formatting detail rows
  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8), // Spacing between rows
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromRGBO(24, 71, 137, 1),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'No data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CharityService {
  final String rpcUrl;
  final String contractAddress;
  late final Web3Client _client;
  late final DeployedContract _contract;

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

  CharityService({
    required this.rpcUrl,
    required this.contractAddress,
  }) {
    _client = Web3Client(rpcUrl, Client());
  }

  Future<void> initialize() async {
    try {
      var abi = jsonDecode(abiString);
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), "CharityRegistration"),
        EthereumAddress.fromHex(contractAddress),
      );
    } catch (e) {
      throw Exception("Failed to load contract: $e");
    }
  }

  Future<List<String>> fetchPendingCharities() async {
    List<String> walletAddresses = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountStatus', isEqualTo: 'pending')
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

  Future<Map<String, dynamic>?> getCharityDetails(String walletAddress) async {
    final function = _contract.function('getAllCharities');
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

    for (int i = 0; i < wallets.length; i++) {
      if (wallets[i].toString().toLowerCase() == walletAddress.toLowerCase()) {
        return {
          "wallet": wallets[i].toString(),
          "name": names[i],
          "email": emails[i],
          "phone": phones[i],
          "city": cities[i],
          "website": websites[i],
          "description": descriptions[i],
          "licenseNumber": licenseNumbers[i],
          "establishmentDate": establishmentDates[i],
        };
      }
    }

    return null; // Not found
  }
}
