import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

import 'DonorProfile.dart';

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
  final String contractAddress = '0x761a4F03a743faf9c0Eb3440ffeAB086Bd099fbc';
  final String DonationContractAddress =
      "0x204e30437e9B11b05AC644EfdEaCf0c680022Fe5";

  List<String> donatedProjectNames =
      []; // This will hold the project names from SharedPreferences

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    _loadWalletAddress();
    printUserType();
    _loadDonatedProjects(); // Load the projects when the page is initialized
  }

  Future<void> _loadDonatedProjects() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Retrieve the wallet address from SharedPreferences
    String walletAddress = prefs.getString('walletAddress') ?? '';

    if (walletAddress.isEmpty) {
      print('No wallet address found');
      return;
    }

    // Use the wallet address to get the donated projects
    String key = 'donatedProjects_$walletAddress';

    // Get the list of donated projects
    List<String> projectNames = prefs.getStringList(key) ?? [];

    print("Loaded donated project names: $projectNames");

    // Update the UI with the project names
    setState(() {
      donatedProjectNames = projectNames;
    });

    print("All donated project names after loading: $donatedProjectNames");
  }

  void _loadWalletAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String walletAddress = prefs.getString('walletAddress') ?? '';
    print("Wallet Address from SharedPreferences: $walletAddress");

    if (walletAddress.isNotEmpty) {
      setState(() {
        _walletAddress = walletAddress;
      });
      _loadDonatedProjects();
    } else {
      print("⚠️ Wallet address is not available!");
    }
  }

  Future<void> _getDonorData() async {
    try {
      final contract = await _loadContract();
      final result = await _web3Client.call(
        contract: contract,
        function: contract.function('getDonor'),
        params: [EthereumAddress.fromHex(_walletAddress)],
      );

      if (mounted) {
        // Check if the widget is still mounted
        setState(() {
          _firstName = result[0]; // First name from blockchain
        });
      }
    } catch (e) {
      print("Error fetching donor data: $e");
    }
  }

  Future<void> _initializeWeb3() async {
    print("Initializing Web3 client...");
    _web3Client = Web3Client(rpcUrl, Client());

    final prefs = await SharedPreferences.getInstance();
    _walletAddress = prefs.getString('walletAddress') ?? '';
    print("Wallet address from SharedPreferences: $_walletAddress");

    if (_walletAddress.isNotEmpty) {
      await _getDonorData();
    }
  }

  Future<void> printUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userType = prefs.getInt('userType'); // 0 = Donor, 1 = Charity

    if (userType != null) {
      if (userType == 0) {
        print("User Type: Donor");
      } else if (userType == 1) {
        print("User Type: Charity Employee");
      }
    } else {
      print("No user type found in SharedPreferences");
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

  // Future<void> _getDonorData() async {
  //   try {
  //     print("Fetching donor data for wallet: $_walletAddress");
  //     final contract = await _loadContract();
  //     final result = await _web3Client.call(
  //       contract: contract,
  //       function: contract.function('getDonor'),
  //       params: [EthereumAddress.fromHex(_walletAddress)],
  //     );

  //     if (result.isNotEmpty) {
  //       setState(() {
  //         _firstName = result[0]; // First name from blockchain
  //       });
  //       print("Donor first name: $_firstName");
  //     }
  //   } catch (e) {
  //     print("Error fetching donor data: $e");
  //   }
  // }

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
              child: donatedProjectNames.isEmpty
                  ? const Center(child: Text("No donations found"))
                  : ListView.builder(
                      itemCount: donatedProjectNames.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              donatedProjectNames[index],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: const Text(
                              "Click for more details", // Informative subtitle
                              style: TextStyle(color: Colors.grey),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blue,
                            ),
                            onTap: () {
                              // Implement navigation or other actions here
                              // For example, navigate to a detail page
                              print("Tapped on ${donatedProjectNames[index]}");
                            },
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
