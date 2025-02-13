import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

import 'profile_screen_two.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Web3Client _web3Client;
  String _firstName = '';
  String _walletAddress = '';

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

    final prefs = await SharedPreferences.getInstance();
    _walletAddress = prefs.getString('walletAddress') ?? '';

    if (_walletAddress.isNotEmpty) {
      await _getDonorData();
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

    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  Future<void> _getDonorData() async {
    try {
      final contract = await _loadContract();
      final result = await _web3Client.call(
        contract: contract,
        function: contract.function('getDonor'),
        params: [EthereumAddress.fromHex(_walletAddress)],
      );

      if (result.isNotEmpty) {
        setState(() {
          _firstName = result[0]; // First name from blockchain
        });
      }
    } catch (e) {
      print("Error fetching donor data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 60), // Moves everything down
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Day, ${_firstName}!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 120, // Define an explicit width
                      height: 80, // Define an explicit height
                      child: IconButton(
                        icon: const Icon(Icons.account_circle,
                            size: 85, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfileScreenTwo()),
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  '🏠 Home Page',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
