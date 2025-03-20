



// flutter run -d chrome --target=lib/AdminScreens/ViewComplaintsPage.dart --debug

import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart'; 
import '../firebase_options.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/Terms&cond.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'AdminSidebar.dart'; //
// Define your Ethereum RPC and contract details
const String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
const String contractAddress = '0xc23C7DCCEFFD3CFBabED29Bd7eE28D75FF7612D4';
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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ViewComplaintsPage(),
    );
  }
}

class ViewComplaintsPage extends StatefulWidget {
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
        _deleteComplaintFunction = _contract.function('deleteComplaint');  // Reference to deleteComplaint function


    print("📡 Fetching complaints from blockchain...");
    await _fetchComplaints();
  }

  

  // Function to resolve a complaint by calling the smart contract
Future<void> _resolveComplaint(int complaintId) async {
  if (!mounted) return;

  Navigator.pop(context); // Close modal

  try {
    var credentials = await _web3Client.credentialsFromPrivateKey('9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c');

    print("🔄 Sending transaction to resolve complaint...");
    await _web3Client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _resolveComplaintFunction,
        parameters: [BigInt.from(complaintId)],
        gasPrice: EtherAmount.inWei(BigInt.from(5000000000)),
        maxGas: 200000,
      ),
      chainId: 11155111, // Sepolia testnet
    );

    print("✅ Complaint resolved successfully!");

    // Fetch updated complaints to reflect changes
    await _fetchComplaints();
  } catch (e) {
    print('❌ Error resolving complaint: $e');
  }
}



// fetch complaints 
Future<void> _fetchComplaints() async {
  try {
    print("📡 Fetching complaints from blockchain...");

    // Fetch data from the contract
    final result = await _web3Client.call(
      contract: _contract,
      function: _getAllComplaints,
      params: [],
    );

    print("🔍 Raw result from blockchain:");
    print("  ├── Total items: ${result.length}");
    print("  ├── Data structure: ${result.runtimeType}");
    print("  ├── Raw data: $result\n");

    // Ensure the result has expected length
    if (result.length != 7) {
      throw Exception("❌ Unexpected response format from fetchAllComplaints: Expected 7 fields but got ${result.length}");
    }

    // Extract values from the result
    List<BigInt> ids = List<BigInt>.from(result[0]);
    List<String> titles = List<String>.from(result[1]);
    List<String> descriptions = List<String>.from(result[2]);
    List<EthereumAddress> complainants = List<EthereumAddress>.from(result[3]);
    List<EthereumAddress> targetCharities = List<EthereumAddress>.from(result[4]);
    List<BigInt> timestamps = List<BigInt>.from(result[5]);
    List<bool> resolvedStatuses = List<bool>.from(result[6]);

    print("✅ Successfully extracted complaint data.");
    print("  ├── IDs count: ${ids.length}");
    print("  ├── Titles count: ${titles.length}");
    print("  ├── Descriptions count: ${descriptions.length}");
    print("  ├── Complainants count: ${complainants.length}");
    print("  ├── Target Charities count: ${targetCharities.length}");
    print("  ├── Timestamps count: ${timestamps.length}");
    print("  ├── Resolved statuses count: ${resolvedStatuses.length}");

    // Check for mismatched lengths
    int expectedLength = ids.length;
    if ([titles, descriptions, complainants, targetCharities, timestamps, resolvedStatuses]
        .any((list) => list.length != expectedLength)) {
      throw Exception("❌ Data inconsistency detected! Arrays have mismatched lengths.");
    }

    // Convert the extracted data into a list of maps, filtering out invalid complaints
    List<Map<String, dynamic>> complaints = [];
    for (int i = 0; i < expectedLength; i++) {
      // Validate complaint data
      if (ids[i] == BigInt.zero || titles[i].trim().isEmpty || descriptions[i].trim().isEmpty) {
        print("⚠️ Skipping complaint #$i due to invalid or missing data.");
        continue;
      }

      print("\n📌 Processing complaint #$i");
      print("  ├── ID: ${ids[i]}");
      print("  ├── Title: ${titles[i]}");
      print("  ├── Description: ${descriptions[i]}");
      print("  ├── Complainant: ${complainants[i].hex}");
      print("  ├── Target Charity: ${targetCharities[i].hex}");
      print("  ├── Timestamp (Raw BigInt): ${timestamps[i]}");
      print("  ├── Timestamp (Converted): ${DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000)}");
      print("  ├── Resolved: ${resolvedStatuses[i]}\n");

      complaints.add({
        'id': ids[i].toInt(),
        'title': titles[i],
        'description': descriptions[i],
        'complainant': complainants[i].hex,
        'targetCharity': targetCharities[i].hex,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(timestamps[i].toInt() * 1000),
        'resolved': resolvedStatuses[i],
      });
    }

    // Sort complaints by timestamp (newest first)
    complaints.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    // Ensure the widget is still mounted before calling setState
    if (!mounted) return;

    // Update UI state
    setState(() {
      _complaints = complaints;
    });

    print("🎉 All valid complaints processed successfully! Total complaints: ${_complaints.length}");

  } catch (e, stackTrace) {
    print("❌ Error fetching complaints: $e");
    print("🔍 Stack trace: $stackTrace");

    setState(() {
      _complaints = [
        {'title': 'Error', 'description': 'Unable to fetch complaints at the moment.'}
      ];
    });
  }
}


  // Sidebar item widget
  Widget _buildSidebarItem(BuildContext context, String title, VoidCallback onTap, {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
  return ListTile(
    title: Center( // Center the text
      child: Text(
        title,
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
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
          side: BorderSide(color: borderColor, width: 2), // Set border thickness here
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(
          title,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
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
            color: Color.fromRGBO(24, 71, 137, 1), // Customize the color
          ),
        ),
      ),
                // Toggle button for sidebar visibility
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



                
                // Complaint List
              Expanded(
  child: _complaints.isEmpty
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
    if (complaint['title'] == null || complaint['title'].trim().isEmpty || 
        complaint['description'] == null || complaint['description'].trim().isEmpty) {
      return SizedBox.shrink(); // Don't render the complaint if it's invalid
    }

    return GestureDetector(
      onTap: () => _showComplaintDetails(complaint), // Show details on tap
      child: Card(
        margin: EdgeInsets.all(10),
        elevation: 5,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2), // Custom blue border
          borderRadius: BorderRadius.circular(10),
        ),
        color: Colors.grey[200], // Light grey background
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes text left & icon right
            children: [
              Expanded( // Ensures text doesn't overflow
                child: Text(
                  complaint['title'],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
              ),
              if (complaint['resolved'] == true) // Show checkmark if resolved
                Icon(Icons.check_circle, color: Color.fromARGB(255, 54, 142, 57), size: 24),
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
                          fontSize: 25, fontWeight: FontWeight.bold, color: Color.fromRGBO(24, 71, 137, 1)),
                    ),
                  ),
                  SizedBox(height: 50),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Complaint Details: ${complaint['description']}',
                              style: TextStyle(fontSize: 20, color: Color.fromRGBO(24, 71, 137, 1))),
                          SizedBox(height: 30),
                          Text('Complainant: ${complaint['complainant']}',
                              style: TextStyle(fontSize: 20, color: Color.fromRGBO(24, 71, 137, 1))),
                          SizedBox(height: 30),
                          GestureDetector(
                            onTap: () {
                              // Assuming 'targetCharity' contains the organization details or ID to pass
//                              Navigator.push(
//   context,
//   MaterialPageRoute(
//     builder: (context) => OrganizationProfile(
//       walletAddress: complaint['targetCharity'], // Pass the wallet address as String
//     ),
//   ),
// );


                            },
                            child: RichText(
  text: TextSpan(
    text: 'Target Charity:  ',
    style: TextStyle(
      fontSize: 20,
      color: Color.fromRGBO(24, 71, 137, 1),
    ),
    children: <TextSpan>[
      TextSpan(
        text: 'View profile',
        style: TextStyle(
          fontSize: 20,
          color: Color.fromRGBO(14, 101, 240, 1), // Blue color
          decoration: TextDecoration.underline, // Underlined
        ),
        recognizer: TapGestureRecognizer()..onTap = () {
           Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => OrganizationProfile(
      walletAddress: complaint['targetCharity'], // Pass the wallet address as String
    ),
  ),
);
        },
      ),
    ],
  ),
)
,
                          ),
                          SizedBox(height: 40),
                          Text(
                            'Date: ${complaint['timestamp'] is DateTime ? complaint['timestamp'].toLocal().toString().split(' ')[0] : complaint['timestamp'] != null ? DateTime.parse(complaint['timestamp']).toLocal().toString().split(' ')[0] : 'N/A'}',
                            style: TextStyle(fontSize: 20, color: Color.fromRGBO(24, 71, 137, 1)),
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
                                complaint['resolved'] ? 'Resolved' : 'Unresolved',
                                style: TextStyle(
                                    fontSize: 20, color: Color.fromRGBO(24, 71, 137, 1)),
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
                          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        onPressed: () {
                          _resolveComplaint(complaint['id']).then((_) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => ViewComplaintsPage()),
                            );
                          });
                        },
                        child: Text('Resolve', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 197, 47, 36),
                          minimumSize: Size(120, 50),
                          padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                          textStyle: TextStyle(fontSize: 18),
                        ),
                        onPressed: () async {
                          bool shouldDelete = await _showDeleteConfirmationDialog(context);
                          if (shouldDelete) {
                            await _deleteComplaint(complaint['id']);
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => ViewComplaintsPage()),
                            );
                            showSuccessPopup(context);
                          }
                        },
                        child: Text('Delete', style: TextStyle(color: Colors.white)),
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

Future<void> _deleteComplaint(int complaintId) async {
  if (!mounted) return;

  try {
    // Credentials for the sender (private key)
    var credentials = await _web3Client.credentialsFromPrivateKey(
      '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'
    );

    print("🗑️ Deleting complaint...");

    // Sending the transaction to delete the complaint
    var transaction = await _web3Client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _deleteComplaintFunction,
        parameters: [BigInt.from(complaintId)],
        gasPrice: EtherAmount.inWei(BigInt.from(5000000000)), // Set an appropriate gas price
        maxGas: 200000, // Set the max gas limit (you might need to adjust this)
      ),
      chainId: 11155111, // Sepolia testnet
    );

    // Confirming the transaction receipt
    var receipt = await _web3Client.getTransactionReceipt(transaction);
    if (receipt == null) {
      print('❌ Transaction failed or is pending. Please check the transaction status.');
      return;
    }

    // Check if the transaction was successful (receipt status 1 means success)
    if (receipt.status == 1) {
      print("✅ Complaint deleted successfully!");

      // Fetch updated complaints to reflect changes
      await _fetchComplaints();
    } else {
      print('❌ Deletion failed. Transaction receipt status: ${receipt.status}');
    }
  } catch (e) {
    print('❌ Error deleting complaint: $e');
  }
}




Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
  print("🚀 Showing delete confirmation dialog...");

  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
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
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              OutlinedButton(
                onPressed: () {
                  print("❌ Cancel clicked - Deletion not confirmed.");
                  Navigator.pop(context, false); // Return false on cancel
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(24, 71, 137, 1), // Border color for Cancel button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background color for Cancel button
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color for Cancel button
                  ),
                ),
              ),
              const SizedBox(width: 20), // Add space between the buttons
              OutlinedButton(
                onPressed: () {
                  print("✅ Yes clicked - Deletion confirmed.");
                  Navigator.pop(context, true); // Return true after confirming deletion
                  // If you want to navigate back to the previous page or perform additional actions:
                  // Navigator.pop(context); // This line is for returning to the previous page, if needed
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(212, 63, 63, 1), // Border color for Yes button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(212, 63, 63, 1), // Background color for Yes button
                ),
                child: const Text(
                  '   Yes   ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color for Yes button
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(vertical: 10), // Add padding for the actions
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
  final String contractAddress = '0x02b0d417D48eEA64Aae9AdA80570783034ED6839';

  late Web3Client _client;
  late DeployedContract _contract;
  Map<String, dynamic>? organizationData;  // Hold fetched data
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
      int index = wallets.indexOf(EthereumAddress.fromHex(widget.walletAddress));
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
    backgroundColor: const Color.fromARGB(255, 246, 246, 246),
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(80),
      child: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only( top: 20 ),
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
                const Center(
                  child: Icon(Icons.account_circle, size: 120, color: Colors.grey),
                ),
                const SizedBox(height: 20),
            Padding(
  padding: const EdgeInsets.all(0), // Adjust the overall padding here
  child: Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
        const SizedBox(width: 200),
      // Left Side - Contact Information & About Us
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 120), // Space between the left and right sections
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildSectionTitle(Icons.contact_phone, "Contact Information"),
              _buildStyledInfoRow(Icons.phone, "Phone: ", organizationData?["phone"]),
              _buildStyledInfoRow(Icons.email, "Email: ", organizationData?["email"]),
              _buildStyledInfoRow(Icons.location_city, "City: ", organizationData?["city"]),
              const SizedBox(height: 16),
              _buildSectionTitle(Icons.info_outline, "About Us"),
              _buildStyledInfoRow(Icons.description, "", organizationData?["description"]),
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
              
              _buildSectionTitle(Icons.business, "Organization Details"),
              _buildStyledInfoRow(Icons.badge, "License No.: ", organizationData?["licenseNumber"]),
              _buildStyledInfoRow(Icons.public, "Website: ", organizationData?["website"], isLink: true),
              _buildStyledInfoRow(Icons.calendar_today, "Established date: ", organizationData?["establishmentDate"]),
            ],
          ),
        ),
      ),
    ],
  ),
),

                                const SizedBox(height: 140),

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
                        onPressed: () {
                          // Implement suspend account functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 80),
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
                        onPressed: () {
                          // Implement suspend account and cancel all projects functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
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


// Custom styled info row to ensure consistency
Widget _buildStyledInfoRow(IconData icon, String label, String? value, {bool isLink = false}) {
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
                "$label",
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

  Widget _buildInfoRow(IconData icon, String label, String? value, {bool isLink = false}) {
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
                decoration: isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

