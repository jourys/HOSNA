import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/EditDonorProfile.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart'; // To make HTTP requests
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';


class ProfileScreenTwo extends StatefulWidget {
  const ProfileScreenTwo({super.key});

  @override
  _ProfileScreenTwoState createState() => _ProfileScreenTwoState();
}

class _ProfileScreenTwoState extends State<ProfileScreenTwo> {
  late Web3Client _web3Client; // For blockchain connection
String _donorAddress = '';
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  int? userType;
  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x761a4F03a743faf9c0Eb3440ffeAB086Bd099fbc';
String? _profilePictureUrl;


  @override
  void initState() {
    super.initState();
    _getUserType();
    _initializeWeb3();
    _fetchProfilePicture();
    _getDonorData();
 }

 Future<void> _fetchProfilePicture() async {
  print('🔄 Fetching profile picture for donor: $_donorAddress');

  if (_donorAddress.isEmpty) {
    print('⚠️ Donor address is empty. Cannot fetch profile picture.');
    return;
  }

  try {
    print('📡 Querying Firestore for user document...');
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_donorAddress)
        .get();

    print('📄 Firestore Document Retrieved: ${userDoc.exists ? "Exists ✅" : "Not Found ❌"}');

    if (userDoc.exists) {
      if (userDoc.data() != null) {
        print('📑 Firestore Data: ${userDoc.data()}');
      } else {
        print('⚠️ Document exists but contains no data.');
      }

      if (userDoc['profile_picture'] != null) {
        String profileUrl = userDoc['profile_picture'];
        print('✅ Profile picture URL fetched: $profileUrl');

        setState(() {
          _profilePictureUrl = profileUrl;
        });
      } else {
        print('⚠️ No profile picture found in Firestore document.');
      }
    } else {
      print('❌ User document does not exist in Firestore.');
    }
  } catch (e) {
    print('❌ Error fetching profile picture: $e');
  }
}

  Future<void> _getUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getInt('userType');
    });

    print("All keys: ${prefs.getKeys()}");
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    final prefs = await SharedPreferences.getInstance();
    _donorAddress = prefs.getString('walletAddress') ?? '';
    // String? userType = prefs.getString('userType');

    if (_donorAddress.isNotEmpty) {
      print("🔍 Loaded Wallet Address: $_donorAddress");
      print("🔍 Loaded User Type: $userType");
      await _getDonorData();
    } else {
      print("⚠️ No wallet address found in SharedPreferences");
    }
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
    {
      "constant": true,
      "inputs": [{"name": "_wallet", "type": "address"}],
      "name": "getDonor",
      "outputs": [
        {"name": "firstName", "type": "string"},
        {"name": "lastName", "type": "string"},
        {"name": "email", "type": "string"},
        {"name": "phone", "type": "string"},
        {"name": "walletAddress", "type": "address"},
        {"name": "registered", "type": "bool"}
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

    return DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );
  }
Future<void> _getDonorData() async {
  print("🔄 Checking donor address: $_donorAddress");
 _fetchProfilePicture();
  if (_donorAddress.isEmpty) {
    print("⚠️ No donor wallet address found.");
    return;
  }

  try {
    print("📡 Fetching contract...");
    final contract = await _loadContract();
    final function = contract.function('getDonor');

    print("📡 Fetching donor data for $_donorAddress...");

    final result = await _web3Client.call(
      contract: contract,
      function: function,
      params: [EthereumAddress.fromHex(_donorAddress)],
    );

    print("🟢 Raw Result: $result"); // ✅ Debugging the response

    if (result.isEmpty) {
      print("❌ Donor data is empty! Wallet: $_donorAddress");
      return;
    }

    bool isRegistered = result[5] as bool;
    if (!isRegistered) {
      print("❌ Donor is not registered in the blockchain!");
      return;
    }

    setState(() {
      _firstName = result[0] as String;
      _lastName = result[1] as String;
      _email = result[2] as String;
      _phone = result[3] as String;
    });

    print("✅ Donor data retrieved successfully!");
  } catch (e) {
    print("❌ Error fetching donor data: $e");
  }
}


  Future<List<dynamic>> _callGetDonorMethod(DeployedContract contract,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                    builder: (context) => EditDonorProfileScreen(
                      firstName: _firstName,
                      lastName: _lastName,
                      email: _email,
                      phone: _phone,
                    ),
                  ),
                );

                if (result == true) {
                  print("🔄 Refreshing profile after edit...");
                  await _getDonorData(); // ✅ Fetch fresh data from blockchain
                  setState(() {}); // ✅ Forces a rebuild with new data
                }
              }),
        ],
        // Setting the height of the AppBar using preferredSize
        toolbarHeight: 80, // Adjust the height here
      ),
      body: Container(
        color: Colors.blue[900],
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.all(50),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
              radius: 38,
              backgroundColor: Colors.transparent,
              backgroundImage: _profilePictureUrl != null
                  ? NetworkImage(_profilePictureUrl!)
                  : null,
              child: _profilePictureUrl == null
                  ? Icon(Icons.account_circle, size: 100, color: Colors.grey)
                  : null,
            ),
              SizedBox(height: 30),
              Text('$_firstName $_lastName',
                  style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              SizedBox(height: 50),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      infoRow('Phone Number : ', _phone),
                      infoRow('Email : ', _email),
                      SizedBox(height: 200),
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
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const UsersPage()),
                                );
                              },
                              child: const Text(
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
                                        color: Colors.blue[900]!,
                                      ),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24)))),
                            )),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                            height: MediaQuery.of(context).size.height * .066,
                            width: MediaQuery.of(context).size.width * .8,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Text(
                                'Delete Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20, // Increase the font size here
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24)))),
                            )),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.blue[900],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
