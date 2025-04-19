// flutter run -d chrome --target=lib/AdminScreens/ViewComplaintsPage.dart --debug

import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/ViewDonors.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/Terms&cond.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'AdminSidebar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

// Define your Ethereum RPC and contract details
const String rpcUrl =
    'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
const String contractAddress = '0x89284505E6EbCD2ADADF3d1B5cbc51B3568CcFd1';
const String abi = '''[
  {
    "constant": true,
    "inputs": [],
    "name": "fetchAllComplaints",
    "outputs": [
      { "name": "", "type": "uint256[]" },
      { "name": "", "type": "string[]" },
      { "name": "", "type": "string[]" },
      { "name": "", "type": "address[]" },
      { "name": "", "type": "address[]" },
      { "name": "", "type": "uint256[]" },
      { "name": "", "type": "bool[]" }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{ "name": "_complaintId", "type": "uint256" }],
    "name": "resolveComplaint",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [{ "name": "_complaintId", "type": "uint256" }],
    "name": "deleteComplaint",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]''';

void main() {
  WidgetsFlutterBinding
      .ensureInitialized(); // ✅ التأكد من تهيئة الـ Widgets قبل Firebase
  try {
    Firebase.initializeApp(
      // 🚀 تهيئة Firebase عند بدء التطبيق
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully 🎉");
  } catch (e) {
    print("❌ Error initializing Firebase: $e ");
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(24, 71, 137, 1), // Set primary color
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: const MaterialColor(
            0xFF184787,
            <int, Color>{
              50: Color(0xFFE1E8F3),
              100: Color(0xFFB3C9E1),
              200: Color(0xFF80A8D0),
              300: Color(0xFF4D87BF),
              400: Color(0xFF2668A9),
              500: Color(0xFF184787),
              600: Color(0xFF165F75),
              700: Color(0xFF134D63),
              800: Color(0xFF104A52),
              900: Color(0xFF0D3841),
            },
          ),
        ).copyWith(
          primary: const Color.fromRGBO(24, 71, 137, 1),
          secondary: const Color.fromRGBO(24, 71, 137, 1),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color.fromRGBO(24, 71, 137, 1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
      ),
      home: ViewComplaintsPage(),
    );
  }
}

class ViewComplaintsPage extends StatefulWidget {
  const ViewComplaintsPage({super.key});

  @override
  _ViewComplaintsPageState createState() => _ViewComplaintsPageState();
}

class _ViewComplaintsPageState extends State<ViewComplaintsPage> {
  late Web3Client _web3Client;
  late DeployedContract _contract;
  late ContractFunction _getAllComplaints;
  late ContractFunction _resolveComplaintFunction;
  late ContractFunction _deleteComplaintFunction;
  List<Map<String, dynamic>> _complaints = [];
  bool isSidebarVisible = true;
  final BlockchainService _blockchainService = BlockchainService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Initialize the connection to the Ethereum blockchain

  /// Initialize Ethereum connection
  Future<void> _initialize() async {
    print("🚀 Initializing Web3 client...");
    _web3Client = Web3Client(rpcUrl, http.Client());
    print("✅ Web3 client initialized successfully!");

    print("🔗 Connecting to smart contract at: $contractAddress");
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'ComplaintRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    print("📜 Smart contract loaded successfully!");

    // Initialize contract functions
    _getAllComplaints = _contract.function('fetchAllComplaints');
    _resolveComplaintFunction = _contract.function('resolveComplaint');
    print("✅ Function references obtained!");
    _deleteComplaintFunction = _contract
        .function('deleteComplaint'); // Reference to deleteComplaint function

    print("📡 Fetching complaints from blockchain...");
    await _fetchComplaints();
  }

  Future<void> _resolveComplaint(String complaintDocId) async {
    if (!mounted) return;

    Navigator.pop(context); // Close modal

    try {
      final docRef =
          FirebaseFirestore.instance.collection('reports').doc(complaintDocId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        print('❌ Complaint document does not exist.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint not found.')),
        );
        return;
      }

      print("🔄 Updating complaint status to resolved...");

      await docRef.update({'resolved': true});

      print("✅ Complaint marked as resolved.");
      await _fetchComplaints();
    } catch (e) {
      print('❌ Error updating complaint status in Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve complaint: $e')),
      );
    }
  }

  Future<String> _getUserType(String walletAddress) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        int userType = userDoc['userType'] ?? -1;
        // Return a string representing the type based on userType
        if (userType == 0) {
          return 'donor'; // 0 means donor
        } else {
          return 'organization'; // Other values indicate organization
        }
      }
    } catch (e) {
      print('Error fetching user type: $e');
    }
    return 'organization'; // Default to 'organization' if error occurs
  }

  bool isLoading = true;

  Future<void> _fetchComplaints() async {
    setState(() {
      isLoading = true; // Set loading state to true before fetching
    });

    try {
      print("📡 Fetching complaints from Firestore...");

      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection("reports")
          .orderBy("timestamp", descending: true)
          .get();

      List<Map<String, dynamic>> complaints = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        // Skip if required fields are missing
        if (data['title'] == null ||
            data['description'] == null ||
            data['targetCharityAddress'] == null) {
          print("⚠️ Skipping document ${doc.id} due to missing fields.");
          continue;
        }

        // Fetch user type to determine if it's a donor complaint
        DocumentSnapshot userDoc = await firestore
            .collection("users")
            .doc(data['targetCharityAddress'])
            .get();
        int userType = userDoc.exists ? userDoc.get('userType') : -1;
        bool isDonor = userType == 0;

        // Determine complaint type
        String complaintType =
            (data.containsKey('project_id') && data['project_id'] != null)
                ? 'project'
                : isDonor
                    ? 'donor'
                    : 'other';

        complaints.add({
          'id': doc.id,
          'title': data['title'],
          'description': data['description'],
          'targetCharity': data['targetCharityAddress'],
          'targetDonor': isDonor ? data['targetCharityAddress'] : null,
          'complainant': data['complainant'] ?? 'Unknown',
          'timestamp':
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'resolved': data['resolved'] ?? false,
          'complaintType': complaintType,
          if (complaintType == 'project') 'project_id': data['project_id'],
        });
      }

      // Sort: unresolved first, then newest
      complaints.sort((a, b) {
        int resolvedComparison = (a['resolved'] as bool ? 1 : 0)
            .compareTo(b['resolved'] as bool ? 1 : 0);
        if (resolvedComparison != 0) return resolvedComparison;
        return (b['timestamp'] as DateTime)
            .compareTo(a['timestamp'] as DateTime);
      });

      if (!mounted) return;
      setState(() {
        _complaints = complaints;
        isLoading = false; // Set loading to false after fetching data
      });

      print(
          "🎉 Fetched ${_complaints.length} complaints from Firestore successfully.");
    } catch (e, stackTrace) {
      print("❌ Error fetching complaints from Firestore: $e");
      print("🔍 Stack trace: $stackTrace");

      setState(() {
        _complaints = [
          {
            'title': 'Error',
            'description': 'Unable to fetch complaints at the moment.'
          }
        ];
      });
    }
  }

// Future<void> _fetchComplaints() async {
//   try {
//     print("📡 Fetching complaints from blockchain...");

//     // Fetch data from the contract
//     final result = await _web3Client.call(
//       contract: _contract,
//       function: _getAllComplaints,
//       params: [],
//     );

//     print("🔍 Raw result from blockchain:");
//     print("  ├── Total items: ${result.length}");
//     print("  ├── Data structure: ${result.runtimeType}");
//     print("  ├── Raw data: $result\n");

//     // Ensure the result has the expected length
//     if (result.length != 7) {
//       throw Exception("❌ Unexpected response format from fetchAllComplaints: Expected 7 fields but got ${result.length}");
//     }

//     // Extract values from the result
//     List<BigInt> ids = List<BigInt>.from(result[0]);
//     List<String> titles = List<String>.from(result[1]);
//     List<String> descriptions = List<String>.from(result[2]);
//     List<EthereumAddress> complainants = List<EthereumAddress>.from(result[3]);
//     List<EthereumAddress> targetCharities = List<EthereumAddress>.from(result[4]);
//     List<BigInt> timestamps = List<BigInt>.from(result[5]);
//     List<bool> resolvedStatuses = List<bool>.from(result[6]);

//     print("✅ Successfully extracted complaint data.");
//     print("  ├── IDs count: ${ids.length}");
//     print("  ├── Titles count: ${titles.length}");
//     print("  ├── Descriptions count: ${descriptions.length}");
//     print("  ├── Complainants count: ${complainants.length}");
//     print("  ├── Target Charities count: ${targetCharities.length}");
//     print("  ├── Timestamps count: ${timestamps.length}");
//     print("  ├── Resolved statuses count: ${resolvedStatuses.length}");

//     // Check for mismatched lengths
//     int expectedLength = ids.length;
//     if ([titles, descriptions, complainants, targetCharities, timestamps, resolvedStatuses]
//         .any((list) => list.length != expectedLength)) {
//       throw Exception("❌ Data inconsistency detected! Arrays have mismatched lengths.");
//     }

//     // Initialize the Firebase Firestore reference to fetch userType
//     final firestore = FirebaseFirestore.instance;

//     // Convert the extracted data into a list of maps, filtering out invalid complaints
//     List<Map<String, dynamic>> complaints = [];
//     for (int i = 0; i < expectedLength; i++) {
//       // Validate complaint data
//       if (ids[i] == BigInt.zero || titles[i].trim().isEmpty || descriptions[i].trim().isEmpty) {
//         print("⚠️ Skipping complaint #$i due to invalid or missing data.");
//         continue;
//       }

//       print("\n📌 Processing complaint #$i");
//       print("  ├── ID: ${ids[i]}");
//       print("  ├── Title: ${titles[i]}");
//       print("  ├── Description: ${descriptions[i]}");
//       print("  ├── Complainant: ${complainants[i].hex}");
//       print("  ├── Target Charity: ${targetCharities[i].hex}");
//       print("  ├── Timestamp (Raw BigInt): ${timestamps[i]}");
//       print("  ├── Timestamp (Converted): ${DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000)}");
//       print("  ├── Resolved: ${resolvedStatuses[i]}\n");

//       // Fetch userType from Firestore based on the wallet address (targetCharity)
//       DocumentSnapshot userDoc = await firestore.collection("users").doc(targetCharities[i].hex).get();

//       // Check if the userType exists and get it (default to -1 if not found)
//       int userType = userDoc.exists ? userDoc.get('userType') : -1;  // Default to -1 if not found

//       // Determine if it's a donor-related complaint
//       bool isDonorComplaint = (userType == 0); // 0 is for donor

//       complaints.add({
//         'id': ids[i].toInt(),
//         'title': titles[i],
//         'description': descriptions[i],
//         'complainant': complainants[i].hex,
//         'targetCharity': targetCharities[i].hex,
//         'targetDonor': isDonorComplaint ? targetCharities[i].hex : null, // Add targetDonor if it's a donor-related complaint
//         'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000),
//         'resolved': resolvedStatuses[i],
//       });
//     }

//     // Sort complaints by timestamp (newest first)
//     complaints.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

//     // Ensure the widget is still mounted before calling setState
//     if (!mounted) return;

//     // Update UI state
//     setState(() {
//       _complaints = complaints;
//     });

//     print("🎉 All valid complaints processed successfully! Total complaints: ${_complaints.length}");

//   } catch (e, stackTrace) {
//     print("❌ Error fetching complaints: $e");
//     print("🔍 Stack trace: $stackTrace");

//     setState(() {
//       _complaints = [
//         {'title': 'Error', 'description': 'Unable to fetch complaints at the moment.'}
//       ];
//     });
//   }
// }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Change this to your desired color
        child: Row(
          children: [
            // Sidebar (Toggleable visibility)
            AdminSidebar(), // Include the reusable sidebar
            // Main content (Complaints page)
            Expanded(
              child: Column(
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Complaints ', // Page title
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

                  // Complaint List
                  Expanded(
                    child: isLoading
                        ? Center(
                            child:
                                CircularProgressIndicator()) // Show loading while fetching data
                        : _complaints.isEmpty
                            ? Center(
                                child: Text(
                                  'No complaints available at the moment.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: _complaints.length,
                                itemBuilder: (context, index) {
                                  final complaint = _complaints[index];

                                  // Check if title or description is empty
                                  if (complaint['title'] == null ||
                                      complaint['title'].trim().isEmpty ||
                                      complaint['description'] == null ||
                                      complaint['description'].trim().isEmpty) {
                                    return SizedBox
                                        .shrink(); // Don't render the complaint if it's invalid
                                  }

                                  return GestureDetector(
                                    onTap: () => _showComplaintDetails(
                                        complaint), // Show details on tap
                                    child: Card(
                                      margin: EdgeInsets.all(10),
                                      elevation: 5,
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(
                                            color:
                                                Color.fromRGBO(24, 71, 137, 1),
                                            width: 2), // Custom blue border
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      color: Colors
                                          .grey[200], // Light grey background
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment
                                              .spaceBetween, // Pushes text left & icon right
                                          children: [
                                            Expanded(
                                              // Ensures text doesn't overflow
                                              child: Text(
                                                complaint['title'],
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color.fromRGBO(
                                                      24, 71, 137, 1),
                                                ),
                                              ),
                                            ),
                                            if (complaint['resolved'] ==
                                                true) // Show checkmark if resolved
                                              Icon(Icons.check_circle,
                                                  color: Color.fromARGB(
                                                      255, 54, 142, 57),
                                                  size: 24),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
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

  void _showComplaintDetails(Map<String, dynamic> complaint) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 600,
              height: 600,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        complaint['title'],
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(24, 71, 137, 1)),
                      ),
                    ),
                    SizedBox(height: 50),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Complaint Details: ${complaint['description']}',
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Color.fromRGBO(24, 71, 137, 1))),
                            SizedBox(height: 30),
                            GestureDetector(
                              onTap: () async {
                                String complainantAddress =
                                    complaint['complainant'];

                                // Fetch user type for the complainant address
                                String userType =
                                    await _getUserType(complainantAddress);

                                // Navigate based on the userType
                                if (userType == 'donor') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DonorDetailsPage(
                                          walletAddress: complainantAddress),
                                    ),
                                  );
                                  print(
                                      'Navigating to Donor Details for: $complainantAddress');
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrganizationProfile(
                                          walletAddress: complainantAddress),
                                    ),
                                  );
                                  print(
                                      'Navigating to Organization Profile for: $complainantAddress');
                                }
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Complainant: ',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Color.fromRGBO(24, 71, 137, 1),
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: 'View profile',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Color.fromRGBO(14, 101, 240, 1),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 30),
                            GestureDetector(
                              onTap: () async {
                                // Fetch the target address based on the complaint data
                                String targetAddress =
                                    complaint['targetDonor'] ??
                                        complaint['targetCharity'];

                                // Fetch user type for the target address (donor or organization)
                                String userType =
                                    await _getUserType(targetAddress);

                                // Navigate based on the userType
                                if (userType == 'donor') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DonorDetailsPage(
                                          walletAddress:
                                              complaint['targetDonor']),
                                    ),
                                  );
                                  print(
                                      'Navigating to Donor Details for: ${complaint['targetDonor']}');
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OrganizationProfile(
                                          walletAddress:
                                              complaint['targetCharity']),
                                    ),
                                  );
                                  print(
                                      'Navigating to Organization Profile for: ${complaint['targetCharity']}');
                                }
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'Target profile :  ',
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Color.fromRGBO(24, 71, 137, 1),
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text: 'View profile',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Color.fromRGBO(14, 101, 240, 1),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (complaint['complaintType'] == 'project')
                              SizedBox(height: 30),
                            if (complaint['complaintType'] == 'project')
                              GestureDetector(
                                onTap: () async {
                                  Map<String, dynamic> projectDetails =
                                      await _blockchainService
                                          .getProjectDetails(
                                              complaint['project_id']);

                                  if (!projectDetails.containsKey('error')) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProjectDetails(
                                          projectName: projectDetails['name'],
                                          description:
                                              projectDetails['description'],
                                          startDate: projectDetails['startDate']
                                              .toString()
                                              .split(' ')[0],
                                          deadline: projectDetails['endDate']
                                              .toString()
                                              .split(' ')[0],
                                          totalAmount:
                                              projectDetails['totalAmount'],
                                          projectType:
                                              projectDetails['projectType'],
                                          projectCreatorWallet:
                                              projectDetails['organization'],
                                          donatedAmount:
                                              projectDetails['donatedAmount'],
                                          projectId: projectDetails['id'],
                                          progress:
                                              (projectDetails['donatedAmount'] /
                                                      projectDetails[
                                                          'totalAmount']) *
                                                  100,
                                        ),
                                      ),
                                    );
                                  } else {
                                    print(
                                        'Error fetching project details: ${projectDetails['error']}');
                                    // Optional: Show error to user
                                  }
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: 'project: ',
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Color.fromRGBO(24, 71, 137, 1),
                                    ),
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: 'View project',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color:
                                              Color.fromRGBO(14, 101, 240, 1),
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: 40),
                            Text(
                              'Date: ${_formatDate(complaint['timestamp'])}',
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Color.fromRGBO(24, 71, 137, 1)),
                            ),
                            SizedBox(height: 30),
                            Row(
                              children: [
                                Icon(
                                  complaint['resolved']
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: complaint['resolved']
                                      ? Color.fromARGB(255, 54, 142, 57)
                                      : Color.fromARGB(255, 197, 47, 36),
                                  size: 32,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  complaint['resolved']
                                      ? 'Resolved'
                                      : 'Unresolved',
                                  style: TextStyle(
                                      fontSize: 20,
                                      color: Color.fromRGBO(24, 71, 137, 1)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 54, 142, 57),
                            minimumSize: Size(120, 50),
                            padding: EdgeInsets.symmetric(
                                vertical: 18, horizontal: 22),
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: complaint['resolved'] == true
                              ? null // Disable the button if resolved is true
                              : () {
                                  _resolveComplaint(complaint['id']).then((_) {
                                    Navigator.pop(
                                        context); // Go back to the previous page
                                  });
                                },
                          child: Text(
                            complaint['resolved'] == true
                                ? 'Resolved'
                                : 'Resolve',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromARGB(255, 197, 47, 36),
                            minimumSize: Size(120, 50),
                            padding: EdgeInsets.symmetric(
                                vertical: 18, horizontal: 22),
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: () async {
                            bool shouldDelete =
                                await _showDeleteConfirmationDialog(context);
                            if (shouldDelete) {
                              await _deleteComplaint(complaint['id']);
                              Navigator.pop(
                                  context); // Go back to the previous page
                              showSuccessPopup(context);
                            }
                          },
                          child: Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is DateTime) {
      return timestamp.toLocal().toString().split(' ')[0];
    } else if (timestamp != null) {
      return DateTime.parse(timestamp).toLocal().toString().split(' ')[0];
    }
    return 'N/A';
  }

  Future<void> _deleteComplaint(String complaintDocId) async {
    if (!mounted) return;

    try {
      print("🗑️ Deleting complaint from Firestore...");

      // Deleting the complaint from Firestore
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(complaintDocId)
          .delete();

      print("✅ Complaint deleted successfully!");

      // Fetch updated complaints to reflect changes
      await _fetchComplaints();
    } catch (e) {
      print('❌ Error deleting complaint: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete complaint: $e')),
      );
    }
  }

// Future<void> _deleteComplaint(int complaintId) async {
//   if (!mounted) return;

//   try {
//     // Credentials for the sender (private key)
//     var credentials = await _web3Client.credentialsFromPrivateKey(
//       '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'
//     );

//     print("🗑️ Deleting complaint...");

//     // Sending the transaction to delete the complaint
//     var transaction = await _web3Client.sendTransaction(
//       credentials,
//       web3.Transaction.callContract(
//         contract: _contract,
//         function: _deleteComplaintFunction,
//         parameters: [BigInt.from(complaintId)],
//         gasPrice: EtherAmount.inWei(BigInt.from(5000000000)), // Set an appropriate gas price
//         maxGas: 200000, // Set the max gas limit (you might need to adjust this)
//       ),
//       chainId: 11155111, // Sepolia testnet
//     );

//     // Confirming the transaction receipt
//     var receipt = await _web3Client.getTransactionReceipt(transaction);
//     if (receipt == null) {
//       print('❌ Transaction failed or is pending. Please check the transaction status.');
//       return;
//     }

//     // Check if the transaction was successful (receipt status 1 means success)
//     if (receipt.status == 1) {
//       print("✅ Complaint deleted successfully!");

//       // Fetch updated complaints to reflect changes
//       await _fetchComplaints();
//     } else {
//       print('❌ Deletion failed. Transaction receipt status: ${receipt.status}');
//     }
//   } catch (e) {
//     print('❌ Error deleting complaint: $e');
//   }
// }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    print("🚀 Showing delete confirmation dialog...");

    return await showDialog<bool>(
          context: context,
          barrierDismissible:
              false, // Prevent dismissing the dialog by tapping outside
          builder: (BuildContext context) {
            print("🔧 Building the dialog...");

            return AlertDialog(
              backgroundColor: Colors.white, // Set background to white
              title: const Text(
                'Confirm Deletion',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Make title bold
                  fontSize: 22, // Increase title font size
                ),
                textAlign: TextAlign.center, // Center the title text
              ),
              content: const Text(
                'Are you sure you want to delete this complaint ?',
                style: TextStyle(
                  fontSize: 18, // Make content text bigger
                ),
                textAlign: TextAlign.center, // Center the content text
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the buttons
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        print("❌ Cancel clicked - Deletion not confirmed.");
                        Navigator.pop(context, false); // Return false on cancel
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              24, 71, 137, 1), // Border color for Cancel button
                          width: 3,
                        ),
                        backgroundColor: Color.fromRGBO(24, 71, 137,
                            1), // Background color for Cancel button
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color: Colors
                              .white, // White text color for Cancel button
                        ),
                      ),
                    ),
                    const SizedBox(width: 20), // Add space between the buttons
                    OutlinedButton(
                      onPressed: () {
                        print("✅ Yes clicked - Deletion confirmed.");
                        Navigator.pop(context,
                            true); // Return true after confirming deletion
                        // If you want to navigate back to the previous page or perform additional actions:
                        // Navigator.pop(context); // This line is for returning to the previous page, if needed
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              212, 63, 63, 1), // Border color for Yes button
                          width: 3,
                        ),
                        backgroundColor: Color.fromRGBO(
                            212, 63, 63, 1), // Background color for Yes button
                      ),
                      child: const Text(
                        '   Yes   ',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color:
                              Colors.white, // White text color for Yes button
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.symmetric(
                  vertical: 10), // Add padding for the actions
            );
          },
        ) ??
        false; // If null, default to false
  }

  void showSuccessPopup(BuildContext context) {
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: true, // allow closing the dialog by tapping outside
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
                  'Complaint deleted Successfully!',
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
}

class OrganizationProfile extends StatefulWidget {
  final String walletAddress; // Pass the wallet address as a string

  const OrganizationProfile({super.key, required this.walletAddress});

  @override
  _OrganizationProfileState createState() => _OrganizationProfileState();
}

class _OrganizationProfileState extends State<OrganizationProfile> {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7';

  late Web3Client _client;
  late DeployedContract _contract;
  Map<String, dynamic>? organizationData; // Hold fetched data
  bool isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _client = Web3Client(rpcUrl, http.Client());
    _loadContract();
  }

  Future<void> _loadContract() async {
    try {
      var abi = jsonDecode(abiString);
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), "CharityRegistration"),
        EthereumAddress.fromHex(contractAddress),
      );
      await _fetchOrganizationData();
    } catch (e) {
      print("Error loading contract: $e");
    }
  }

  Future<void> _fetchOrganizationData() async {
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
      List<dynamic> descriptions = result[6];
      List<dynamic> licenseNumbers = result[7];
      List<dynamic> establishmentDates = result[8];

      // Search for the organization using the wallet address
      int index =
          wallets.indexOf(EthereumAddress.fromHex(widget.walletAddress));
      if (index != -1) {
        setState(() {
          organizationData = {
            "wallet": wallets[index].toString(),
            "name": names[index],
            "email": emails[index],
            "phone": phones[index],
            "city": cities[index],
            "website": websites[index],
            "description": descriptions[index],
            "licenseNumber": licenseNumbers[index],
            "establishmentDate": establishmentDates[index],
          };
          isLoading = false;
        });
      } else {
        print("Organization not found");
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching organization data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color.fromARGB(255, 246, 246, 246),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          // backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Color.fromRGBO(24, 71, 137, 1),
                size: 30,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                organizationData?["name"] ?? "Unknown Organization",
                style: const TextStyle(
                  color: Color.fromRGBO(24, 71, 137, 1),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment
                          .center, // Centering content vertically
                      crossAxisAlignment: CrossAxisAlignment
                          .center, // Centering content horizontally
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 100, bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ViewProjectsPage(
                                        orgAddress: organizationData?["wallet"],
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      "View All Organization Projects",
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Color.fromRGBO(24, 71, 137, 1),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward,
                                        size: 30,
                                        color: Color.fromRGBO(24, 71, 137, 1)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.account_circle,
                          size: 120,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(
                        0), // Adjust the overall padding here
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(width: 200),
                        // Left Side - Contact Information & About Us
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                right:
                                    120), // Space between the left and right sections
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 40),
                                _buildSectionTitle(
                                    Icons.contact_phone, "Contact Information"),
                                _buildStyledInfoRow(Icons.phone, "Phone: ",
                                    organizationData?["phone"]),
                                _buildStyledInfoRow(Icons.email, "Email: ",
                                    organizationData?["email"]),
                                _buildStyledInfoRow(Icons.location_on, "City: ",
                                    organizationData?["city"]),
                                const SizedBox(height: 16),
                                _buildSectionTitle(
                                    Icons.info_outline, "About Us"),
                                _buildStyleddescRow(Icons.description, "",
                                    organizationData?["description"]),
                              ],
                              
                            ),
                            
                          ),
                        ),

                        // Right Side - Organization Details
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 150.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                    Icons.business, "Organization Details"),
                                _buildStyledInfoRow(
                                    Icons.badge,
                                    "License No.: ",
                                    organizationData?["licenseNumber"]),
                                _buildStyledInfoRow(Icons.explore, "Website: ",
                                    organizationData?["website"]
                                    ),
                                _buildStyledInfoRow(
                                    Icons.calendar_today,
                                    "Established date: ",
                                    organizationData?["establishmentDate"]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ElevatedButton(
                        //   onPressed: () {
                        //     Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //         builder: (context) => ViewProjectsPage(
                        //           orgAddress: widget.walletAddress,
                        //           orgName: organizationData?["name"] ?? "Organization",
                        //         ),
                        //       ),
                        //     );
                        //   },
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                        //     padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 100),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        //   child: const Text(
                        //     "View Projects",
                        //     style: TextStyle(fontSize: 20, color: Colors.white),
                        //   ),
                        // ),

                        ElevatedButton(
                          onPressed: () async {
                            // Show the confirmation dialog
                            bool isConfirmed = await _showSuspendConfirmationDialog(context);

                            if (isConfirmed) {
                              // The suspension logic is now handled in _showSuspendConfirmationDialog
                              // Just show the success popup
                              showSuspendSuccessPopup(context);

                              // Show a SnackBar for quick feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Account has been suspended successfully."),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );

                              print("✅ Account suspended successfully!");
                            } else {
                              print("❌ Suspension cancelled by user.");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 80),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Suspend Account",
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),

                        const SizedBox(width: 180),
                        ElevatedButton(
                          onPressed: () async {
                            bool confirmed =
                                await _showcancelConfirmationDialog(context);

                            if (confirmed) {
                              // final helper = CancelAllProjectsHelper();
                              // await helper.cancelAllProjectsForOrganization(
                              //     widget.walletAddress);

                               // The cancellation logic is now handled in the dialog's then() callback

                              // Just update the user's suspend status and show success popup
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(widget.walletAddress)
                                  .update({'isSuspend': true});

                              showCancelSuccessPopup(context);
                            } else {
                              print("User canceled the mass cancelation.");
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            "Suspend & Cancel Projects",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

// Function to show success popup after project cancellation
  void showCancelSuccessPopup(BuildContext context) {
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
                  'Account suspended & All Projects cancelled successfully!',
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
    ).then((value) {
      // Close the dialog after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        Navigator.of(context, rootNavigator: true).pop();
      });
    });
  }

// Function to show confirmation dialog before cancellation
  Future<bool> _showcancelConfirmationDialog(BuildContext context) async {
    // Create a TextEditingController for the justification field

    final justificationController = TextEditingController();

    String justification = "Admin initiated cancellation"; // Default value
    return await showDialog<bool>(
          context: context,
          barrierDismissible:
              false, // Prevent dismissing the dialog by tapping outside
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white, // Set background to white
              title: const Text(
                'Confirm Cancelation',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Make title bold
                  fontSize: 22, // Increase title font size
                ),
                textAlign: TextAlign.center, // Center the title text
              ),
              content: SingleChildScrollView(

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    const Text(

                      'Are you sure you want to suspend this account and cancel all projects?',

                      style: TextStyle(

                        fontSize: 18, // Make content text bigger

                      ),

                      textAlign: TextAlign.center, // Center the content text

                    ),

                    const SizedBox(height: 20),

                    const Text(

                      'Please provide a justification:',

                      style: TextStyle(

                        fontSize: 16,

                        fontWeight: FontWeight.bold,

                      ),

                      textAlign: TextAlign.left,

                    ),

                    const SizedBox(height: 10),

                    TextField(

                      controller: justificationController,

                      maxLines: 3,

                      decoration: InputDecoration(

                        hintText: 'Enter reason for cancellation...',

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(8),

                        ),

                        filled: true,

                        fillColor: Colors.grey[100],

                      ),

                      onChanged: (value) {

                        if (value.trim().isNotEmpty) {

                          justification = value;

                        }

                      },

                    ),

                  ],
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the buttons
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context, false); // Return false on cancel
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              24, 71, 137, 1), // Border color for Cancel button
                          width: 3,
                        ),
                        backgroundColor:
                            Color.fromRGBO(24, 71, 137, 1), // Background color
                      ),
                      child: const Text(
                        '  No  ',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color: Colors.white, // White text color
                        ),
                      ),
                    ),
                    const SizedBox(width: 20), // Add space between buttons
                    OutlinedButton(
                      onPressed: () {
                        // Validate if justification is provided

                        if (justificationController.text.trim().isEmpty) {

                          ScaffoldMessenger.of(context).showSnackBar(

                            const SnackBar(

                              content: Text('Please provide a justification for cancellation.'),

                              backgroundColor: Colors.red,

                            ),

                          );

                        } else {

                          // Store the justification in a global variable or a provider

                          justification = justificationController.text.trim();

                          Navigator.pop(context, true); // Return true with justification

                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: const Color.fromARGB(
                              255, 182, 12, 12), // Border color for Save button
                          width: 3,
                        ),
                        backgroundColor: const Color.fromARGB(
                            255, 182, 12, 12), // Background color
                      ),
                      child: const Text(
                        '  Yes  ',
                        style: TextStyle(
                          fontSize: 20, // Increase font size
                          color: Colors.white, // White text color
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.symmetric(
                  vertical: 10), // Add padding for the actions
            );
          },
        ).then((confirmed) {

          if (confirmed == true) {

            // Pass the justification to the cancellation helper

            final helper = CancelAllProjectsHelper();

            helper.cancelAllProjectsForOrganization(widget.walletAddress, justification);

            return true;

          }

          return false;

        });
  }

  Future<bool> _showSuspendConfirmationDialog(BuildContext context) async {
    print("🚀 Showing suspend confirmation dialog...");
    
    // Create a TextEditingController for the justification field
    final justificationController = TextEditingController();
    String justification = "Account suspended by admin"; // Default value
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Confirm Account Suspension',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Are you sure you want to suspend this charity account?',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please provide a justification:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: justificationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter reason for account suspension...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    if (value.trim().isNotEmpty) {
                      justification = value;
                    }
                  },
                ),
              ],
            ),
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
                    '  No  ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: () {
                    // Validate if justification is provided
                    if (justificationController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please provide a justification for suspension.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      // Store the justification
                      justification = justificationController.text.trim();
                      Navigator.pop(context, true);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color.fromARGB(255, 182, 12, 12),
                      width: 3,
                    ),
                    backgroundColor: const Color.fromARGB(255, 182, 12, 12),
                  ),
                  child: const Text(
                    '  Yes  ',
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
    ).then((confirmed) {
      if (confirmed == true) {
        // Suspend account and send notification
        _suspendAccountWithJustification(widget.walletAddress, justification);
        return true;
      }
      return false;
    });
  }

  Future<void> _suspendAccountWithJustification(String walletAddress, String justification) async {
    try {
      // Update the account in Firestore with suspension status and reason
      await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .update({
            'isSuspend': true,
            'suspensionReason': justification,
            'suspendedAt': FieldValue.serverTimestamp(),
            'suspendedBy': 'admin'
          });
      
      // Fetch organization information to use in notification
      final orgDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();
      
      if (orgDoc.exists) {
        final orgData = orgDoc.data();
        final orgName = orgData?['name'] ?? 'Unknown Organization';
        
        // Send notification to the suspended charity
        await _sendSuspensionNotification(
          walletAddress,
          orgName,
          justification
        );
      }
      
      print("✅ Account suspended successfully with justification: $justification");
    } catch (e) {
      print("❌ Error suspending account: $e");
    }
  }
  
  Future<void> _sendSuspensionNotification(String charityAddress, String orgName, String justification) async {
    try {
      // Create a unique notification ID
      final notificationId = 'account_suspended_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create notification in Firestore
      await FirebaseFirestore.instance
          .collection('charity_notifications')
          .doc(notificationId)
          .set({
            'charityAddress': charityAddress,
            'orgName': orgName,
            'message': 'Your charity account has been suspended by an admin. Reason: $justification',
            'type': 'account_suspension',
            'status': 'suspended',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'suspensionReason': justification,
          });
          
      print("✅ Suspension notification sent to charity: $charityAddress");
    } catch (e) {
      print("❌ Error sending suspension notification: $e");
    }
  }

  void showSuspendSuccessPopup(BuildContext context) {
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
                  'Account suspended successfully!',
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
Widget _buildStyleddescRow(IconData icon, String label, String? value) {
 return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
  children: [
    Icon(Icons.description, color: Colors.grey),
    SizedBox(width: 10),
    Expanded( // Use Expanded to allow wrapping text
      child: Text(
        organizationData?["description"] ?? "No description available",
        style: TextStyle(fontSize: 16, color: Colors.black),
        softWrap: true, // Ensures text wraps to the next line if needed
        overflow: TextOverflow.visible, // Prevents clipping
        maxLines: null, // Remove the limit on lines to let the text wrap freely
      ),
    ),
  ],
)




  );
}

// Custom styled info row to ensure consistency
  Widget _buildStyledInfoRow(IconData icon, String label, String? value,
      {bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (isLink)
                  GestureDetector(
                    onTap: () {
                      // Handle the website link tap
                      // launchUrl(Uri.parse(value ?? ""));
                    },
                    child: Text(
                      value ?? "N/A",
                      style: TextStyle(color: Colors.blue, fontSize: 16),
                    ),
                  )
                else
                  Text(
                    value ?? "N/A",
                    style: TextStyle(fontSize: 16),
                  ),
              ],
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
          Icon(icon, size: 26, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ?? "N/A",
              style: TextStyle(
                fontSize: 18,
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

class DonorDetailsPage extends StatelessWidget {
  final String walletAddress;

  const DonorDetailsPage({super.key, required this.walletAddress});

  final String donorContractAddress =
      '0x8a69415dcb679d808296bdb51dFcb01A4Cd2Bb79';

  final String donorAbi = '''
  [
    {
      "constant": true,
      "inputs": [{"name": "_wallet", "type": "address"}],
      "name": "getDonor",
      "outputs": [
        {"name": "", "type": "string"},
        {"name": "", "type": "string"},
        {"name": "", "type": "string"},
        {"name": "", "type": "string"},
        {"name": "", "type": "address"},
        {"name": "", "type": "bool"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  Future<Map<String, dynamic>?> fetchDonorDetails() async {
    try {
      final client = Web3Client(
        "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1",
        http.Client(),
      );

      final contract = DeployedContract(
        ContractAbi.fromJson(donorAbi, 'DonorContract'),
        EthereumAddress.fromHex(donorContractAddress),
      );

      final getDonorFunction = contract.function('getDonor');
      final result = await client.call(
        contract: contract,
        function: getDonorFunction,
        params: [EthereumAddress.fromHex(walletAddress)],
      );

      final firstName = result[0] as String;
      final lastName = result[1] as String;
      final email = result[2] as String;
      final phone = result[3] as String;

      final profilePicture = await _fetchProfilePicture(walletAddress);

      return {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'profile_picture': profilePicture,
      };
    } catch (e) {
      print('Error fetching donor from contract: $e');
      return null;
    }
  }

  Future<String?> _fetchProfilePicture(String walletAddress) async {
    try {
      print('Fetching profile picture for wallet address: $walletAddress');

      // Fetching user document from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      // Ensure the document exists and contains data
      if (userDoc.exists) {
        print('User document found.');

        var data = userDoc.data() as Map<String, dynamic>?;

        if (data != null) {
          print('User data fetched successfully: $data');

          // Check if the profile_picture field exists
          if (data['profile_picture'] != null) {
            print('Profile picture URL found: ${data['profile_picture']}');
            return data['profile_picture'];
          } else {
            print('Profile picture field is missing or null.');
          }
        } else {
          print('No data available in the user document.');
        }
      } else {
        print('User document not found for wallet address: $walletAddress');
      }
    } catch (e) {
      print('Error fetching profile picture for $walletAddress: $e');
    }
    return null; // Return null if no profile picture is found
  }
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchDonorDetails(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('An error occurred: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            body: Center(child: Text('Donor not found')),
          );
        }

        final donor = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 2,
            centerTitle: true,
            leading: IconButton(
              icon:
                  Icon(Icons.arrow_back, color: Color.fromRGBO(24, 71, 137, 1)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              "${donor['firstName']}'s Profile",
              style: TextStyle(
                color: Color.fromRGBO(24, 71, 137, 1),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  width: 120,
                  child: donor['profile_picture'] != null
                      ? ClipOval(
                          child: Image.network(
                            donor['profile_picture'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.person,
                                    size: 60, color: Colors.white),
                              );
                            },
                          ),
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          child:
                              Icon(Icons.person, size: 60, color: Colors.white),
                        ),
                ),
                SizedBox(height: 65),
                ProfileItem(
                    title: "Name",
                    value: "${donor['firstName']} ${donor['lastName']}"),
                Divider(),
                ProfileItem(title: "Email", value: donor['email']),
                Divider(),
                ProfileItem(title: "Phone", value: donor['phone']),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ViewProjectsPage extends StatefulWidget {
  final String orgAddress;

  const ViewProjectsPage({super.key, required this.orgAddress});

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

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();

    String projectId = project['id'].toString(); // Ensure it's a String
    bool isCanceled =
        await _isProjectCanceled(projectId); // Await the async call

    if (isCanceled) {
      print("This project is canceled.");
      return "canceled";
    } else {
      print("This project is active.");
    }

    // Handle startDate (could be DateTime, String, or null)
    DateTime startDate = project['startDate'] != null
        ? (project['startDate'] is DateTime
            ? project['startDate']
            : DateTime.parse(project['startDate']))
        : DateTime.now(); // Use current time if startDate is null

    // Handle endDate (could be DateTime, String, or null)
    DateTime endDate = project['endDate'] != null
        ? (project['endDate'] is DateTime
            ? project['endDate']
            : DateTime.parse(project['endDate']))
        : DateTime.now(); // Use current time if endDate is null

    // Get totalAmount and donatedAmount, handle null or invalid values
    double totalAmount = (project['totalAmount'] ?? 0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming"; // Project is not started yet
    } else if (donatedAmount >= totalAmount) {
      return "in-progress"; // Project reached the goal
    } else {
      if (now.isAfter(endDate)) {
        return "failed"; // Project failed to reach the target
      } else {
        return "active"; // Project is ongoing and goal is not reached yet
      }
    }
  }

  Future<bool> _isProjectCanceled(String projectId) async {
    try {
      // Fetch the project document from Firestore using the projectId
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      // Check if the document exists
      if (doc.exists) {
        // Retrieve the 'isCanceled' field and return true or false
        bool isCanceled = doc['isCanceled'] ?? false;
        return isCanceled; // Return true if canceled, false otherwise
      } else {
        print("Project not found");
        return false; // If the project does not exist, return false
      }
    } catch (e) {
      print("Error fetching project state: $e");
      return false; // Return false in case of an error
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "in-progress":
        return Colors.purple;
      case "completed":
        return Colors.blue;
      case "canceled":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  double weiToEth(BigInt wei) {
    return (wei / BigInt.from(10).pow(18)).toDouble();
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
            "Organization's Projects", // Title now doesn't include orgName
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
                future: projects, // Ensure this Future is properly initialized
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                      color: Colors.white,
                    ));
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child:
                          Text("Currently, there are no projects available."),
                    );
                  }

                  final projectList = snapshot.data!;

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: projectList.length,
                    itemBuilder: (context, index) {
                      final project = projectList[index];

                      return FutureBuilder<String>(
                        future: _getProjectState(
                            project), // Await the project state
                        builder: (context, stateSnapshot) {
                          if (stateSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                                child: CircularProgressIndicator(
                              color: Colors.white,
                            ));
                          } else if (stateSnapshot.hasError) {
                            return Center(
                                child: Text("Error: ${stateSnapshot.error}"));
                          } else if (!stateSnapshot.hasData) {
                            return SizedBox(); // Handle no data scenario
                          }

                          final projectState = stateSnapshot.data!;
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
                                  color: Color.fromRGBO(24, 71, 137, 1),
                                  width: 3),
                            ),
                            elevation: 2,
                            margin: EdgeInsets.symmetric(
                                vertical: 6, horizontal: 16),
                            child: ListTile(
                              tileColor: Colors.grey[200],
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
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
                                          color:
                                              Color.fromRGBO(238, 100, 90, 1)),
                                      children: [
                                        TextSpan(
                                          text: deadline,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        stateColor),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style:
                                            TextStyle(color: Colors.grey[600]),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: stateColor.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                      startDate:
                                          project['startDate'].toString(),
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

class CancelAllProjectsHelper {
  final BlockchainService _blockchainService = BlockchainService();

  /// Cancel all projects for a specific organization
  Future<void> cancelAllProjectsForOrganization(String orgAddress, String justification) async {
    try {
      print("🔎 Fetching projects for org: $orgAddress");
      List<Map<String, dynamic>> projects =
          await _blockchainService.fetchOrganizationProjects(orgAddress);

      if (projects.isEmpty) {
        print("⚠️ No projects found for this organization.");
        return;
      }

      for (var project in projects) {
        int projectId = project['id'];
        print("🚫 Cancelling project ID: $projectId");

        await _cancelProjectInFirestore(projectId, justification);
      }

      print("✅ All projects canceled and updated in Firestore.");
    } catch (e) {
      print("❌ Error while canceling all projects: $e");
    }
  }

  /// Firestore logic to cancel a project
  Future<void> _cancelProjectInFirestore(int projectId, String justification) async {
    final docRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId.toString());

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      await docRef.update({

        'isCanceled': true,

        'cancellationReason': justification,

        'cancelledAt': FieldValue.serverTimestamp(),

        'cancelledBy': 'admin'

      });

      print("📄 Firestore project updated: $projectId with justification");

      

      // Attempt to get project details to send notification

      try {

        final project = await _blockchainService.getProjectDetails(projectId);

        if (!project.containsKey("error")) {

          await _sendCancellationNotification(

            projectId.toString(), 

            project['name'] ?? 'Unknown Project', 

            project['organization'] ?? '', 

            justification

          );

        }

      } catch (e) {

        print("⚠️ Could not send notification: $e");

      }
    } else {
      await docRef.set({

        'isCanceled': true,

        'cancellationReason': justification,

        'cancelledAt': FieldValue.serverTimestamp(),

        'cancelledBy': 'admin'

      });

      print("🆕 Firestore project created and canceled: $projectId with justification");

    }

  }

  

  // Send notification to project creator

  Future<void> _sendCancellationNotification(String projectId, String projectName, String creatorAddress, String justification) async {

    try {

      if (creatorAddress.isEmpty) {

        print("❌ No project creator wallet address found");

        return;

      }

      

      // Create notification for project creator

      final notificationId = 'project_cancelled_${projectId}_${DateTime.now().millisecondsSinceEpoch}';

      

      await FirebaseFirestore.instance

          .collection('charity_notifications')

          .doc(notificationId)

          .set({

            'charityAddress': creatorAddress,

            'projectId': projectId,

            'projectName': projectName,

            'message': 'Your project "$projectName" has been cancelled by an admin. Reason: $justification',

            'type': 'project_cancellation',

            'status': 'canceled',

            'timestamp': FieldValue.serverTimestamp(),

            'isRead': false,

            'cancellationReason': justification,

          });

          

      print("✅ Cancellation notification sent to project creator: $creatorAddress");

    } catch (e) {

      print("❌ Error sending cancellation notification: $e");
    }
  }
}
