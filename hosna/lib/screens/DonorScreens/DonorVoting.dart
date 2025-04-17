import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';


class DonorVotePage extends StatefulWidget {
  final String walletAddress;
  final String votingId;

  const DonorVotePage({
    required this.walletAddress,
    required this.votingId,
    Key? key,
  }) : super(key: key);

  @override
  _DonorVotePageState createState() => _DonorVotePageState();
}

class _DonorVotePageState extends State<DonorVotePage> {
  late Web3Client _web3Client;
  late EthereumAddress _contractAddressEth;
  late DeployedContract _contract;
  late ContractFunction _getVotingDetails;
  late ContractFunction _voteFunction;

  List<String> votingDetails = [];
  List<int> votingPercentages = [];
  bool isFetching = false;

  int selectedProjectIndex = -1;
  bool isSubmitting = false;

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
    },
    {
      "inputs": [
        { "name": "votingId", "type": "uint256" },
        { "name": "projectIndex", "type": "uint256" }
      ],
      "name": "vote",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';

  @override
  void initState() {
    super.initState();
    _initializeWeb3Client();
  }

  void _initializeWeb3Client() async {
    _web3Client = Web3Client(
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1',
      http.Client(),
    );

    _contractAddressEth =
        EthereumAddress.fromHex("0x619038eB1634155b26CB927ad09b5Fc14A6082cb");

    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, "CharityVoting"),
      _contractAddressEth,
    );

    _getVotingDetails = _contract.function("getVotingDetails");
    _voteFunction = _contract.function("vote");

    await _fetchVotingData();
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

  Future<void> _submitVote() async {
    if (selectedProjectIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an option to vote.")),
      );
      return;
    }

    setState(() => isSubmitting = true);

    final privateKey = await _loadPrivateKey();
    if (privateKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Private key not found.")),
      );
      setState(() => isSubmitting = false);
      return;
    }

    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      await _web3Client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract,
          function: _voteFunction,
          parameters: [
            BigInt.from(int.parse(widget.votingId)),
            BigInt.from(selectedProjectIndex),
          ],
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Vote submitted successfully!")),
      );
    } catch (e) {
      print("❌ Error submitting vote: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit vote: $e")),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text('Voting Details' ),
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
foregroundColor: Colors.white,
    ),
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.fromRGBO(24, 71, 137, 1),
      Color.fromRGBO(24, 71, 137, 1)],
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
                            itemCount: votingDetails.length,
                            itemBuilder: (context, index) {
                              return Card(
                                color: Colors.blue[50],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: RadioListTile<int>(
                                  value: index,
                                  groupValue: selectedProjectIndex,
                                  onChanged: (int? value) {
                                    setState(() {
                                      selectedProjectIndex = value!;
                                    });
                                  },
                                  title: Text(
                                    '${votingDetails[index]} (${votingPercentages[index]}%)',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Center(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40), // Increased padding for a larger container
    decoration: BoxDecoration(
      color: const Color(0xFFFFCDD2), // Very light grey background
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFB71C1C), width: 1), // Dark red border
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.access_time, color: Color(0xFFB71C1C) , size : 50), // Dark red icon
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: "Countdown :   ",
                style: TextStyle(
                  fontFamily: 'Georgia', // Set to Georgia font
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFFB71C1C), // Dark red for the label
                ),
              ),
              TextSpan(
                text: "$remainingDays",
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Georgia', // Set to Georgia font
                  color: Color(0xFFB71C1C), // Dark red for days
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: " d   ",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB71C1C), // Dark red for "d"
                  fontFamily: 'Georgia', // Set to Georgia font
                ),
              ),
              TextSpan(
                text: "$remainingHours",
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Georgia', // Set to Georgia font
                  color: Color(0xFFB71C1C), // Dark red for hours
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: " h   ",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB71C1C), // Dark red for "h"
                  fontFamily: 'Georgia', // Set to Georgia font
                ),
              ),
              TextSpan(
                text: "$remainingMinutes",
                style: const TextStyle(
                  fontSize: 18,
                  fontFamily: 'Georgia', // Set to Georgia font
                  color: Color(0xFFB71C1C), // Dark red for minutes
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: " m",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB71C1C), // Dark red for "m"
                  fontFamily: 'Georgia', // Set to Georgia font
                ),
              ),
            ],
          ),
        ),
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
   ElevatedButton(
  onPressed: isSubmitting ? null : _submitVote,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    elevation: 6,
    shadowColor: Colors.blueAccent.withOpacity(0.4),
    foregroundColor: Colors.white,
  ),
  child: isSubmitting
      ? const CircularProgressIndicator(color: Colors.white)
      : Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              "Submit Vote  ",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(width: 20),
            Icon(Icons.rocket_launch, color: Colors.white , size : 30),
          ],
        ),
),

  
  ],
),

                      ],
                    ),
        ),
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
