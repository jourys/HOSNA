



// flutter run -d chrome --target=lib/AdminScreens/ViewComplaintsPage.dart --debug

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

// Define your Ethereum RPC and contract details
const String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
const String contractAddress = '0x3cC7a8C93c2bd9285785E382Bd9e9b2d2aB34D13';
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
  if (!mounted) return; // ✅ Ensure the widget is still in the tree

  Navigator.pop(context); // Close modal

  try {
    // Get user's credentials securely (DO NOT HARD-CODE PRIVATE KEY)
    var credentials = await _web3Client.credentialsFromPrivateKey('9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'); 

    print("🔄 Sending transaction to resolve complaint...");
    final result = await _web3Client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _resolveComplaintFunction,
        parameters: [BigInt.from(complaintId)],
        gasPrice: EtherAmount.inWei(BigInt.from(5000000000)), // 5 Gwei
        maxGas: 200000,
      ),
      chainId: 11155111, // Sepolia testnet chainId
    );

    print("✅ Transaction successful: $result");

    // ✅ Ensure the widget is still mounted before calling setState
    if (mounted) {
      setState(() {
        _complaints = _complaints.map((complaint) {
          if (complaint['id'] == complaintId) {
            return {...complaint, 'resolved': true};
          }
          return complaint;
        }).toList();
      });
      print("✅ Complaint resolved locally!");
    }
  } catch (e) {
    print('❌ Error resolving complaint: $e');
  }
}



// Fetch complaints from the smart contract





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

    // Convert the extracted data into a list of maps
    List<Map<String, dynamic>> complaints = [];
    for (int i = 0; i < expectedLength; i++) {
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

    // Update state
    setState(() {
      _complaints = complaints;
    });

    print("🎉 All complaints processed successfully! Total complaints: ${_complaints.length}");

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
      body: Row(
        children: [
          // Sidebar (Toggleable visibility)
          if (isSidebarVisible)
            Container(
              width: 350,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Image.asset(
                      'assets/HOSNA.jpg',
                      height: 200,
                      width: 350,
                    ),
                  ),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Home", () {
                    // Navigate to Admin Home Page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminHomePage()),
                    );
                  }),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Organizations", () {Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminBrowseOrganizations()),
                    );}),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Projects", () {
                    // Navigate to Admin Browse Projects
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AdminBrowseProjects()),
                    );
                  }),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Complaints", () {}),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Terms & Conditions", () {}),
                  Divider(color: Color.fromRGBO(24, 71, 137, 1)),
                  SizedBox(height: 50),
                  _buildSidebarButton(
                    title: "Sign Out",
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => AdminLoginPage()),
                      );
                    },
                    backgroundColor: Colors.white,
                    borderColor: Color.fromRGBO(24, 71, 137, 1),
                    textColor: Color.fromRGBO(24, 71, 137, 1),
                  ),
                  SizedBox(height: 14),
                  _buildSidebarButton(
                    title: "Delete Account",
                    onTap: () {
                      // Handle delete account
                    },
                    backgroundColor: Colors.red,
                    borderColor: Colors.red,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
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
        child: Container( // Container wraps the entire content and sets background to white
           decoration: BoxDecoration(
            color: Colors.white, // Set the background color to white
            borderRadius: BorderRadius.circular(20), // Set circular corners
          ),// Set circular corners
        child: SizedBox(
          width: 600,  // Fixed width
          height: 600, // Fixed height to make it square
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               Center(
  child: Text(
    complaint['title'],
    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold , color: Color.fromRGBO(24, 71, 137, 1)),
  ),
)
,
                SizedBox(height: 50),
                Expanded( // Allows description to take available space
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complaint Details : ${complaint['description']}', style: TextStyle(fontSize: 20 , color: Color.fromRGBO(24, 71, 137, 1)) ),
                        SizedBox(height: 30),
                        Text('Complainant: ${complaint['complainant']}', style: TextStyle(fontSize: 20 , color: Color.fromRGBO(24, 71, 137, 1)) ),
                         SizedBox(height: 30),
                        Text('Target Charity: ${complaint['targetCharity']}', style: TextStyle(fontSize: 20 , color: Color.fromRGBO(24, 71, 137, 1)) ),
                         SizedBox(height: 40),
                    Text(
  'Date: ${complaint['timestamp'] is DateTime ? 
            complaint['timestamp'].toLocal().toString().split(' ')[0] : 
            complaint['timestamp'] != null ? DateTime.parse(complaint['timestamp']).toLocal().toString().split(' ')[0] : 'N/A'}',
  style: TextStyle(fontSize: 20 , color: Color.fromRGBO(24, 71, 137, 1)),
),


                         SizedBox(height: 30),
                    Row(
  children: [
    Icon(
      complaint['resolved'] ? Icons.check_circle : Icons.cancel,
      color: complaint['resolved'] ? Color.fromARGB(255, 54, 142, 57) : Color.fromARGB(255, 197, 47, 36),
      size: 32, // Increase icon size
    ),
    SizedBox(width: 10), // Adds spacing between icon and text
    Text(
      complaint['resolved'] ? 'Resolved' : 'Unresolved',
      style: TextStyle(fontSize: 20,   color: Color.fromRGBO(24, 71, 137, 1)), // Increase text size
    ),
  ],
)


                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                // Buttons for resolving and deleting
              Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromARGB(255, 54, 142, 57),
        minimumSize: Size(120, 50), // Width: 120, Height: 50
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        textStyle: TextStyle(fontSize: 18), // Increase text size
      ),
      onPressed: () {
        _resolveComplaint(complaint['id']).then((_) {
    // Navigate to ViewComplaintsPage after resolving
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
        minimumSize: Size(120, 50), // Width: 120, Height: 50
        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
        textStyle: TextStyle(fontSize: 18), // Increase text size
      ),
      onPressed: () async {
  // Show delete confirmation dialog
  bool shouldDelete = await _showDeleteConfirmationDialog(context);

  // If user confirms deletion, proceed
  if (shouldDelete) {
    // Call _deleteComplaint function with the complaint ID
    await _deleteComplaint(complaint['id']);
    showSuccessPopup(context);
    // Close dialog after action
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ViewComplaintsPage()),
    ); // Close the current modal
     
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
  try {
    print("🚀 Attempting to delete complaint with ID: $complaintId");

    // Assuming _deleteComplaintFunction is the function reference for deleting a complaint
    var credentials = await _web3Client.credentialsFromPrivateKey(
        '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'); 
    print("✅ Credentials fetched successfully");

    // Sending the transaction to delete the complaint
    var response = await _web3Client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _deleteComplaintFunction,
        parameters: [BigInt.from(complaintId)],
      ),
        chainId: 11155111,
    );
    print("🚀 Transaction sent successfully with response: $response");

    print('Complaint $complaintId deleted successfully');
    
    // Optionally refresh the complaints list after deletion
    await _fetchComplaints();
    print("📡 Complaints list refreshed after deletion");
  } catch (e) {
    print("❌ Error deleting complaint: $e");
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