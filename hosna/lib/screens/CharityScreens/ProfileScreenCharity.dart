import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:hosna/screens/CharityScreens/_EditProfileScreenState.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
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
  final String contractAddress = '0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7';

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
    print(
        "🟢 Retrieved Wallet Address from SharedPreferences: $_charityAddress");

    if (_charityAddress.isEmpty || _charityAddress == "none") {
      print("❌ Wallet address is invalid or missing. Please log in again.");
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
          .collection('charities')
          .doc(_charityAddress)
          .get();

      if (doc.exists && doc.data()?.containsKey('profile_picture') == true) {
        setState(() {
          _profilePictureUrl = doc.data()!['profile_picture'];
        });
      }
    } catch (e) {
      print('❌ Error loading profile picture: $e');
    }
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
        print("❌ No charity data found for wallet: $_charityAddress");
      }
    } catch (e) {
      print("❌ Error fetching charity data: $e");
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

  Future<void> deleteCharityAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('walletAddress');

    if (walletAddress == null || walletAddress.isEmpty) {
      print("❌ Wallet address not found.");
      return;
    }

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
      final credentials = EthPrivateKey.fromHex(
          "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90"); //  Replace securely
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

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .delete();

      print("✅ Deleted from Firestore");

      // Delete from Firebase Auth (optional)
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.delete();
          print("✅ Firebase Auth user deleted");
        }
      } catch (e) {
        print("⚠️ Firebase Auth deletion skipped: $e");
      }

      await prefs.clear(); // Clear all storage
      print("✅ SharedPreferences cleared");

      // Navigate to Users page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => UsersPage()),
        (route) => false,
      );
    } catch (e) {
      print("❌ Error deleting account: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting account: $e")),
      );
    }
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
                backgroundColor: Colors.grey[300],
                backgroundImage: _profilePictureUrl.isNotEmpty
                    ? NetworkImage(_profilePictureUrl)
                    : null,
                child: _profilePictureUrl.isEmpty
                    ? Icon(Icons.business, size: 100, color: Colors.white)
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
                        InfoRow(title: 'phone : ', value: _phone), // Phone
                        InfoRow(title: 'Email : ', value: _email), // Email
                        InfoRow(
                            title: 'License : ',
                            value: _licenseNumber), // License Number
                        InfoRow(
                            title: 'Location : ',
                            value: _organizationCity), // City
                        InfoRow(
                            title: 'Website : ',
                            value: _organizationURL), // Website
                        InfoRow(
                            title: 'Founded : ',
                            value: _establishmentDate), // Establishment Date
                        InfoRow(
                            title: 'About : ',
                            value: _description), // Description

                        SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                              height: MediaQuery.of(context).size.height * .066,
                              width: MediaQuery.of(context).size.width * .8,
                              child: ElevatedButton(
                                onPressed: () async {
                                  SharedPreferences prefs =
                                      await SharedPreferences.getInstance();

                                  // Retrieve private key and wallet address before clearing session data
                                  String? privateKey =
                                      prefs.getString('privateKey');
                                  String? walletAddress =
                                      prefs.getString('walletAddress');

                                  // Clear all session-related data (but keep the private key and wallet address)
                                  await prefs.remove(
                                      'userSession'); // Remove any session data you want cleared

                                  // If we have the private key and wallet address, restore them
                                  if (privateKey != null) {
                                    await prefs.setString(
                                        'privateKey', privateKey);
                                  }
                                  if (walletAddress != null) {
                                    await prefs.setString(
                                        'walletAddress', walletAddress);
                                  }

                                  print(
                                      '✅ User logged out. Session cleared but private key and wallet address retained.');

                                  // Navigate to UsersPage
                                 Navigator.pushAndRemoveUntil(
                                      context,
    MaterialPageRoute(builder: (context) => UsersPage()),
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
                                        side: BorderSide(
                                            color: Colors.blue[900]!),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(24)))),
                              )),
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                              height: MediaQuery.of(context).size.height * .066,
                              width: MediaQuery.of(context).size.width * .8,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text("Confirm Deletion"),
                                      content: Text(
                                          "Are you sure you want to delete your account? This action cannot be undone."),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text("Cancel")),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text("Delete")),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
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
                                        side:
                                            BorderSide(color: Colors.red[900]!),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(24)))),
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
                      fontWeight: FontWeight.w600,
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
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
                      color: Colors.blue[900],
                      fontWeight: FontWeight.w600,
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
