import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart'; // Add this import for Client

class ViewDonorsPage extends StatefulWidget {
  final int projectId;

  ViewDonorsPage({Key? key, required this.projectId}) : super(key: key);

  @override
  _ViewDonorsPageState createState() => _ViewDonorsPageState();
}

class _ViewDonorsPageState extends State<ViewDonorsPage> {
  late Web3Client _web3Client;
  late DeployedContract _donationContract;
  late ContractFunction _getProjectDonorsWithAmounts;
  late ContractFunction _getDonor;

  List<Map<String, dynamic>> donorData = []; // List of donor data with address, amount, and anonymity

  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // Replace with your Infura project ID
  final String donationContractAddress = '0x0913167630dac537dd9477c68c3c7806159871C9'; // Your contract address

  @override
  void initState() {
    super.initState();
    _initializeContracts();
  }Future<void> _initializeContracts() async {
  print("Initializing contracts...");

  _web3Client = Web3Client(rpcUrl, Client());

  // Define the ABI for the updated contract
  final donationAbi = '''[
    {
      "constant": false,
      "inputs": [
        {"name": "projectId", "type": "uint256"},
        {"name": "isAnonymous", "type": "bool"}
      ],
      "name": "donate",
      "outputs": [],
      "stateMutability": "payable",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [{"name": "projectId", "type": "uint256"}],
      "name": "getProjectDonorsWithAmounts",
      "outputs": [
        {"name": "", "type": "address[]"},
        {"name": "", "type": "uint256[]"},
        {"name": "", "type": "uint256[]"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  _donationContract = DeployedContract(
    ContractAbi.fromJson(donationAbi, 'DonationContract'),
    EthereumAddress.fromHex(donationContractAddress),
  );

  _getProjectDonorsWithAmounts = _donationContract.function('getProjectDonorsWithAmounts');

  await _fetchProjectDonors(widget.projectId);
}
bool _isLoading = true; // Track loading state

Future<void> _fetchProjectDonors(int projectId) async {
    setState(() {
    _isLoading = true; // Show loading indicator
  });

  print("Fetching donors for project ID: $projectId");

  try {
    // Fetch donor addresses, anonymous donation amounts, and non-anonymous amounts
    final List<dynamic> result = await _web3Client.call(
      contract: _donationContract,
      function: _getProjectDonorsWithAmounts,
      params: [BigInt.from(projectId)],
    );

    if (result.isNotEmpty && result.length == 3) {
      final List<dynamic> addresses = result[0] as List<dynamic>;
      final List<dynamic> anonymousAmountsRaw = result[1] as List<dynamic>;
      final List<dynamic> nonAnonymousAmountsRaw = result[2] as List<dynamic>;

      List<Map<String, dynamic>> donorsList = [];

      for (int i = 0; i < addresses.length; i++) {
        final String address = addresses[i].toString();
        final BigInt anonymousAmount = BigInt.tryParse(anonymousAmountsRaw[i].toString()) ?? BigInt.zero;
        final BigInt nonAnonymousAmount = BigInt.tryParse(nonAnonymousAmountsRaw[i].toString()) ?? BigInt.zero;

        donorsList.add({
          'address': address,
          'anonymousAmount': anonymousAmount,
          'nonAnonymousAmount': nonAnonymousAmount,
        });
      }

      setState(() {
        donorData = donorsList;
        _isLoading = false; // Hide loading indicator
      });

      print("Processed Donor Data: $donorData");
    } else {
      print("Unexpected result format or no data found.");
    }
  } catch (e) {
    print("Error fetching project donors: $e");
  }
}


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Donors for Project')),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator()) // Show loading indicator
        : donorData.isEmpty
            ? const Center(
                child: Text(
                  'No donations have been made for this project yet.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                itemCount: donorData.length,
                itemBuilder: (context, index) {
                  final donor = donorData[index];

                  // Convert BigInt amounts to ETH
                  double anonymousAmount = donor['anonymousAmount'].toDouble() / 1e18;
                  double nonAnonymousAmount = donor['nonAnonymousAmount'].toDouble() / 1e18;

                  return ListTile(
                    title: Text('Donor Address: ${donor['address']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anonymous Donations: ${anonymousAmount.toStringAsFixed(8)} ETH'),
                        Text('Non-Anonymous Donations: ${nonAnonymousAmount.toStringAsFixed(8)} ETH'),
                      ],
                    ),
                  );
                },
              ),
  );
}
}
class DonorProfilePage extends StatefulWidget {
  final String walletAddress;

  DonorProfilePage({Key? key, required this.walletAddress}) : super(key: key);

  @override
  _DonorProfilePageState createState() => _DonorProfilePageState();
}

class _DonorProfilePageState extends State<DonorProfilePage> {
  late Web3Client _web3Client;
  late DeployedContract _contract;
  late ContractFunction _getDonorFunction;

  String firstName = "";
  String lastName = "";
  String email = "";
  String phone = "";
  String walletAddress = "";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _web3Client = Web3Client('https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1', Client()); 

    final abi = '''
    [
      {
        "constant": true,
        "inputs": [
          {
            "name": "_wallet",
            "type": "address"
          }
        ],
        "name": "getDonor",
        "outputs": [
          {
            "name": "",
            "type": "string"
          },
          {
            "name": "",
            "type": "string"
          },
          {
            "name": "",
            "type": "string"
          },
          {
            "name": "",
            "type": "string"
          },
          {
            "name": "",
            "type": "address"
          },
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

    final contractAddress = EthereumAddress.fromHex('0x761a4F03a743faf9c0Eb3440ffeAB086Bd099fbc'); 
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'DonorRegistry'),
      contractAddress,
    );

    _getDonorFunction = _contract.function('getDonor');

    await _fetchDonorProfile();
  }

  Future<void> _fetchDonorProfile() async {
    try {
      final wallet = EthereumAddress.fromHex(widget.walletAddress);
      final List<dynamic> result = await _web3Client.call(
        contract: _contract,
        function: _getDonorFunction,
        params: [wallet],
      );

      setState(() {
        firstName = result[0];
        lastName = result[1];
        email = result[2];
        phone = result[3];
        walletAddress = result[4].toString();
      });
    } catch (e) {
      print("Error fetching donor profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donor Profile')),
      body: firstName.isEmpty
          ? const Center(child: CircularProgressIndicator()) 
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("First Name: $firstName"),
                  Text("Last Name: $lastName"),
                  Text("Email: $email"),
                  Text("Phone: $phone"),
                  Text("Wallet Address: $walletAddress"),
                ],
              ),
            ),
    );
  }
}



