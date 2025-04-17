import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart'; // Import Client from the http package
import 'dart:convert';  // Import for utf8 and hex encoding
import 'dart:typed_data';  // Required to use Uint8List
import 'dart:convert'; // Optional if you need other encoding


class VotingDetailsPage extends StatefulWidget {
  final String walletAddress;
  final String votingId;

  const VotingDetailsPage({
    required this.walletAddress,
    required this.votingId,
    Key? key,
  }) : super(key: key);

  @override
  _VotingDetailsPageState createState() => _VotingDetailsPageState();
}

class _VotingDetailsPageState extends State<VotingDetailsPage> {
  late Web3Client _web3Client;
  late EthereumAddress _contractAddressEth;
  late DeployedContract _contract;
  late ContractFunction _getVotingDetails;

  List<String> votingDetails = [];
  List<int> votingPercentages = [];
  bool isFetching = false;

  int remainingMonths = 0;
  int remainingDays = 0;
  int remainingHours = 0;
  int remainingMinutes = 0;

  final String _abi = '''[
    {
      "constant": true,
      "inputs": [{ "name": "votingId", "type": "uint256" }],
      "name": "getVotingDetails",
      "outputs": [
        { "name": "projectNames", "type": "string[]" },
        { "name": "percentages", "type": "uint256[]" },
        { "name": "remainingMonths", "type": "uint256" },
        { "name": "remainingDays", "type": "uint256" },
        { "name": "remainingHours", "type": "uint256" },
        { "name": "remainingMinutes", "type": "uint256" }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

  @override
  void initState() {
    super.initState();
    print("🟢 initState called! Initializing Web3 client...");
    _initializeWeb3Client();
  }

  void _initializeWeb3Client() async {
    print("🔌 Setting up Web3Client...");
    _web3Client = Web3Client(
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1', 
      http.Client(),
    );

    const int chainId = 11155111;

    _contractAddressEth = EthereumAddress.fromHex(
      "0x619038eB1634155b26CB927ad09b5Fc14A6082cb", 
    );
    print("📦 Contract address set: $_contractAddressEth");

    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, "CharityVoting"),
      _contractAddressEth,
    );
    print("📜 Contract loaded!");

    _getVotingDetails = _contract.function("getVotingDetails");

    print("⚙️ Contract functions loaded.");
    await _fetchVotingData();
  }

  Future<void> _fetchVotingData() async {
    if (isFetching) return;
    isFetching = true;

    try {
      print("🚀 Fetching voting data for ID: ${widget.votingId}");

      await Future.delayed(const Duration(seconds: 5)); // Delay for debugging

      final results = await _web3Client.call(
        contract: _contract,
        function: _getVotingDetails,
        params: [BigInt.from(int.parse(widget.votingId))],
      );

      print("📝 Results from getVotingDetails: $results");

      if (results.isEmpty || results[0].isEmpty) {
        print("❌ No results or invalid data returned from getVotingDetails.");
        return; // Early exit if results are invalid
      }

      setState(() {
        votingDetails = List<String>.from(results[0]); // Project names
        votingPercentages = (results[1] as List)
            .map((e) => (e as BigInt).toInt()) // Percentages
            .toList();

        remainingMonths = (results[2] as BigInt).toInt();
        remainingDays = (results[3] as BigInt).toInt();
        remainingHours = (results[4] as BigInt).toInt();
        remainingMinutes = (results[5] as BigInt).toInt();
      });

      print("✅ Voting data updated successfully.");
    } catch (e) {
      print("❌ Error fetching voting data: $e");

      if (e.toString().contains("execution reverted")) {
        print("💡 Check if voting ID exists and is valid.");
      } else {
        print("💡 An unknown error occurred: ${e.toString()}");
      }
    } finally {
      isFetching = false;
    }
  }

  String _formatRemainingTime() {
    return "$remainingMonths months, $remainingDays days, $remainingHours hours, $remainingMinutes minutes";
  }

  

  @override
  Widget build(BuildContext context) {
    final List<String> options = votingDetails;
    final List<String> percentages = votingPercentages
        .map((e) => "$e%")
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voting Details'),
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isFetching
            ? const Center(child: CircularProgressIndicator())
            : votingDetails.isEmpty
                ? const Center(child: Text("No voting details available"))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Voting Ends In: ${_formatRemainingTime()}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      const Text("Options and Percentages:",
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final optionName = options[index];
                            final percentage = index < percentages.length
                                ? percentages[index]
                                : "0%";

                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFF5F5F5),
                              ),
                              child: Text(
                                '$optionName: $percentage',
                                style: const TextStyle(fontSize: 16),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

