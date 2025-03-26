import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart'; // Add this import for Client


import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

class ViewDonorsPage extends StatefulWidget {
  final int projectId;

  ViewDonorsPage({Key? key, required this.projectId}) : super(key: key);

  @override
  _ViewDonorsPageState createState() => _ViewDonorsPageState();
}

class _ViewDonorsPageState extends State<ViewDonorsPage> {
  late Web3Client _web3Client;
  late DeployedContract _donationContract;
  late DeployedContract _donorRegistryContract;
  late ContractFunction _getProjectDonorsWithAmounts;
  late ContractFunction _getDonor;

  List<String> donorNames = [];
  List<BigInt> donorAmounts = [];

  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // Replace with your Infura project ID
  final String donationContractAddress = '0xd34FbeEdc4f69AcAE08d271D577Cb7EAED0E5Eb4';
  final String donorRegistryAddress = '0x761a4F03a743faf9c0Eb3440ffeAB086Bd099fbc';

  @override
  void initState() {
    super.initState();
    _initializeContracts();
  }

  Future<void> _initializeContracts() async {
    _web3Client = Web3Client(rpcUrl, Client());

    final donationAbi = '''[
      {
        "constant": true,
        "inputs": [{"name": "projectId", "type": "uint256"}],
        "name": "getProjectDonorsWithAmounts",
        "outputs": [{"name": "", "type": "address[]"}, {"name": "", "type": "uint256[]"}],
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    final donorRegistryAbi = '''[
      {
        "constant": true,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "getDonor",
        "outputs": [
          {"name": "", "type": "string"},
          {"name": "", "type": "string"},
          {"name": "", "type": "string"},
          {"name": "", "type": "string"},
          {"name": "", "type": "address"},
          {"name": "", "type": "bool"}
        ],
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    _donationContract = DeployedContract(
      ContractAbi.fromJson(donationAbi, 'DonationContract'),
      EthereumAddress.fromHex(donationContractAddress),
    );

    _donorRegistryContract = DeployedContract(
      ContractAbi.fromJson(donorRegistryAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(donorRegistryAddress),
    );

    _getProjectDonorsWithAmounts = _donationContract.function('getProjectDonorsWithAmounts');
    _getDonor = _donorRegistryContract.function('getDonor');

    await _fetchDonors();
  }

Future<void> _fetchDonors() async {
  try {
    print("Starting _fetchDonors function...");

    print("Fetching donors for project ID: ${widget.projectId}");

    final List<dynamic> results = await _web3Client.call(
      contract: _donationContract,
      function: _getProjectDonorsWithAmounts,
      params: [BigInt.from(widget.projectId)],
    );

    print("Results from contract call: $results");

    if (results.isNotEmpty && results[0] is List && results[1] is List) {
      final List<dynamic> addresses = results[0];
      final List<dynamic> amounts = results[1];

      print("Raw Addresses List: $addresses");
      print("Raw Amounts List: $amounts");

      List<String> namesList = [];
      List<BigInt> amountsList = [];

      for (int i = 0; i < addresses.length; i++) {
        print("Processing donor $i: ${addresses[i]}");

        if (addresses[i] is EthereumAddress) {
          print("Fetching profile for donor address: ${addresses[i]}");

          try {
            final donorProfile = await _getDonorProfile(addresses[i]);
            print("Fetched donor name: $donorProfile");

            namesList.add(donorProfile);
          } catch (profileError) {
            print("Error fetching profile for ${addresses[i]}: $profileError");
            namesList.add("Unknown Donor");
          }
        } else {
          print("Invalid address format at index $i: ${addresses[i]}");
        }

        print("Adding donation amount: ${amounts[i]}");
        amountsList.add(amounts[i]);
      }

      setState(() {
        donorNames = namesList;
        donorAmounts = amountsList;
      });

      print("Final Donor Names List: $donorNames");
      print("Final Donor Amounts List: $donorAmounts");
    } else {
      print("No donors found or unexpected structure. Results: $results");
    }
  } catch (e, stackTrace) {
    print("Error fetching donors: $e");
    print("StackTrace: $stackTrace");
  }
}


  Future<String> _getDonorProfile(EthereumAddress address) async {
    try {
      print("Fetching donor profile for address: ${address.hex}");

      final List<dynamic> result = await _web3Client.call(
        contract: _donorRegistryContract,
        function: _getDonor,
        params: [address],
      );

      print("Donor profile result: $result");

      if (result.isNotEmpty && result.length >= 2) {
        final String firstName = result[0]?.toString() ?? 'Unknown';
        final String lastName = result[1]?.toString() ?? '';
        return '$firstName $lastName'.trim();
      } else {
        return 'Unknown Donor';
      }
    } catch (e) {
      print("Error fetching donor profile: $e");
      return 'Error retrieving donor profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donors for Project')),
      body: donorNames.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: donorNames.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(donorNames[index]),
                  subtitle: Text('Donated: ${(donorAmounts[index] / BigInt.from(1e18)).toStringAsFixed(6)} ETH'),
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
