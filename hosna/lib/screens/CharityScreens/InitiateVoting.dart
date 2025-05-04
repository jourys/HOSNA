import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart'; // Import Client from the http package
import 'dart:convert'; // Import for utf8 and hex encoding
import 'dart:typed_data'; // Required to use Uint8List
import 'dart:convert'; // Optional if you need other encoding
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

class InitiateVoting extends StatefulWidget {
  final String walletAddress;
  final int projectId;
  const InitiateVoting(
      {super.key, required this.walletAddress, required this.projectId});

  @override
  State<InitiateVoting> createState() => _InitiateVotingState();
}

class _InitiateVotingState extends State<InitiateVoting> {
  List<Map<String, dynamic>> _selectedProjects = [];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  String? _privateKey; // Variable to hold the private key
  late Web3Client _web3Client; // Web3 client
  late EthereumAddress _contractAddress; // Contract address
  late DeployedContract _contract; // Contract instance
  late ContractFunction
      _startVotingFunction; // Function to call in the contract
  late Credentials _credentials; // Credentials for interacting with blockchain
  bool _isBlockchainReady = false; // NEW: Flag to indicate blockchain is ready
  bool _isLoading = false; // Add this to your widget's state

  bool votingInitiated = false;
  final String contractABI = '''[
    {
        "inputs": [],
        "stateMutability": "view",
        "type": "function",
        "name": "getVotingStatus",
        "outputs": [
            {"internalType": "uint256", "name": "status", "type": "uint256"},
            {"internalType": "uint256", "name": "timeLeft", "type": "uint256"}
        ]
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "projectId", "type": "uint256"}
        ],
        "name": "vote",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "projectId", "type": "uint256"}
        ],
        "name": "fundProject",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "_votingDuration", "type": "uint256"},
            {"internalType": "uint256[]", "name": "_projectIds", "type": "uint256[]"},
            {"internalType": "string[]", "name": "_projectNames", "type": "string[]"}
        ],
        "name": "initiateVoting",
        "outputs": [
            {"internalType": "uint256", "name": "votingId", "type": "uint256"}
        ],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {"internalType": "uint256", "name": "projectId", "type": "uint256"}
        ],
        "name": "getProject",
        "outputs": [
            {
                "internalType": "struct CharityVoting.Project",
                "name": "",
                "type": "tuple",
                "components": [
                    {"internalType": "uint256", "name": "id", "type": "uint256"},
                    {"internalType": "string", "name": "name", "type": "string"},
                    {"internalType": "uint256", "name": "funds", "type": "uint256"},
                    {"internalType": "uint256", "name": "votes", "type": "uint256"}
                ]
            }
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "getVotingPercentages",
        "outputs": [
            {"internalType": "string", "name": "", "type": "string"}
        ],
        "stateMutability": "view",
        "type": "function"
    }
]''';

  @override
  void initState() {
    super.initState();
    _initializeBlockchain();
    _loadPrivateKey(); // Load the private key during initialization
  }

  Future<void> _loadPrivateKey() async {
    print('Loading private key...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('Error: Wallet address not found.');
        return;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        setState(() {
          _privateKey = privateKey; // Set the private key
        });
        print('✅ Private key retrieved for wallet $walletAddress');
      } else {
        print('❌ Private key not found for wallet $walletAddress');
      }
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
    }
  }

  Future<void> cancelTransaction(int nonce) async {
    final credentials =
        await _web3Client.credentialsFromPrivateKey(_privateKey!);
    final ownAddress = await credentials.extractAddress();

    await _web3Client.sendTransaction(
      credentials,
      web3.Transaction(
        from: ownAddress,
        to: ownAddress, // Send to self
        gasPrice: EtherAmount.inWei(
            BigInt.from(30 * 1e9)), // Higher gas price (30 gwei)
        maxGas: 21000,
        value: EtherAmount.zero(),
        nonce: nonce, // Same nonce as the pending tx
      ),
      chainId: 11155111,
    );

    print('✅ Sent cancel tx with nonce $nonce');
  }

  Future<void> _initializeBlockchain() async {
    try {
      print('Initializing blockchain...');

      // Initialize the Web3Client
      _web3Client = Web3Client(
          'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1',
          Client());
      print('Web3 client initialized.');

      // Set the contract address
      _contractAddress =
          EthereumAddress.fromHex('0x2D2cDD99eff93AC01F825b45eE0844d44345F058');
      print('Contract address set to $_contractAddress');

      // Load the contract
      _contract = DeployedContract(
          ContractAbi.fromJson(contractABI, 'CharityVoting'), _contractAddress);
      print('Contract loaded.');

      // Extract the function 'startVoting' (matching the ABI)
      _startVotingFunction =
          _contract.function('initiateVoting'); // Use 'startVoting' here
      print('Function extracted: startVoting');

      // Set the blockchain readiness flag
      _isBlockchainReady = true;
      print('Blockchain is now ready ✅');
    } catch (e) {
      print('Error initializing blockchain: $e');
    }
  }

// Future<void> _initiateVotingOnBlockchain() async {
//   print('🚀 Initiating voting process...');
//   print('🧮 Selected projects count: ${_selectedProjects.length}');
//   print('📆 Start date: $_startDate | End date: $_endDate');
//   print('✅ Blockchain ready? $_isBlockchainReady');

//   // Quick inline function to show snackbars
//   void showWarning(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
//   }

//   // Validation checks
//   if (_selectedProjects.isEmpty || _startDate == null || _endDate == null) {
//     print('❗ Validation failed: Need exactly 3 projects and valid start/end dates.');
//     showWarning('⚠️ Please select 3 projects and valid start and end dates.');
//     setState(() => _isLoading = false);
//     return;
//   }

//   if (!_isBlockchainReady) {
//     print('🛑 Blockchain not ready yet. Aborting...');
//     showWarning('⏳ Blockchain is not ready yet. Please wait...');
//     setState(() => _isLoading = false);
//     return;
//   }

//   try {
//     print('🔐 Fetching credentials...');
//     _credentials = await _web3Client.credentialsFromPrivateKey(_privateKey!);
//     print('🔑 Credentials obtained.');

//     final startTimestamp = _startDate!.millisecondsSinceEpoch;
//     final endTimestamp = _endDate!.millisecondsSinceEpoch;
//     final votingDurationSeconds = ((endTimestamp - startTimestamp) ~/ 1000);

//     if (votingDurationSeconds <= 0) {
//       print('❗ Invalid voting duration: $votingDurationSeconds seconds');
//       showWarning('⚠️ End date must be after the start date.');
//       setState(() => _isLoading = false);
//       return;
//     }

//     final votingDuration = BigInt.from(votingDurationSeconds);
//     print('📅 Voting Duration (s): $votingDuration');

//     final projectIds = <BigInt>[];
//     final projectNames = <String>[];

//     for (final proj in _selectedProjects) {
//       final id = proj['id'];
//       final name = proj['name'];

//       if (id is int && name is String) {
//         projectIds.add(BigInt.from(id));
//         projectNames.add(name);
//       } else {
//         print('❗ Invalid project data: id=$id, name=$name');
//         showWarning('⚠️ Invalid project data. Please try again.');
//         setState(() => _isLoading = false);
//         return;
//       }
//     }

//     if (projectIds.isEmpty || projectNames.isEmpty) {
//       print('❗ No valid projects selected');
//       showWarning('⚠️ No valid projects selected. Please try again.');
//       setState(() => _isLoading = false);
//       return;
//     }

//     print('🔍 Project IDs: $projectIds');
//     print('🔍 Project Names: $projectNames');
//     print('🧾 Creating transaction...');

//     try {
//       final txHash = await _web3Client.sendTransaction(
//         _credentials,
//         web3.Transaction(
//           to: _contract.address,
//           gasPrice: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 20),
//           data: _contract.function('initiateVoting').encodeCall([
//             votingDuration,
//             projectIds,
//             projectNames,
//           ]),
//         ),
//         chainId: 11155111,
//       );
//       print("✅ Transaction sent! Hash: $txHash");
//     } catch (e) {
//       print("❌ Transaction failed: $e");
//       showWarning('❗ Blockchain transaction failed.');
//       setState(() => _isLoading = false);
//       return;
//     }

//     final function = _contract.function('initiateVoting');
//     final result = await _web3Client.call(
//       contract: _contract,
//       function: function,
//       params: [votingDuration, projectIds, projectNames],
//     );

//     if (result.isEmpty) {
//       print('❗ Error: Voting counter not found in contract.');
//       showWarning('⚠️ Voting counter not found.');
//       setState(() => _isLoading = false);
//       return;
//     }

//     final votingCounter = result[0].toString();
//     print('🎉 Voting Counter (ID): $votingCounter');

//     await FirebaseFirestore.instance
//         .collection('projects')
//         .doc(widget.projectId.toString())
//         .set({
//           'votingId': votingCounter,
//           'votingInitiated': true,
//         }, SetOptions(merge: true));

//     await FirebaseFirestore.instance
//         .collection('votings')
//         .doc(votingCounter)
//         .set({
//           'projectIds': projectIds.map((id) => id.toInt()).toList(),
//           'projectNames': projectNames,
//         });

//     print("✅ Voting ID and details successfully saved to Firestore: $votingCounter");

//     await VoteListener.listenForVotingStatus(int.parse(votingCounter), widget.projectId);
//     print("✅ listener started");

//     // Hide loading before navigating away
//     setState(() => _isLoading = false);

//     // Navigate and show success popup
//     Navigator.pop(context, true);
//     showVotingSuccessPopup(context);
//     print('✅ Voting initiation process complete.');

//   } catch (e) {
//     print('❌ Error initiating voting: $e');
//     showWarning('❗ Failed to initiate voting. Please try again.');
//     setState(() => _isLoading = false);
//   }
// }

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

  Future<void> _initiateVotingOnBlockchain() async {
    print('🚀 Initiating voting process...');
    print('🧮 Selected projects count: ${_selectedProjects.length}');
    print('📆 Start date: $_startDate | End date: $_endDate');
    print('✅ Blockchain ready? $_isBlockchainReady');

    // Quick inline function to show snackbars
    void showWarning(String message) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }

    // Validation checks
    if (_selectedProjects.isEmpty || _startDate == null || _endDate == null) {
      print(
          '❗ Validation failed: Need exactly 3 projects and valid start/end dates.');
      showWarning('⚠️ Please select 3 projects and valid start and end dates.');
      setState(() => _isLoading =
          false); // Ensure _isLoading is set to false if validation fails
      return;
    }

    if (!_isBlockchainReady) {
      print('🛑 Blockchain not ready yet. Aborting...');
      showWarning('⏳ Blockchain is not ready yet. Please wait...');
      setState(() => _isLoading =
          false); // Ensure _isLoading is set to false if blockchain is not ready
      return;
    }

    try {
      print('🔐 Fetching credentials...');
      _credentials = await _web3Client.credentialsFromPrivateKey(_privateKey!);
      print('🔑 Credentials obtained.');

      final startTimestamp = _startDate!.millisecondsSinceEpoch;
      final endTimestamp = _endDate!.millisecondsSinceEpoch;
      final votingDurationSeconds = ((endTimestamp - startTimestamp) ~/ 1000);

      if (votingDurationSeconds <= 0) {
        print('❗ Invalid voting duration: $votingDurationSeconds seconds');
        showWarning('⚠️ End date must be after the start date.');
        setState(() => _isLoading =
            false); // Ensure _isLoading is set to false if duration is invalid
        return;
      }

      final votingDuration = BigInt.from(votingDurationSeconds);
      print('📅 Voting Duration (s): $votingDuration');

      final projectIds = <BigInt>[];
      final projectNames = <String>[];

      for (final proj in _selectedProjects) {
        final id = proj['id'];
        final name = proj['name'];

        if (id is int && name is String) {
          projectIds.add(BigInt.from(id));
          projectNames.add(name);
        } else {
          print('❗ Invalid project data: id=$id, name=$name');
          showWarning('⚠️ Invalid project data. Please try again.');
          setState(() =>
              _isLoading = false); // Ensure _isLoading is set to false on error
          return;
        }
      }

      if (projectIds.isEmpty || projectNames.isEmpty) {
        print('❗ No valid projects selected');
        showWarning('⚠️ No valid projects selected. Please try again.');
        setState(() => _isLoading =
            false); // Ensure _isLoading is set to false if no valid projects
        return;
      }

      print('🔍 Project IDs: $projectIds');
      print('🔍 Project Names: $projectNames');
      print('🧾 Creating transaction...');

      String? txHash;
      try {
        txHash = await _web3Client.sendTransaction(
          _credentials,
          web3.Transaction(
            to: _contract.address,
            gasPrice: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 50),
            data: _contract.function('initiateVoting').encodeCall([
              votingDuration,
              projectIds,
              projectNames,
            ]),
          ),
          chainId: 11155111,
        );
        print("✅ Transaction sent! Hash: $txHash");
      } catch (e) {
        print("❌ Transaction failed: $e");
        showWarning('❗ Blockchain transaction failed.');
        setState(() =>
            _isLoading = false); // Ensure _isLoading is set to false on failure
        return;
      }

      final function = _contract.function('initiateVoting');
      final result = await _web3Client.call(
        contract: _contract,
        function: function,
        params: [votingDuration, projectIds, projectNames],
      );

      if (result.isEmpty) {
        print('❗ Error: Voting counter not found in contract.');
        showWarning('⚠️ Voting counter not found.');
        setState(() =>
            _isLoading = false); // Ensure _isLoading is set to false on error
        return;
      }

      final votingCounter = result[0].toString();
      print('🎉 Voting Counter (ID): $votingCounter');

      // Save voting information in Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId.toString())
          .set({
        'votingId': votingCounter,
        'votingInitiated': true,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('votings')
          .doc(votingCounter)
          .set({
        'projectIds': projectIds.map((id) => id.toInt()).toList(),
        'projectNames': projectNames,
      });

      print(
          "✅ Voting ID and details successfully saved to Firestore: $votingCounter");

      // Start the listener for the voting status
      await VoteListener.listenForVotingStatus(
          int.parse(votingCounter), widget.projectId);
      print("✅ listener started");

      // Hide loading before navigating away
      setState(() => _isLoading = false);

      // Navigate and show success popup
      Navigator.pop(context, true);
      showVotingSuccessPopup(context);
      print('✅ Voting initiation process complete.');
    } catch (e) {
      print('❌ Error initiating voting: $e');
      showWarning('❗ Failed to initiate voting. Please try again.');
      setState(() =>
          _isLoading = false); // Ensure _isLoading is set to false on failure
    }
  }

  void _initiateVoting() async {
    if (_selectedProjects.length != 3 || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select 3 projects and an end date.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _initiateVotingOnBlockchain();

    setState(() {
      _isLoading = false;
    });
  }

  void _openProjectSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProjectSelectorPage(walletAddress: widget.walletAddress),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      if (result.length == 3) {
        setState(() {
          _selectedProjects = result;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select exactly 3 projects.')),
        );
      }
    }
  }

  void _pickEndDate() async {
    DateTime now = DateTime.now();

    // Show date picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(Duration(days: 30)),
    );

    if (pickedDate == null) return; // If no date is picked, exit

    // Show time picker
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: now.hour, minute: now.minute),
    );

    if (pickedTime == null) return; // If no time is picked, exit

    // Combine the picked date and time
    setState(() {
      _endDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<bool> _showInitiateVotingConfirmationDialog(
      BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white, // Set background to white
              title: const Text(
                'Confirm Voting Initiation',
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Make title bold
                  fontSize: 22, // Increase title font size
                ),
                textAlign: TextAlign.center, // Center the title text
              ),
              content: const Text(
                'Are you sure you want to initiate the voting process?',
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
                        print("Cancel clicked - Voting not initiated.");
                        Navigator.pop(context, false); // Return false on cancel
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              24, 71, 137, 1), // Border color for Cancel button
                          width: 3,
                        ),
                        backgroundColor:
                            Colors.white, // Background color for Cancel button
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color: Color.fromRGBO(24, 71, 137,
                              1), // White text color for Cancel button
                        ),
                      ),
                    ),
                    const SizedBox(width: 20), // Add space between the buttons
                    OutlinedButton(
                      onPressed: () {
                        print("Yes clicked - Initiating voting...");
                        _initiateVoting(); // Trigger the voting process
                        Navigator.pop(
                            context, true); // Return true after initiation
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              24, 71, 137, 1), // Border color for Yes button
                          width: 3,
                        ),
                        backgroundColor: Color.fromRGBO(
                            24, 71, 137, 1), // Background color for Yes button
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

  void showVotingSuccessPopup(BuildContext context) {
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
                  'Voting process initiated successfully!',
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

  @override
  Widget build(BuildContext context) {
    final startDateFormatted =
        DateFormat('yyyy-MM-dd – HH:mm').format(_startDate);
    final endDateFormatted = _endDate != null
        ? DateFormat('yyyy-MM-dd – HH:mm').format(_endDate!)
        : 'Select End Date';
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.center, // Align the text to the right
          child: Text(
            'Initiate Voting        ',
            style: TextStyle(
              fontSize: 24, // Make text bigger
              fontWeight: FontWeight.bold, // Make text bold
              color: Color.fromRGBO(24, 71, 137, 1), // Text color
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // Optional, to remove the shadow
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 24),
            // 🧾 Instructions
            Text(
              'Please select 3 projects to initiate a voting session. Set a voting period and press "Initiate Voting" when ready.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            SizedBox(height: 24),

            // 🔍 Project Selection Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected Projects',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.search,
                      size: 32, color: Color.fromRGBO(24, 71, 137, 1)),
                  tooltip: 'Tap to search and select projects',
                  onPressed: _openProjectSelection,
                ),
              ],
            ),

            // 🧱 Selected Projects Fields (Tappable)
            ...List.generate(3, (index) {
              return GestureDetector(
                onTap: _openProjectSelection,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(vertical: 6),
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.grey),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedProjects.length > index
                              ? _selectedProjects[index]['name']
                              : 'Select Project ${index + 1}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              );
            }),

            SizedBox(height: 25),

            // 📅 Start Date (disabled)
            Text(
              'Voting Start Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 6),
            TextFormField(
              initialValue: startDateFormatted,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors
                    .grey.shade300, // Light gray color to indicate read-only
                prefixIcon:
                    Icon(Icons.date_range, color: Colors.grey), // Gray icon
                hintText: 'Start Date', // Optional hint text
                hintStyle:
                    TextStyle(color: Colors.grey), // Gray hint text color
              ),
              style: TextStyle(
                  color: Colors
                      .grey), // Gray text color to match the read-only state
              readOnly: true,
            ),

            SizedBox(height: 20),

            // ⏳ End Date Picker
            Text(
              'Voting End Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 6),
            GestureDetector(
              onTap: _pickEndDate,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: TextEditingController(text: endDateFormatted),
                  decoration: InputDecoration(
                    hintText: 'Select end date',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    prefixIcon: Icon(Icons.timer),
                  ),
                ),
              ),
            ),

            Spacer(),

            // 🚀 CTA Button
            Center(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _initiateVoting,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.how_to_vote),
                label: Text(
                  'Initiate Voting',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  padding: EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectSelectorPage extends StatefulWidget {
  final String walletAddress;
  const ProjectSelectorPage({super.key, required this.walletAddress});

  @override
  State<ProjectSelectorPage> createState() => _ProjectSelectorPageState();
}

class _ProjectSelectorPageState extends State<ProjectSelectorPage> {
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _projects = [];
  List<int> _selectedProjectIndices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      int count = await _blockchainService.getProjectCount();
      List<Map<String, dynamic>> tempProjects = [];

      for (int i = 0; i < count; i++) {
        final project = await _blockchainService.getProjectDetails(i);
        if (!project.containsKey('error')) {
          final status = await _getProjectState(project);
          if (status == 'active') {
            project['status'] = status;
            tempProjects.add(project);
          }
        }
      }

      setState(() {
        _projects = tempProjects;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching filtered projects: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();
    String projectId = project['id'].toString();

    bool isCanceled = await _isProjectCanceled(projectId);
    if (isCanceled) return "canceled";

    DateTime startDate = project['startDate'] is DateTime
        ? project['startDate']
        : DateTime.tryParse(project['startDate'] ?? '') ?? now;

    DateTime endDate = project['endDate'] is DateTime
        ? project['endDate']
        : DateTime.tryParse(project['endDate'] ?? '') ?? now;

    double total = (project['totalAmount'] ?? 0).toDouble();
    double donated = (project['donatedAmount'] ?? 0).toDouble();

    if (now.isBefore(startDate)) return "upcoming";
    if (donated >= total) return "in-progress";
    if (now.isAfter(endDate)) return "failed";
    return "active";
  }

  Future<bool> _isProjectCanceled(String projectId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      return doc.exists ? (doc['isCanceled'] ?? false) : false;
    } catch (e) {
      print("Error checking canceled status: $e");
      return false;
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedProjectIndices.contains(index)) {
        _selectedProjectIndices.remove(index);
      } else {
        if (_selectedProjectIndices.length < 3) {
          _selectedProjectIndices.add(index);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can only select 3 projects.')),
          );
        }
      }
    });
  }

  void _initiateVotingProcess() {
    if (_selectedProjectIndices.length != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select exactly 3 projects.')),
      );
      return;
    }

    final selectedProjects =
        _selectedProjectIndices.map((i) => _projects[i]).toList();

    // Pass the selected projects back to the previous page
    Navigator.pop(context, selectedProjects);
  }

  Color _getStateColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.center, // Align the text to the right
          child: Text(
            'Select Voting Options    ',
            style: TextStyle(
              fontSize: 22, // Make text bigger
              fontWeight: FontWeight.bold, // Make text bold
              color: Color.fromRGBO(24, 71, 137, 1), // Text color
            ),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0, // Optional, to remove the shadow
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌈 Intro Banner
                // Container(
                //   width: double.infinity,
                //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                //   decoration: BoxDecoration(
                //     gradient: LinearGradient(
                //       colors: [Color(0xFF184789), Color(0xFF2B69C4)],
                //       begin: Alignment.topLeft,
                //       end: Alignment.bottomRight,
                //     ),
                //   ),
                //   child: Row(
                //     children: [
                //       Icon(Icons.info_outline, color: Colors.white),
                //       SizedBox(width: 10),
                //       Expanded(
                //         child: Text(
                //           'Select 3 projects you’d like to include in this voting round.',
                //           style: TextStyle(color: Colors.white, fontSize: 15),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),

                // 📌 Section Header
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Available Projects',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF184789)),
                  ),
                ),
                SizedBox(height: 2),
                // 📋 Project List
                Expanded(
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final selected = _selectedProjectIndices.contains(index);

                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: GestureDetector(
                          onTap: () => _toggleSelection(index),
                          child: Card(
                            margin: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: selected ? 8 : 4,
                            color:
                                selected ? Colors.blue.shade50 : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
//                                   // 👤 Avatar Icon
//                                   CircleAvatar(
//   backgroundColor: Colors.grey, // A fresh green to show activity
//   child: Icon(Icons.rocket_launch, color: Colors.white),
// ),

//                                   SizedBox(width: 12),

                                      // 📛 Project Name
                                      Expanded(
                                        child: Text(
                                          project['name'],
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      // ✅ Selection Icon
                                      Icon(
                                        selected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: selected
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10),

                                  // 📝 Project Description
                                  Text(
                                    project['description'],
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 10),

                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStateColor(project['status'])
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        project['status'],
                                        style: TextStyle(
                                          color:
                                              _getStateColor(project['status']),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 🚀 Voting Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      // 📊 Selection Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedProjectIndices.length}/3 selected',
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                          // Icon(Icons.how_to_vote, color: Color(0xFF184789)),
                        ],
                      ),
                      SizedBox(height: 10),

                      ElevatedButton.icon(
                        onPressed: _initiateVotingProcess,
                        // icon: Icon(Icons.check_circle_outline),
                        label: Text(
                          'Confirm Projects Selection',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF184789),
                          padding: EdgeInsets.symmetric(
                              horizontal: 36, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class VoteListener {
  final int projectId; // <-- Add this line

  VoteListener({required this.projectId}); // <-- Add constructor

  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x2D2cDD99eff93AC01F825b45eE0844d44345F058';

  late Web3Client _client;
  late Credentials _credentials;
  late DeployedContract _contract;

  late String projectName;
  late String projectDescription;
  late DateTime startDate;
  late DateTime endDate;
  late double totalAmount;
  late double donatedAmount;
  late String organization;
  late String projectType;

  bool isEnded = false;

  final String contractABI = '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "getVotes",
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "name": "candidate",
        "type": "string"
      }
    ],
    "name": "vote",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "name": "voter",
        "type": "address"
      },
      {
        "indexed": true,
        "name": "candidate",
        "type": "string"
      }
    ],
    "name": "VoteCast",
    "type": "event"
  },
  {
    "constant": true,
    "inputs": [
      {
        "name": "votingId",
        "type": "uint256"
      }
    ],
    "name": "getVotingDetails",
    "outputs": [
      {
        "name": "projectNames",
        "type": "string[]"
      },
      {
        "name": "percentages",
        "type": "uint256[]"
      },
      {
        "name": "remainingMonths",
        "type": "uint256"
      },
      {
        "name": "remainingDays",
        "type": "uint256"
      },
      {
        "name": "remainingHours",
        "type": "uint256"
      },
      {
        "name": "remainingMinutes",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "name": "votingId",
        "type": "uint256"
      },
      {
        "name": "projectIndex",
        "type": "uint256"
      }
    ],
    "name": "fundProject",
    "outputs": [],
    "payable": true,
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "name": "votingId",
        "type": "uint256"
      }
    ],
    "name": "endVoting",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "name": "votingId",
        "type": "uint256"
      }
    ],
    "name": "cancelVoting",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {
        "name": "votingDuration",
        "type": "uint256"
      },
      {
        "name": "_projectIds",
        "type": "uint256[]"
      },
      {
        "name": "_projectNames",
        "type": "string[]"
      }
    ],
    "name": "initiateVoting",
    "outputs": [
      {
        "name": "",
        "type": "uint256"
      }
    ],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {
        "name": "votingId",
        "type": "uint256"
      },
      {
        "name": "donor",
        "type": "address"
      }
    ],
    "name": "hasAlreadyVoted",
    "outputs": [
      {
        "name": "",
        "type": "bool"
      }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  late ContractEvent voteCastEvent;
  StreamSubscription<FilterEvent>? _subscription;

  void initializeClient() {
    _client = Web3Client(rpcUrl, Client());
  }

  Future<void> _loadContract() async {
    final EthereumAddress contractAddr =
        EthereumAddress.fromHex(contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(contractABI, 'CharityVoting'),
      contractAddr,
    );
  }

  Future<void> initializeCredentials() async {
    String? privateKey = await _loadPrivateKey();
    if (privateKey == null) {
      print('Error: Unable to load private key.');
      return;
    }
    _credentials = await _client.credentialsFromPrivateKey(privateKey);
  }

  Future<String?> _loadPrivateKey() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('Error: Wallet address not found.');
        return null;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
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

  Future<String?> _loadWalletAddress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');
      return walletAddress;
    } catch (e) {
      print("Error loading wallet address: $e");
      return null;
    }
  }

  static Future<void> listenForVotingStatus(int votingId, int projectId) async {
    final listener = VoteListener(projectId: projectId);
    listener.initializeClient();

    final EthereumAddress contractAddr =
        EthereumAddress.fromHex(listener.contractAddress);

    final contract = DeployedContract(
      ContractAbi.fromJson(listener.contractABI, 'CharityVoting'),
      contractAddr,
    );

    final getVotingDetails = contract.function('getVotingDetails');

    try {
      print('🔊 Listening for voting status updates on ID: $votingId');

      // Repeatedly check every minute for voting status
      Timer.periodic(const Duration(minutes: 1), (timer) async {
        try {
          final result = await listener._client.call(
            contract: contract,
            function: getVotingDetails,
            params: [BigInt.from(votingId)],
          );

          final remainingMonths = result[2] as BigInt;
          final remainingDays = result[3] as BigInt;
          final remainingHours = result[4] as BigInt;
          final remainingMinutes = result[5] as BigInt;

          print('⏳ Voting Time Left: '
              '${remainingMonths.toInt()} months, '
              '${remainingDays.toInt()} days, '
              '${remainingHours.toInt()} hours, '
              '${remainingMinutes.toInt()} minutes');

          // If all values are zero or less, consider voting as ended
          if (remainingMonths <= BigInt.zero &&
              remainingDays <= BigInt.zero &&
              remainingHours <= BigInt.zero &&
              remainingMinutes <= BigInt.zero) {
            print('🛑 Voting ended for ID: $votingId');
            timer.cancel();
            await FirebaseFirestore.instance
                .collection('votings')
                .doc(votingId.toString())
                .set({'IsEnded': true}, SetOptions(merge: true));

            // Optionally, call transferFundsToWinner
            await listener.initializeCredentials();
            await listener._loadContract(); // helper to reload _contract
            await listener.fetchAndStoreProjectDetails();
            await listener.transferFundsToWinner(votingId, projectId);
          }
        } catch (e) {
          print('⚠️ Error checking voting status: $e');
          timer.cancel();
        }
      });
    } catch (e) {
      print('❌ Failed to start listening for voting status: $e');
    }
  }

  Future<void> setupVoteListener() async {
    try {
      initializeClient();
      await initializeCredentials();

      final EthereumAddress contractAddr =
          EthereumAddress.fromHex(contractAddress);

      _contract = DeployedContract(
        ContractAbi.fromJson(contractABI, 'CharityVoting'),
        contractAddr,
      );

      voteCastEvent = _contract.event('VoteCast');

      final filter = FilterOptions.events(
        contract: _contract,
        event: voteCastEvent,
      );

      _subscription = _client.events(filter).listen((event) {
        final decoded = voteCastEvent.decodeResults(event.topics!, event.data!);
        final voter = decoded[0] as EthereumAddress;
        final candidate = decoded[1] as String;

        print('📢 VoteCast event received!');
        print('🧑 Voter: $voter');
        print('📥 Candidate: $candidate');
      });

      print("📡 Listening for VoteCast events...");
    } catch (e) {
      print("🚨 Error setting up VoteCast listener: $e");
    }
  }

  void cancelListener() {
    _subscription?.cancel();
    print("❌ VoteCast listener cancelled.");
  }

  Future<void> transferFundsToWinner(int votingId, int senderProjectId) async {
    try {
      print(
          "🚀 Starting fund transfer process for voting ID: $votingId, Sender Project ID: $senderProjectId");

      final getVotingDetails = _contract.function('getVotingDetails');

      // Step 1: Fetch voting details from smart contract
      final votingDetails = await _client.call(
        contract: _contract,
        function: getVotingDetails,
        params: [BigInt.from(votingId)],
      );

      final projectNames = (votingDetails[0] as List).cast<String>();
      final percentages = (votingDetails[1] as List).cast<BigInt>();

      print("📋 Retrieved Project Names: $projectNames");
      print("📊 Retrieved Percentages: $percentages");

      // Step 2: Determine the winning project
      int winningIndex = -1;
      BigInt maxPercentage = BigInt.zero;

      for (int i = 0; i < percentages.length; i++) {
        if (percentages[i] > maxPercentage) {
          maxPercentage = percentages[i];
          winningIndex = i;
        }
      }

      if (winningIndex == -1) {
        print("❌ No winning project found (no votes cast).");
        return;
      }

      final winnerName = projectNames[winningIndex];
      print("🏆 Winning project: $winnerName");

      // Step 3: Fetch project IDs from Firestore
      final votingDoc = await FirebaseFirestore.instance
          .collection('votings')
          .doc(votingId.toString())
          .get();
      final List<dynamic>? projectIds = votingDoc.data()?['projectIds'];

      if (projectIds == null || winningIndex >= projectIds.length) {
        print("❌ Could not find matching project ID for winner in Firestore.");
        return;
      }

      final int winnerProjectId = projectIds[winningIndex];
      print("🏷️ Winner project ID: $winnerProjectId");

      // Step 4: Get winner wallet address
      final winnerDetails =
          await BlockchainService().getProjectDetails(winnerProjectId);
      if (winnerDetails.containsKey("error")) {
        print(
            "❌ Error fetching winner project details: ${winnerDetails["error"]}");
        return;
      }

      final String receiverWalletAddress = winnerDetails["organization"];
      print("🏦 Winner's wallet address: $receiverWalletAddress");

      // Step 5: Get sender wallet address (from project ID)
      final senderDetails =
          await BlockchainService().getProjectDetails(senderProjectId);
      if (senderDetails.containsKey("error")) {
        print(
            "❌ Error fetching sender project details: ${senderDetails["error"]}");
        return;
      }

      final String senderWalletAddress = senderDetails["organization"];
      print("🏦 Sender's wallet address: $senderWalletAddress");

      // Step 6: Use DonationService to perform the transaction
      final donationService = DonationService(
        senderAddress: senderWalletAddress,
        receiverAddress: receiverWalletAddress,
      );

      await donationService.initializeContract();

      final txHash = await donationService.transferFundsBetweenProjects(
          senderProjectId, winnerProjectId);

      print(
          "✅ Funds successfully transferred to winning project. Transaction Hash: $txHash");
    } catch (e, stackTrace) {
      print("🚨 Exception during fund transfer: $e");
      print("🧯 Stacktrace: $stackTrace");
    }
  }

  Future<void> fetchAndStoreProjectDetails() async {
    final blockchainService = BlockchainService();

    final details = await blockchainService.getProjectDetails(projectId);

    if (details.containsKey("error")) {
      print(details["error"]);
      return;
    }

    projectName = details["name"];
    projectDescription = details["description"];
    startDate = details["startDate"];
    endDate = details["endDate"];
    totalAmount = details["totalAmount"];
    donatedAmount = details["donatedAmount"];
    organization = details["organization"];
    projectType = details["projectType"];

    print("📦 Project details loaded successfully for project ID: $projectId");
    print("📝 Name: $projectName");
    print("📄 Description: $projectDescription");
    print("📅 Start Date: $startDate");
    print("📅 End Date: $endDate");
    print("💰 Total Amount: $totalAmount");
    print("🎁 Donated Amount: $donatedAmount");
    print("🏢 Organization: $organization");
    print("🏷️ Project Type: $projectType");
  }

  Future<bool> hasDonorAlreadyVoted(
      int votingId, EthereumAddress donorAddress) async {
    initializeClient();
    await initializeCredentials();

    final EthereumAddress contractAddr =
        EthereumAddress.fromHex(contractAddress);

    _contract = DeployedContract(
      ContractAbi.fromJson(contractABI, 'CharityVoting'),
      contractAddr,
    );

    final function = _contract.function('hasAlreadyVoted');

    final result = await _client.call(
      contract: _contract,
      function: function,
      params: [BigInt.from(votingId), donorAddress],
    );

    return result.first as bool;
  }
}

class DonationService {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x94F3a1791df973Bd599EC2a448e2F1A52e1cF5E3';

  final String senderAddress;
  final String receiverAddress;

  late Web3Client ethClient;
  late DeployedContract contract;
  late EthereumAddress senderEthAddress;
  late Credentials credentials;

  DonationService({
    required this.senderAddress,
    required this.receiverAddress,
  }) {
    ethClient = Web3Client(rpcUrl, Client());
  }

  Future<void> initializeContract() async {
    final abi = '''
[
  {
    "inputs": [
      { "internalType": "uint256", "name": "fromProjectId", "type": "uint256" },
      { "internalType": "uint256", "name": "toProjectId", "type": "uint256" }
    ],
    "name": "transferProjectFundsToAnother",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "projectId", "type": "uint256" }
    ],
    "name": "updateDonatedAmount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]
''';

    final privateKey = await _loadPrivateKey();
    if (privateKey == null) {
      throw Exception(
          "Private key not found. Please ensure the wallet is connected.");
    }

    credentials = EthPrivateKey.fromHex(privateKey);
    senderEthAddress = EthereumAddress.fromHex(senderAddress);

    contract = DeployedContract(
      ContractAbi.fromJson(abi, "DonationContract"),
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<String> transferFundsBetweenProjects(
      int fromProjectId, int toProjectId) async {
    final transferFunction = contract.function("transferProjectFundsToAnother");

    try {
      final encodedData = transferFunction.encodeCall([
        BigInt.from(fromProjectId),
        BigInt.from(toProjectId),
      ]);

      print(
          '🚀 Sending transaction for transferring funds from project $fromProjectId to $toProjectId');

      final txHash = await ethClient.sendTransaction(
        credentials,
        web3.Transaction(
          to: contract.address,
          gasPrice: await ethClient
              .getGasPrice(), // use latest gas price from network
          maxGas: 300000,
          data: encodedData,
        ),
        chainId: 11155111,
        fetchChainIdFromNetworkId: false,
      );

      print('🔗 Transaction submitted. Hash: $txHash');

      final receipt = await _waitForReceipt(txHash);
      if (receipt == null) {
        throw Exception(
            "⏳ Transaction not confirmed in time. Tx hash: $txHash");
      }

      print('✅ Transaction confirmed. Block: ${receipt.blockNumber}');

      // Update the donated amount after funds transfer
      await _updateProjectDonatedAmount(fromProjectId);
      await _updateProjectDonatedAmount(toProjectId);

      return txHash;
    } catch (e, stack) {
      print('❌ Error transferring funds: $e');
      print('🧯 Stacktrace: $stack');
      rethrow;
    }
  }

  Future<void> _updateProjectDonatedAmount(int projectId) async {
    final updateFunction = contract.function("updateDonatedAmount");

    try {
      final encodedData = updateFunction.encodeCall([BigInt.from(projectId)]);

      print('🚀 Updating donated amount for project $projectId');

      final txHash = await ethClient.sendTransaction(
        credentials,
        web3.Transaction(
          to: contract.address,
          gasPrice: await ethClient
              .getGasPrice(), // use latest gas price from network
          maxGas: 300000,
          data: encodedData,
        ),
        chainId: 11155111,
        fetchChainIdFromNetworkId: false,
      );

      print('🔗 Donation amount update transaction submitted. Hash: $txHash');

      final receipt = await _waitForReceipt(txHash);
      if (receipt == null) {
        throw Exception(
            "⏳ Donation amount update not confirmed in time. Tx hash: $txHash");
      }

      print('✅ Donation amount updated successfully for project $projectId');
    } catch (e, stack) {
      print('❌ Error updating donated amount for project $projectId: $e');
      print('🧯 Stacktrace: $stack');
      rethrow;
    }
  }

// Optimized version without delay, faster mining confirmation loop
  Future<web3.TransactionReceipt?> _waitForReceipt(
    String txHash, {
    int retries = 40,
  }) async {
    print('🔍 Waiting for transaction $txHash to be mined...');

    for (int i = 0; i < retries; i++) {
      final receipt = await ethClient.getTransactionReceipt(txHash);

      if (receipt != null) {
        print('✅ Receipt found at attempt $i');
        return receipt;
      }

      // Yield to event loop to prevent UI blocking without fixed delay
      await Future.delayed(Duration(milliseconds: 500));
    }

    print('❌ Failed to get receipt after $retries attempts for $txHash');
    return null;
  }

  // Loads private key from SharedPreferences
  Future<String?> _loadPrivateKey() async {
    print('🔐 Loading private key...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('❌ Wallet address not found.');
        return null;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      print('🔍 Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
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

  // Loads the wallet address from SharedPreferences
  Future<String?> _loadWalletAddress() async {
    print('🔄 Loading wallet address...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("❌ Wallet address not found. Please log in again.");
        return null;
      }

      print('✅ Wallet address loaded: $walletAddress');
      return walletAddress;
    } catch (e) {
      print("⚠️ Error loading wallet address: $e");
      return null;
    }
  }
}
