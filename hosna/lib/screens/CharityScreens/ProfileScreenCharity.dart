import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:hosna/screens/CharityScreens/_EditProfileScreenState.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:web3dart/web3dart.dart' as web3;

class ProfileScreenCharity extends StatefulWidget {
  const ProfileScreenCharity({super.key});

  @override
  _ProfileScreenCharityState createState() => _ProfileScreenCharityState();
}

class _ProfileScreenCharityState extends State<ProfileScreenCharity> {
  late Web3Client _web3Client; // For blockchain connection
  late String _charityAddress; // Wallet address of the charity
  String _organizationName = '';
  String _email = '';
  String _phone = '';
  String _licenseNumber = '';
  String _organizationCity = '';
  String _organizationURL = '';
  String _establishmentDate = '';
  String _description = '';
  String _profilePictureUrl = '';

  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x25ef93ac312D387fdDeFD62CD852a29328c4B122';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _initializeWeb3();
    await _loadProfilePicture(); // 🔹 Fetch profile picture from Firestore
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    final prefs = await SharedPreferences.getInstance();
    _charityAddress = prefs.getString('walletAddress') ?? '';
    print("Retrieved Wallet Address from SharedPreferences: $_charityAddress");

    if (_charityAddress.isEmpty || _charityAddress == "none") {
      print("Wallet address is invalid or missing. Please log in again.");
      return;
    }

    await _getCharityData();
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
      {
        "constant": true,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "getCharity",
        "outputs": [
          {"name": "organizationName", "type": "string"},
          {"name": "email", "type": "string"},
          {"name": "phone", "type": "string"},
          {"name": "licenseNumber", "type": "string"},
          {"name": "city", "type": "string"},
          {"name": "website", "type": "string"},
          {"name": "establishmentDate", "type": "string"},
          {"name": "description", "type": "string"}
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'CharityRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  Future<void> _loadProfilePicture() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_charityAddress)
          .get();

      if (doc.exists && doc.data()?.containsKey('profilepicture') == true) {
        setState(() {
          _profilePictureUrl = doc.data()!['profilepicture'];
        });
      }
    } catch (e) {
      print('Error loading profile picture from users collection: $e');
    }
  }

  Future<void> deleteCharityAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('walletAddress');

    if (walletAddress == null || walletAddress.isEmpty) {
      print("Wallet address not found.");
      return;
    }

    // Step 1: Fetch all projects for the charity
    final blockchainService = BlockchainService();
    List<Map<String, dynamic>> projects =
        await blockchainService.fetchOrganizationProjects(walletAddress);

    // 🔹 Step 2: Check for active projects
    for (final project in projects) {
      String state = await _getProjectState(project);
      if (state == "active" ||
          state == "canceled" ||
          state == "failed" ||
          state == "voting" ||
          state == "in-progress") {
        print(
            "You cannot delete your account while having active, canceled, failed, voting, or in-progress projects.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "You cannot delete your account while having active, canceled, failed, voting, or in-progress projects.")),
        );
        return;
      }
    }

    // 🔹 Step 3: Proceed with deletion (same as before)
    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[
        {
          "constant": false,
          "inputs": [{"name": "_wallet", "type": "address"}],
          "name": "deleteCharity",
          "outputs": [],
          "payable": false,
          "stateMutability": "nonpayable",
          "type": "function"
        }
      ]''',
        'CharityRegistry',
      ),
      EthereumAddress.fromHex(contractAddress),
    );

    final deleteFunction = contract.function('deleteCharity');

    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('walletAddress');

// Check for null or empty
      if (walletAddress == null || walletAddress.isEmpty) {
        print("Wallet address not found.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Wallet address not found. Please log in again.")),
        );
        return;
      }

// Now safe to use
      final credentials = EthPrivateKey.fromHex(prefs.getString('privateKey') ??
          prefs.getString('privateKey_$walletAddress') ??
          '');

      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[
      {
        "constant": false,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "deleteCharity",
        "outputs": [],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
      }
    ]''',
          'CharityRegistry',
        ),
        EthereumAddress.fromHex(contractAddress),
      );

// ✅ No error here now
      await _web3Client.sendTransaction(
        credentials,
        web3.Transaction.callContract(
          contract: contract,
          function: contract.function('deleteCharity'),
          parameters: [
            EthereumAddress.fromHex(walletAddress)
          ], // walletAddress is now non-null
          maxGas: 200000,
        ),
        chainId: 11155111,
      );
      await _web3Client.sendTransaction(
        credentials,
        web3.Transaction.callContract(
          contract: contract,
          function: deleteFunction,
          parameters: [web3.EthereumAddress.fromHex(walletAddress)],
          maxGas: 200000,
        ),
        chainId: 11155111,
      );

      print("✅ Deleted from blockchain");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .delete();
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) await user.delete();
      } catch (_) {}

      await prefs.clear();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => UsersPage()),
        (route) => false,
      );
    } catch (e) {
      print("Error deleting account: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();
    String projectId = project['id'].toString(); // Ensure it's a String

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!doc.exists) {
        print("⚠️ Project not found. Creating default fields...");
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .set({
          'isCanceled': false,
          'isCompleted': false,
          'isEnded': false,
          'votingInitiated': false,
        });
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};

      bool isCanceled = data['isCanceled'] ?? false;
      bool isCompleted = data['isCompleted'] ?? false;
      bool isEnded = false;
      final votingId = data['votingId'];

      if (votingId != null) {
        final votingDocRef = FirebaseFirestore.instance
            .collection("votings")
            .doc(votingId.toString());

        final votingDoc = await votingDocRef.get();
        final votingData = votingDoc.data();

        if (votingDoc.exists) {
          isEnded = votingData?['IsEnded'] ?? false;
        }
      }
      bool votingInitiated = data['votingInitiated'] ?? false;

      // Determine projectState based on Firestore flags
      if (isEnded) {
        return "ended";
      }
      if (isCompleted) {
        return "completed";
      } else if (votingInitiated && (!isCompleted) && (!isEnded)) {
        return "voting";
      } else if (isCanceled && (!votingInitiated) && (!isEnded)) {
        return "canceled";
      }

      // Fallback to logic based on time and funding progress
      DateTime startDate = project['startDate'] != null
          ? (project['startDate'] is DateTime
              ? project['startDate']
              : DateTime.parse(project['startDate']))
          : DateTime.now();

      DateTime endDate = project['endDate'] != null
          ? (project['endDate'] is DateTime
              ? project['endDate']
              : DateTime.parse(project['endDate']))
          : DateTime.now();

      double totalAmount = (project['totalAmount'] ?? 0).toDouble();
      double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

      if (now.isBefore(startDate)) {
        return "upcoming";
      } else if (donatedAmount >= totalAmount) {
        return "in-progress";
      } else if (now.isAfter(endDate)) {
        return "failed";
      } else {
        return "active";
      }
    } catch (e) {
      print("Error determining project state for ID $projectId: $e");
      return "unknown";
    }
  }

  Future<bool> _showAccountDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Confirm Deletion',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'Are you sure you want to delete your account?',
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
                        side: const BorderSide(
                          color: Color.fromRGBO(24, 71, 137, 1),
                          width: 3,
                        ),
                        backgroundColor: Colors.white,
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
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
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

  Future<void> _getCharityData() async {
    try {
      final contract = await _loadContract();

      print("🔹 Fetching data for wallet: $_charityAddress");

      final result = await _callGetCharityMethod(contract, 'getCharity', [
        EthereumAddress.fromHex(_charityAddress),
      ]);

      print("📌 Raw Result: $result");

      if (result != null && result.isNotEmpty) {
        setState(() {
          _organizationName = result[0].toString();
          _email = result[1].toString();
          _phone = result[2].toString();
          _licenseNumber = result[3].toString();
          _organizationCity = result[4].toString();
          _description = result[5].toString();
          _organizationURL = result[6].toString();
          _establishmentDate = result[7].toString();
        });
      } else {
        print("No charity data found for wallet: $_charityAddress");
      }
    } catch (e) {
      print("Error fetching charity data: $e");
    }
  }

  Future<List<dynamic>> _callGetCharityMethod(DeployedContract contract,
      String methodName, List<dynamic> params) async {
    try {
      final function = contract.function(methodName);
      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: params,
      );
      return result;
    } catch (e) {
      print("Error calling contract method: $e");
      return [];
    }
  }

  Future<bool> _showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Confirm Logout',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'Are you sure you want to log out?',
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
                        side: const BorderSide(
                          color: Color.fromRGBO(24, 71, 137, 1),
                          width: 3,
                        ),
                        backgroundColor: Colors.white,
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
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            // ✅ Navigate to home page if returning after edit
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => CharityMainScreen()),
            );
          },
        ),
        title: Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    organizationName: _organizationName,
                    email: _email,
                    phone: _phone,
                    licenseNumber: _licenseNumber,
                    organizationCity: _organizationCity,
                    organizationURL: _organizationURL,
                    establishmentDate: _establishmentDate,
                    description: _description,
                  ),
                ),
              );

              if (result == true) {
                print("🔄 Refreshing profile after edit...");
                await _getCharityData();
                await _loadProfilePicture();
              }
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.blue[900],
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                backgroundImage: _profilePictureUrl.isNotEmpty
                    ? NetworkImage(_profilePictureUrl)
                    : null,
                child: _profilePictureUrl.isEmpty
                    ? Icon(Icons.business, size: 60, color: Colors.blue[900])
                    : null,
              ),
              SizedBox(height: 30),
              Text(_organizationName,
                  style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Expanded(
                child: Scrollbar(
                  // Add scrollbar here
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        InfoRow(title: 'Phone', value: _phone),
                        InfoRow(title: 'Email', value: _email),
                        InfoRow(title: 'License Number', value: _licenseNumber),
                        InfoRow(title: 'City', value: _organizationCity),
                        InfoRow(title: 'Website', value: _organizationURL),
                        InfoRow(title: 'Founded ', value: _establishmentDate),
                        InfoRow(title: 'About us', value: _description),
                        SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                              height: MediaQuery.of(context).size.height * .066,
                              width: MediaQuery.of(context).size.width * .8,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirm =
                                      await _showLogoutConfirmation(context);
                                  if (!confirm) return;

                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();

                                  // Retrieve private key and wallet address before clearing session data
                                  String? privateKey =
                                      prefs.getString('privateKey');
                                  String? walletAddress =
                                      prefs.getString('walletAddress');

                                  // Clear session-related data
                                  await prefs.remove('userSession');

                                  // Restore private key and wallet address
                                  if (privateKey != null) {
                                    await prefs.setString(
                                        'privateKey', privateKey);
                                  }
                                  if (walletAddress != null) {
                                    await prefs.setString(
                                        'walletAddress', walletAddress);
                                  }

                                  print(
                                      'User logged out. Session cleared but private key and wallet address retained.');

                                  // Navigate to UsersPage
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => UsersPage()),
                                    (route) => false,
                                  );
                                },
                                child: Text(
                                  'Log out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue[900],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.blue[900]!),
                                  ),
                                ),
                              )),
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                              height: MediaQuery.of(context).size.height * .066,
                              width: MediaQuery.of(context).size.width * .8,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirm =
                                      await _showAccountDeleteConfirmation(
                                          context);
                                  if (confirm) {
                                    await deleteCharityAccount();
                                  }
                                },
                                child: Text(
                                  'Delete Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.red[800]!),
                                  ),
                                ),
                              )),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatefulWidget {
  final String title;
  final String value;

  const InfoRow({super.key, required this.title, required this.value});

  @override
  State<InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<InfoRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool isLong = widget.value.length > 40;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label and Value in a Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
                // Value
                Expanded(
                  flex: 5,
                  child: Text(
                    _isExpanded || !isLong
                        ? widget.value
                        : widget.value.length > 60
                            ? widget.value.substring(0, 60) + '...'
                            : widget.value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            ),
            // "More"/"Less" button
            if (isLong)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Text(
                    _isExpanded ? "less" : "more",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
