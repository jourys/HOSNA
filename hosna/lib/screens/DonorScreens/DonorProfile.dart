import 'package:flutter/material.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart'; // To make HTTP requests
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class ProfileScreenTwo extends StatefulWidget {
  const ProfileScreenTwo({super.key});

  @override
  _ProfileScreenTwoState createState() => _ProfileScreenTwoState();
}

class _ProfileScreenTwoState extends State<ProfileScreenTwo> {
  late Web3Client _web3Client; // For blockchain connection
  late String _donorAddress; // Wallet address of the donor
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';

  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x84F41a8f4e9d394Ff77Df64FFCc4447BA17d7809';

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    // Retrieve wallet address from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _donorAddress = prefs.getString('walletAddress') ?? '';

    if (_donorAddress.isNotEmpty) {
      await _getDonorData();
    } else {
      print("No wallet address found in SharedPreferences");
    }
  }

  Future<DeployedContract> _loadContract() async {
    // Contract ABI (must match your Solidity contract)
    final contractAbi = '''[
      {
        "constant": false,
        "inputs": [
          {"name": "_firstName", "type": "string"},
          {"name": "_lastName", "type": "string"},
          {"name": "_email", "type": "string"},
          {"name": "_phone", "type": "string"},
          {"name": "_password", "type": "string"},
          {"name": "_wallet", "type": "address"}
        ],
        "name": "registerDonor",
        "outputs": [],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
      },
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

    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  Future<void> _getDonorData() async {
    try {
      final contract = await _loadContract();

      final result = await _callGetDonorMethod(contract, 'getDonor', [
        EthereumAddress.fromHex(_donorAddress),
      ]);

      if (result != null && result.isNotEmpty) {
        setState(() {
          _firstName = result[0];
          _lastName = result[1];
          _email = result[2];
          _phone = result[3];
        });
      } else {
        print("No donor data found for wallet: $_donorAddress");
      }
    } catch (e) {
      print("Error fetching donor data: $e");
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
            onPressed: () {},
          ),
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
                backgroundColor:
                    Colors.transparent, // Removes the background color
                child:
                    Icon(Icons.account_circle, size: 100, color: Colors.grey),
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
           onPressed: () async {SharedPreferences prefs = await SharedPreferences.getInstance();

  // Retrieve private key and wallet address before clearing session data
  String? privateKey = prefs.getString('privateKey');
  String? walletAddress = prefs.getString('walletAddress');

  // Clear all session-related data (but keep the private key and wallet address)
  await prefs.remove('userSession'); // Remove any session data you want cleared

  // If we have the private key and wallet address, restore them
  if (privateKey != null) {
    await prefs.setString('privateKey', privateKey);
  }
  if (walletAddress != null) {
    await prefs.setString('walletAddress', walletAddress);
  }

  print('✅ User logged out. Session cleared but private key and wallet address retained.');

  // Navigate to UsersPage
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const UsersPage()),
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
