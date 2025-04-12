import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart'; // Import Client from the http package
import 'dart:convert';  // Import for utf8 and hex encoding
import 'dart:typed_data';  // Required to use Uint8List
import 'dart:convert'; // Optional if you need other encoding
import 'package:hosna/screens/CharityScreens/projectDetails.dart';




class InitiateVoting extends StatefulWidget {
  final String walletAddress;
  final int projectId;
  const InitiateVoting({super.key, required this.walletAddress , required this.projectId});

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
  late ContractFunction _startVotingFunction; // Function to call in the contract
  late Credentials _credentials; // Credentials for interacting with blockchain
  bool _isBlockchainReady = false; // NEW: Flag to indicate blockchain is ready
  bool votingInitiated = false;final String contractABI = '''[
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


Future<void> _initializeBlockchain() async {
  try {
    print('Initializing blockchain...');
    
    // Initialize the Web3Client
    _web3Client = Web3Client('https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1', Client());
    print('Web3 client initialized.');

    // Set the contract address
    _contractAddress = EthereumAddress.fromHex('0x619038eB1634155b26CB927ad09b5Fc14A6082cb');
    print('Contract address set to $_contractAddress');

    // Load the contract
    _contract = DeployedContract(ContractAbi.fromJson(contractABI, 'CharityVoting'), _contractAddress);
    print('Contract loaded.');

    // Extract the function 'startVoting' (matching the ABI)
    _startVotingFunction = _contract.function('initiateVoting'); // Use 'startVoting' here
    print('Function extracted: startVoting');

    // Set the blockchain readiness flag
    _isBlockchainReady = true;
    print('Blockchain is now ready ✅');
  } catch (e) {
    print('Error initializing blockchain: $e');
  }
}


Future<void> _initiateVotingOnBlockchain() async {
  print('🚀 Initiating voting process...');
  print('🧮 Selected projects count: ${_selectedProjects.length}');
  print('📆 Start date: $_startDate | End date: $_endDate');
  print('✅ Blockchain ready? $_isBlockchainReady');

  // Quick inline function to show snackbars
  void showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Validation checks
  if (_selectedProjects.isEmpty || _startDate == null || _endDate == null) {
    print('❗ Validation failed: Need exactly 3 projects and valid start/end dates.');
    showWarning('⚠️ Please select 3 projects and valid start and end dates.');
    return;
  }

  if (!_isBlockchainReady) {
    print('🛑 Blockchain not ready yet. Aborting...');
    showWarning('⏳ Blockchain is not ready yet. Please wait...');
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
      return;
    }

    final votingDuration = BigInt.from(votingDurationSeconds);
    print('📅 Voting Duration (s): $votingDuration');

    final projectIds = <BigInt>[];
    final projectNames = <String>[];

    // Collect project IDs and names, ensuring data validity
    for (final proj in _selectedProjects) {
      final id = proj['id'];
      final name = proj['name'];

      // Ensure data is valid before adding to lists
      if (id is int && name is String) {
        projectIds.add(BigInt.from(id));
        projectNames.add(name);
      } else {
        print('❗ Invalid project data: id=$id, name=$name');
        showWarning('⚠️ Invalid project data. Please try again.');
        return;
      }
    }

    if (projectIds.isEmpty || projectNames.isEmpty) {
      print('❗ No valid projects selected');
      showWarning('⚠️ No valid projects selected. Please try again.');
      return;
    }

    print('🔍 Project IDs: $projectIds');
    print('🔍 Project Names: $projectNames');

    print('🧾 Creating transaction...');
    try {
  final txHash = await _web3Client.sendTransaction(
    _credentials,
    web3.Transaction(
      to: _contract.address,
      gasPrice: EtherAmount.fromUnitAndValue(EtherUnit.gwei, 120),  // Higher gas price
      maxGas: 500000,
      data: _contract.function('initiateVoting').encodeCall([votingDuration, projectIds, projectNames]),
    ),
    chainId: 11155111,
  );
  print("✅ Transaction sent! Hash: $txHash");
} catch (e) {
  print("❌ Transaction failed: $e");
}



  

    // Retrieve the contract function to get the voting counter directly from the transaction return value
    final function = _contract.function('initiateVoting');
    final result = await _web3Client.call(
      contract: _contract,
      function: function,
      params: [votingDuration, projectIds, projectNames],
    );

    if (result.isEmpty) {
      print('❗ Error: Voting counter not found in contract.');
      showWarning('⚠️ Voting counter not found.');
      return;
    }

    final votingCounter = result[0].toString();  // The votingCounter is returned by the function
    print('🎉 Voting Counter (ID): $votingCounter');

    // Save the voting ID and initiate status to Firebase
await FirebaseFirestore.instance
    .collection('projects')
    .doc(widget.projectId.toString()) // Use the projectId as the document ID
    .set({
      'votingId': votingCounter, // Save the voting counter directly
      'votingInitiated': true,    // Add the 'votingInitiated' field
    }, SetOptions(merge: true)); // Merge to avoid overwriting existing data

print("✅ Voting ID and status saved to Firestore: $votingCounter");
await VoteListener.listenForVotingStatus(int.parse(votingCounter) , widget.projectId);
    print("✅ listener staarttttt");

    print("✅ Voting ID saved to Firestore: $votingCounter");
    showWarning('🗳️ Voting started successfully!');

    // Navigate back after successful voting initiation
    Navigator.pop(context, true);
    print('✅ Voting initiation process complete.');

  } catch (e) {
    print('❌ Error initiating voting: $e');
    showWarning('❗ Failed to initiate voting. Please try again.');
  }
}

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

  void _initiateVoting() {
    if (_selectedProjects.length != 3 || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select 3 projects and an end date.')),
      );
      return;
    }

    print("Voting started on ${DateFormat('yyyy-MM-dd').format(_startDate)}");
    print("Ends at $_endDate");
    _selectedProjects.forEach((p) => print(p['name']));

    _initiateVotingOnBlockchain();
  }

  void _openProjectSelection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSelectorPage(walletAddress: widget.walletAddress),
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

  @override
  Widget build(BuildContext context) {
final startDateFormatted = DateFormat('yyyy-MM-dd – HH:mm').format(_startDate);
    final endDateFormatted = _endDate != null
        ? DateFormat('yyyy-MM-dd – HH:mm').format(_endDate!)
        : 'Select End Date';

    return Scaffold(
      appBar: AppBar(
        title: Text('Initiate Voting'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔍 Search Icon
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(Icons.search, size: 30),
                onPressed: _openProjectSelection,
              ),
            ),

            // 🧱 Selected Projects Fields
            ...List.generate(3, (index) {
              return Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(vertical: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _selectedProjects.length > index
                      ? _selectedProjects[index]['name']
                      : 'Select Project ${index + 1}',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }),

            SizedBox(height: 20),

            // 📅 Start Date (disabled)
            TextFormField(
              initialValue: startDateFormatted,
              decoration: InputDecoration(
                labelText: 'Start Date',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),

            SizedBox(height: 16),

            // ⏳ End Date Picker
            GestureDetector(
              onTap: _pickEndDate,
              child: AbsorbPointer(
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'End Date (with time)',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: endDateFormatted),
                ),
              ),
            ),

            Spacer(),

            ElevatedButton(
              onPressed: _initiateVoting,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Initiate Voting'),
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
        title: Text('Initiate Voting'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select 3 Projects to Start a Voting Round',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final selected = _selectedProjectIndices.contains(index);
                      return GestureDetector(
                        onTap: () => _toggleSelection(index),
                        child: Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 4,
                          color: selected
                              ? Colors.blue.shade50
                              : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        project['name'],
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: selected
                                          ? Colors.green
                                          : Colors.grey,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  project['description'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Chip(
                                  label: Text(project['status']),
                                  backgroundColor:
                                      _getStateColor(project['status']),
                                  labelStyle: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _initiateVotingProcess,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Initiate Voting'),
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

  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x619038eB1634155b26CB927ad09b5Fc14A6082cb';

  late Web3Client _client;
  late Credentials _credentials;
  late DeployedContract _contract;

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
    }
  ]
  ''';

  late ContractEvent voteCastEvent;
  StreamSubscription<FilterEvent>? _subscription;

  void initializeClient() {
    _client = Web3Client(rpcUrl, Client());
  }

Future<void> _loadContract() async {
  final EthereumAddress contractAddr = EthereumAddress.fromHex(contractAddress);
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

          // Optionally, call transferFundsToWinner
          await listener.initializeCredentials();
          await listener._loadContract(); // helper to reload _contract
          await listener.transferFundsToWinner(votingId , projectId);
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

      final EthereumAddress contractAddr = EthereumAddress.fromHex(contractAddress);

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

    Future<void> transferFundsToWinner(int votingId, int projectId) async {
  try {
    print("🚀 Starting fund transfer process for voting ID: $votingId, Project ID: $projectId");

    final getVotingDetails = _contract.function('getVotingDetails');
    final fundProject = _contract.function('fundProject');

    // Fetch voting details
    final votingDetails = await _client.call(
      contract: _contract,
      function: getVotingDetails,
      params: [BigInt.from(votingId)],
    );

    final projectNames = (votingDetails[0] as List).cast<String>();
    final percentages = (votingDetails[1] as List).cast<BigInt>();

    print("📋 Retrieved Project Names: $projectNames");
    print("📊 Retrieved Percentages: $percentages");

    // Find the winning project
    int winningIndex = -1;
    BigInt maxPercentage = BigInt.zero;

    for (int i = 0; i < percentages.length; i++) {
      print("🔍 Checking project at index $i: ${projectNames[i]} with percentage ${percentages[i]}");
      if (percentages[i] > maxPercentage) {
        maxPercentage = percentages[i];
        winningIndex = i;
      }
    }

    if (winningIndex == -1) {
      print("❌ No project has votes.");
      return;
    }

    final receiver = projectNames[winningIndex];
    print("🏆 Winning project: $receiver (Index $winningIndex with ${maxPercentage.toInt()}%)");

    final donorServices = DonorServices();  // Initialize DonorServices

    // Fetch the total donations for the winning project using the provided projectId
    final amount = await donorServices.getProjectDonations(BigInt.from(projectId));  
    print("💰 Total donations: $amount");

    // Transfer funds to the winning project
    await _client.sendTransaction(
      _credentials,
      web3.Transaction.callContract(
        contract: _contract,
        function: fundProject,
        parameters: [BigInt.from(votingId), BigInt.from(winningIndex)],
        value: EtherAmount.inWei(BigInt.from(amount)),
      ),
      chainId: 11155111, // Sepolia
    );

    print("✅ Funds successfully transferred to the winning project: $receiver");
  } catch (e, stackTrace) {
    print("🚨 Exception occurred during fund transfer: $e");
    print("🧯 Stacktrace: $stackTrace");
  }
}


}

