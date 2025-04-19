import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';


class DonorVotePage extends StatefulWidget {
   final String projectId; 
  final String walletAddress;
  final String votingId;

  const DonorVotePage({
       required this.projectId,
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

  String selectedProjectIndex = '';
  bool isSubmitting = false;

  int remainingMonths = 0;
  int remainingDays = 0;
  int remainingHours = 0;
  int remainingMinutes = 0;

bool _isLoadingRefundService = true;
RefundService? refundService;

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
    initRefundService();
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
Future<Credentials?> _loadUserCredentials() async {
  try {
    String? privateKey = await _loadPrivateKey(); // Retrieve private key from shared preferences
    if (privateKey == null) {
      print('⚠️ Private key not found');
      return null;
    }

    // Convert the private key to Ethereum credentials (Credentials object)
    Credentials credentials = EthPrivateKey.fromHex(privateKey);
    return credentials; // Return the credentials (userCredentials)
  } catch (e) {
    print('⚠️ Error retrieving credentials: $e');
    return null;
  }
}

Future<void> initRefundService() async {
  setState(() => _isLoadingRefundService = true); // Start loading

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

  setState(() => _isLoadingRefundService = false); // Done loading
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
BigInt getSelectedIndexAsBigInt() {
  if (selectedProjectIndex.startsWith('vote_')) {
    final index = int.parse(selectedProjectIndex.split('_')[1]);
    return BigInt.from(index);
  } else if (selectedProjectIndex.startsWith('refund_')) {
    final projectId = int.parse(widget.projectId);
    return BigInt.from(projectId);
  } else {
    throw Exception('Invalid selection format');
  }
}

Future<void> _submitVote() async {
  print("🔍 Checking if project is selected...");
  if (selectedProjectIndex == -1) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select an option to vote.")),
    );
    print("❌ No project selected. Returning...");
    return;
  }

  setState(() => isSubmitting = true);

  print("🔑 Loading private key...");
  final privateKey = await _loadPrivateKey();
  if (privateKey == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Private key not found.")),
    );
    setState(() => isSubmitting = false);
    print("❌ Private key not found. Returning...");
    return;
  }

  try {
    print("🔑 Private key loaded, creating credentials...");
    final credentials = EthPrivateKey.fromHex(privateKey);
    print("📜 Credentials created: $credentials");

    print("🚀 Preparing to send transaction...");
    print("📝 Transaction details: Voting ID: ${widget.votingId}, Project Index: $selectedProjectIndex");

   final result = await _web3Client.sendTransaction(
  credentials,
  Transaction.callContract(
    contract: _contract,
    function: _voteFunction,
    parameters: [
      BigInt.from(int.parse(widget.votingId)),
      getSelectedIndexAsBigInt(),
    ],
    maxGas: 300000,
  ),
  chainId: 11155111,
);


    print("✅ Transaction sent. Hash: $result");

    // Wait for transaction receipt with a status
    final receipt = await _waitForReceipt(result);

    if (receipt != null && receipt.status == true) {
      print("🎉 Vote submitted successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Vote submitted successfully!")),
      );
    } else if (receipt == null) {
      print("⏰ Transaction receipt timed out.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transaction confirmation timed out. Please check later.")),
      );
    } else {
      print("⚠️ Transaction failed or reverted.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Transaction failed. Please try again.")),
      );
    }

  } catch (e) {
    String errorMessage = "Failed to submit vote.";
    final errorString = e.toString();
    print("⚠️ Error caught: $e");

    if (errorString.contains('revert')) {
      print("🔍 Parsing revert error...");
      final match = RegExp(r'''revert(?:ed)?(?: with reason string)?\s*["']?([^"']+)["']?''').firstMatch(errorString);

      if (match != null && match.groupCount >= 1) {
        final revertMessage = match.group(1);
        print("📜 Revert reason found: $revertMessage");

        if (revertMessage == "Already voted") {
          errorMessage = "You have already voted.";
          print("❌ User has already voted.");
        } else {
          errorMessage = "Transaction reverted: $revertMessage";
          print("⚠️ Transaction reverted with message: $revertMessage");
        }
      } else {
        errorMessage = "Transaction reverted.";
        print("⚠️ Transaction reverted without a specific message.");
      }
    } else if (errorString.contains("User denied")) {
      errorMessage = "Transaction was rejected by the user.";
      print("❌ User rejected the transaction.");
    }

    print("❌ Error submitting vote: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  } finally {
    setState(() => isSubmitting = false);
    print("✅ Finished submitting, setting isSubmitting to false.");
  }
}

Future<TransactionReceipt?> _waitForReceipt(String txHash) async {
  const int maxTries = 20; // instead of 10
const Duration delay = Duration(seconds: 3); // instead of 2

  for (int i = 0; i < maxTries; i++) {
    final receipt = await _web3Client.getTransactionReceipt(txHash);
    if (receipt != null && receipt.status != null) {
      print("🧾 Transaction receipt received. Status: ${receipt.status}");
      return receipt;
    }
    print("⏳ Waiting for transaction receipt... (try ${i + 1}/$maxTries)");
    await Future.delayed(delay);
  }
  print("❌ Receipt not found after $maxTries attempts.");
  return null;
}

 @override
Widget build(BuildContext context) {

// Convert wallet address string to EthereumAddress
final EthereumAddress ethAddress = EthereumAddress.fromHex(widget.walletAddress);
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
  itemCount: votingDetails.length + 1,
  itemBuilder: (context, index) {
    if (index < votingDetails.length) {
      final voteValue = 'vote_$index'; // Unique string value
      return Card(
        color: Colors.blue[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: RadioListTile<String>(
          value: voteValue,
          groupValue: selectedProjectIndex,
          onChanged: (String? value) {
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
    } else {
      final refundValue = 'refund_${widget.projectId}'; // Also unique
      return Card(
        color: Colors.red[50],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: RadioListTile<String>(
          value: refundValue,
          groupValue: selectedProjectIndex,
          onChanged: (String? value) {
            setState(() {
              selectedProjectIndex = value!;
            });
          },
          title: const Text(
            'Request a refund',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
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
  onPressed: isSubmitting
      ? null
      : () async {
          setState(() {
            isSubmitting = true;
          });

          try {
            // التحقق من نوع الخيار (تصويت أو استرجاع)
            if (selectedProjectIndex.startsWith('refund_')) {
              final refundIndex = int.parse(widget.projectId);

              Credentials? userCredentials = await _loadUserCredentials();

              if (userCredentials == null) {
                print("❌ userCredentials is null. Cannot proceed.");
                return;
              }

              final refundService = RefundService(
                userAddress: ethAddress,
                userCredentials: userCredentials,
              );

              final txHash = await refundService.requestRefund(refundIndex);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Refund requested!')),
              );
            } else if (selectedProjectIndex.startsWith('vote_')) {
              // تصويت
              await _submitVote(); // تأكدي إنها معرفة وتعتمد على selectedProjectIndex
            } else {
              // حالة غير متوقعة
              throw Exception("❌ Invalid selection value");
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error: $e')),
            );
          } finally {
            setState(() {
              isSubmitting = false;
            });
          }
        },
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
            Icon(Icons.rocket_launch, color: Colors.white, size: 30),
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



class RefundService {
  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x6753413d428794F8CE9a9359E1739450A8cfED45';

  late Web3Client web3client;
  late DeployedContract donationContract;
  final EthereumAddress userAddress;
  final Credentials userCredentials;

  // ABI string should match the contract on-chain
  final String abi = '''
  [
    {
      "inputs": [
        { "internalType": "uint256", "name": "projectId", "type": "uint256" }
      ],
      "name": "requestRefund",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        { "internalType": "uint256", "name": "projectId", "type": "uint256" }
      ],
      "name": "getTotalRefunded",
      "outputs": [
        { "internalType": "uint256", "name": "", "type": "uint256" }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        { "internalType": "uint256", "name": "projectId", "type": "uint256" }
      ],
      "name": "getRefundRequestCount",
      "outputs": [
        { "internalType": "uint256", "name": "", "type": "uint256" }
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        { "internalType": "uint256", "name": "projectId", "type": "uint256" }
      ],
      "name": "updateDonatedAmount",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]
  ''';

  RefundService({
    required this.userAddress,
    required this.userCredentials,
  }) {
    web3client = Web3Client(rpcUrl, Client());

    donationContract = DeployedContract(
      ContractAbi.fromJson(abi, 'DonationContract'),
      EthereumAddress.fromHex(contractAddress),
    );
  }

  // Request a refund for a given project
  Future<void> requestRefund(int projectId) async {
    final requestRefundFunction = donationContract.function('requestRefund');
    final updateDonatedAmountFunction = donationContract.function('updateDonatedAmount');

    try {
      print("🧾 Preparing to request refund for projectId: $projectId");
      print("🚀 Sending refund transaction...");

      // Send refund transaction
      final result = await web3client.sendTransaction(
        userCredentials,
        Transaction.callContract(
          contract: donationContract,
          function: requestRefundFunction,
          parameters: [BigInt.from(projectId)],
        ),
        chainId: 11155111, // Sepolia
      );

      print("✅ Refund transaction sent: $result");

      // After refund, update the donated amount
      print("🔄 Updating donated amount after refund...");
      await web3client.sendTransaction(
        userCredentials,
        Transaction.callContract(
          contract: donationContract,
          function: updateDonatedAmountFunction,
          parameters: [BigInt.from(projectId)],
        ),
        chainId: 11155111, // Sepolia
      );

      print("✅ Donated amount updated after refund");
    } catch (e) {
      print("❌ Failed to request refund: $e");
    }
  }

  // Get total refunded amount for a project
  Future<BigInt> getTotalRefunded(int projectId) async {
    final function = donationContract.function('getTotalRefunded');
    try {
      final result = await web3client.call(
        contract: donationContract,
        function: function,
        params: [BigInt.from(projectId)],
      );
      return result.first as BigInt;
    } catch (e) {
      throw Exception('❌ Failed to fetch total refunded: $e');
    }
  }

  // Get number of users who requested a refund
  Future<BigInt> getRefundRequestCount(int projectId) async {
    final function = donationContract.function('getRefundRequestCount');
    try {
      final result = await web3client.call(
        contract: donationContract,
        function: function,
        params: [BigInt.from(projectId)],
      );
      return result.first as BigInt;
    } catch (e) {
      throw Exception('❌ Failed to fetch refund request count: $e');
    }
  }
}
