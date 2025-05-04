import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:lottie/lottie.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart'; // Import Client from the http package
import 'dart:convert'; // Import for utf8 and hex encoding
import 'dart:typed_data'; // Required to use Uint8List
import 'dart:convert'; // Optional if you need other encoding

class VotingDetailsPage extends StatefulWidget {
  final String projectId;
  final String walletAddress;
  final String votingId;

  const VotingDetailsPage({
    required this.projectId,
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

  String selectedProjectIndex = '';

  int remainingMonths = 0;
  int remainingDays = 0;
  int remainingHours = 0;
  int remainingMinutes = 0;

  bool _isLoadingRefundService = true;
  RefundService? refundService;
  BigInt? totalRefunded;

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
    _initializeWeb3Client();
    initRefundService();
    fetchRefundedTotal();
  }

  void fetchRefundedTotal() async {
    try {
      String? privateKey = await _loadPrivateKey();
      String? walletAddress = await _loadWalletAddress();

      if (privateKey == null || walletAddress == null) {
        print("❌ Wallet info missing");
        return;
      }

      final creds = EthPrivateKey.fromHex(privateKey);
      final userAddr = EthereumAddress.fromHex(walletAddress);

      final tempRefundService = RefundService(
        userAddress: userAddr,
        userCredentials: creds,
      );

      final result = await tempRefundService
          .getRefundRequestCount(int.parse(widget.projectId));
      setState(() {
        totalRefunded = result;
      });
    } catch (e) {
      print("❌ Error fetching total refunded: $e");
    }
  }

  void _initializeWeb3Client() async {
    _web3Client = Web3Client(
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1',
      http.Client(),
    );

    _contractAddressEth =
        EthereumAddress.fromHex("0x421679ff91d6443B13b40082a56D7cD38D94e6dc");

    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, "CharityVoting"),
      _contractAddressEth,
    );

    _getVotingDetails = _contract.function("getVotingDetails");

    await _fetchVotingData();
  }

  Future<void> initRefundService() async {
    setState(() => _isLoadingRefundService = true);

    try {
      String? privateKey = await _loadPrivateKey();
      String? walletAddress = await _loadWalletAddress();

      if (privateKey == null || walletAddress == null) {
        print("❌ Wallet info missing");
        setState(() => _isLoadingRefundService = false);
        return;
      }

      final creds = EthPrivateKey.fromHex(privateKey);
      final userAddr = EthereumAddress.fromHex(walletAddress);

      refundService = RefundService(
        userAddress: userAddr,
        userCredentials: creds,
      );

      print("✅ RefundService initialized for $walletAddress");
    } catch (e) {
      print("⚠️ Error initializing RefundService: $e");
    }

    setState(() => _isLoadingRefundService = false);
  }

  Future<void> _fetchVotingData() async {
    if (isFetching) return;
    isFetching = true;

    try {
      final results = await _web3Client.call(
        contract: _contract,
        function: _getVotingDetails,
        params: [BigInt.from(int.parse(widget.votingId))],
      );

      if (results.isEmpty || results[0].isEmpty) return;

      setState(() {
        votingDetails = List<String>.from(results[0]);
        votingPercentages =
            (results[1] as List).map((e) => (e as BigInt).toInt()).toList();
        remainingMonths = (results[2] as BigInt).toInt();
        remainingDays = (results[3] as BigInt).toInt();
        remainingHours = (results[4] as BigInt).toInt();
        remainingMinutes = (results[5] as BigInt).toInt();
      });
    } catch (e) {
      print("❌ Error fetching voting data: $e");
    } finally {
      isFetching = false;
    }
  }

  String _formatRemainingTime() {
    return "$remainingDays days, $remainingHours hours, $remainingMinutes minutes";
  }

  Future<String?> _loadPrivateKey() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) return null;

      String privateKeyKey = 'privateKey_$walletAddress';
      return prefs.getString(privateKeyKey);
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
      return null;
    }
  }

  Future<String?> _loadWalletAddress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('walletAddress');
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
// Convert wallet address string to EthereumAddress
    final EthereumAddress ethAddress =
        EthereumAddress.fromHex(widget.walletAddress);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Voting Details'),
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(24, 71, 137, 1),
              Color.fromRGBO(24, 71, 137, 1)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: VotingGlassEffectContainer(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isFetching
                ? const Center(child: CircularProgressIndicator())
                : votingDetails.isEmpty
                    ? const Center(child: Text("No voting details available"))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            "Choose one project to vote:",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: votingDetails.length + 1,
                              itemBuilder: (context, index) {
                                if (index < votingDetails.length) {
                                  return Card(
                                    color: Colors.blue[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        '${votingDetails[index]} (${votingPercentages[index]}%)',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Card(
                                    color: Colors.red[50],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      title: const Text(
                                        'Request a refund',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.people,
                                              color: const Color.fromARGB(
                                                  255, 53, 52, 52)),
                                          const SizedBox(width: 5),
                                          Text(
                                            ' $totalRefunded',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color.fromARGB(
                                                  255, 50, 50, 50),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 20),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 251, 216, 219),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildTimeCard(
                                      remainingDays.toString(), 'Days'),
                                  _buildColon(),
                                  _buildTimeCard(
                                      remainingHours.toString(), 'Hours'),
                                  _buildColon(),
                                  _buildTimeCard(
                                      remainingMinutes.toString(), 'Minutes'),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Center(
                                child: SizedBox(
                                  height: 200,
                                  width: 500,
                                  child: Lottie.asset('assets/hourglass.json'),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

// Widget for time unit card
  Widget _buildTimeCard(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFFB71C1C),
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFB71C1C),
            fontFamily: 'Georgia',
          ),
        ),
      ],
    );
  }

// Widget for colon separator
  Widget _buildColon() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        ":",
        style: TextStyle(
          fontSize: 24,
          color: Color(0xFFB71C1C),
          fontWeight: FontWeight.bold,
          fontFamily: 'Georgia',
        ),
      ),
    );
  }
}

class VotingGlassEffectContainer extends StatelessWidget {
  final Widget child;

  const VotingGlassEffectContainer({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: Container(
        color: Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
