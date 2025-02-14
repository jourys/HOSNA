import 'package:flutter/material.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

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

  final String rpcUrl = 'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xc5A97194e3A6c4524D74D8872C91BbacfBd198E1';

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    // Retrieve wallet address from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _charityAddress = prefs.getString('walletAddress') ?? '';

    if (_charityAddress.isNotEmpty) {
      await _getCharityData();
    } else {
      print("No wallet address found for the charity.");
    }
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

  Future<void> _getCharityData() async {
    try {
      final contract = await _loadContract();

      final result = await _callGetCharityMethod(contract, 'getCharity', [
        EthereumAddress.fromHex(_charityAddress),
      ]);

      if (result != null && result.isNotEmpty) {
        setState(() {
          _organizationName = result[0];
          _email = result[1];
          _phone = result[2];
          _licenseNumber = result[3];
          _organizationCity = result[4];
          _description = result[5]; //_description
          _organizationURL = result[6]; //_organizationURL
          _establishmentDate = result[7]; //_establishmentDate
        });
      } else {
        print("No charity data found for wallet: $_charityAddress");
      }
    } catch (e) {
      print("Error fetching charity data: $e");
    }
  }

  Future<List<dynamic>> _callGetCharityMethod(
      DeployedContract contract, String methodName, List<dynamic> params) async {
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
                child: Icon(Icons.account_circle, size: 100, color: Colors.grey),
              ),
              SizedBox(height: 30),
              Text(_organizationName,
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
                      infoRow('License Number : ', _licenseNumber),
                      infoRow('City : ', _organizationCity),
                      infoRow('Website : ', _organizationURL),
                      infoRow('Establishment Date : ', _establishmentDate),
                      infoRow('Description : ', _description),
                      SizedBox(height: 200),
                      Center(
                        child: SizedBox(
                            height: MediaQuery.of(context).size.height * .066,
                            width: MediaQuery.of(context).size.width * .8,
                            child: ElevatedButton(
                              onPressed: () {
                                // Log out logic
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setString('walletAddress', 'none');
                                });

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const UsersPage()),
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
                                      borderRadius: BorderRadius.all(Radius.circular(24)))),
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
                                  fontSize: 20,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.red[900]!),
                                      borderRadius: BorderRadius.all(Radius.circular(24)))),
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
