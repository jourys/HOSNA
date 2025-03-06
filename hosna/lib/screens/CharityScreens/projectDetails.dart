import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class ProjectDetails extends StatefulWidget {
  final String projectName;
  final String description;
  final String startDate;
  final String deadline;
  final double totalAmount;
  final String projectType;
  final String projectCreatorWallet;
  final double donatedAmount;
  final int projectId;
  final double progress;

  const ProjectDetails(
      {super.key,
      required this.projectName,
      required this.description,
      required this.startDate,
      required this.deadline,
      required this.totalAmount,
      required this.projectType,
      required this.projectCreatorWallet,
      required this.donatedAmount,
      required this.projectId,
      required this.progress});

  @override
  _ProjectDetailsState createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  int? userType;
  final TextEditingController amountController = TextEditingController();
  bool isAnonymous = false;
  String? globalWalletAddress;
  bool _isFetchingDonatedAmount = false;

  // Web3 Variables
  late Web3Client _web3client;
  final String rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final EthereumAddress contractAddress =
      EthereumAddress.fromHex("0x95a20778c2713a11ff61695e57cd562f78f75754");

  @override
  void initState() {
    super.initState();
    _getUserType();
    _web3client = Web3Client(rpcUrl, Client());

    if (globalWalletAddress == null) {
      _loadWalletAddress();
    } else {
      _loadPrivateKey(globalWalletAddress!).then((privateKey) {
        if (privateKey != null) {
          print("✅ Loaded Private Key: $privateKey");
        } else {
          print("❌ No private key found for this wallet address.");
        }
      });
    }

    print("Project Creator Wallet Address: ${widget.projectCreatorWallet}");
    print("Wallet Address: $globalWalletAddress");
  }

  String? _globalPrivateKey;

  String? get globalPrivateKey => _globalPrivateKey;

  set globalPrivateKey(String? privateKey) {
    _globalPrivateKey = privateKey;
    print('✅ Global private key set: $privateKey');
  }

  Future<void> _getUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getInt('userType');
    });
    print("All keys: ${prefs.getKeys()}");
  }

  Future<String?> _loadWalletAddress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("Error: Wallet address not found. Please log in again.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Wallet address not found. Please log in again.')),
        );
        return null;
      }

      setState(() {
        globalWalletAddress = walletAddress;
      });

      String? privateKey = await _loadPrivateKey(walletAddress);

      if (privateKey == null) {
        print("Error: Private key not found for wallet address.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Private key not found for wallet address.')),
        );
        return null;
      }

      return privateKey;
    } catch (e) {
      print("Error loading wallet address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading wallet address: $e')),
      );
      return null;
    }
  }

  Future<String?> _loadPrivateKey(String walletAddress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
        print('✅ Private key : $privateKey');
        globalPrivateKey = privateKey;
        return privateKey;
      } else {
        print('❌ Private key not found for wallet $walletAddress');
        return null;
      }
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
      return null;
    }
  }

  Future<void> _fetchDonatedAmount() async {
    setState(() {
      _isFetchingDonatedAmount = true;
    });

    try {
      print("Fetching donated amount for project ID: ${widget.projectId}");

      final donationContract = DeployedContract(
        ContractAbi.fromJson(_contractAbi, 'DonationContract'),
        contractAddress,
      );

      final function = donationContract.function('getProjectDonations');

      final result = await _web3client.call(
        contract: donationContract,
        function: function,
        params: [BigInt.from(widget.projectId)],
      );

      print("Raw Result from Smart Contract: $result");

      if (result.isEmpty || result[0] == null) {
        print("⚠️ Warning: No data returned from contract!");
        return;
      }

      final donatedAmountInWei = result[0] as BigInt;
      final donatedAmountInEth = donatedAmountInWei / BigInt.from(10).pow(18);

      print("✅ Donated Amount (ETH): $donatedAmountInEth");
    } catch (e) {
      print("❌ Error fetching donated amount: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching donated amount: $e')),
      );
    } finally {
      setState(() {
        _isFetchingDonatedAmount = false;
      });
    }
  }

  String _getProjectState() {
    Map<String, dynamic> project = {
      'startDate': widget.startDate,
      'endDate': widget.deadline,
      'totalAmount': widget.totalAmount,
      'donatedAmount': widget.donatedAmount,
    };

    return getProjectState(project); // Use the utility function
  }

  String getProjectState(Map<String, dynamic> project) {
    DateTime now = DateTime.now();

    // Handle startDate (could be DateTime, String, or null)
    DateTime startDate;
    if (project['startDate'] == null) {
      return "upcoming"; // If startDate is null, assume the project is upcoming
    } else if (project['startDate'] is DateTime) {
      startDate = project['startDate'];
    } else {
      startDate = DateTime.parse(project['startDate']);
    }

    // Handle endDate (could be DateTime, String, or null)
    DateTime endDate;
    if (project['endDate'] == null) {
      return "active"; // If endDate is null, assume the project is active
    } else if (project['endDate'] is DateTime) {
      endDate = project['endDate'];
    } else {
      endDate = DateTime.parse(project['endDate']);
    }

    // Handle totalAmount (could be int, String, or null)
    double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming";
    } else if (donatedAmount >= totalAmount) {
      return "in-progress"; // Project reached the goal
    } else {
      if (now.isAfter(endDate)) {
        return "failed"; // Project failed to reach the target
      } else {
        return "active"; // Project is ongoing and goal is not reached yet
      }
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "in-progress":
        return Colors.purple;
      case "completed":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    String projectState = _getProjectState();
    Color stateColor = _getStateColor(projectState);
    double totalAmount = widget.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.projectName,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1)),
              ),
              const SizedBox(height: 20),
              Text(widget.description,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              const SizedBox(height: 20),
              _buildDetailItem('Start Date:', widget.startDate),
              _buildDetailItem('Deadline:', widget.deadline),
              _buildDetailItem(
                  'Total Amount:', '${totalAmount.toStringAsFixed(5)} ETH'),
              _buildDetailItem('Project Type:', widget.projectType),
              Visibility(
                visible: _isFetchingDonatedAmount,
                child: Center(child: CircularProgressIndicator()),
              ),
              Visibility(
                visible: !_isFetchingDonatedAmount,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem('Donated Amount:',
                        '${widget.donatedAmount.toStringAsFixed(5)} ETH'), // Updated here
                    const SizedBox(height: 20),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: widget.progress,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(widget.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: stateColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            projectState,
                            style: TextStyle(
                                color: stateColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (userType == 0 && projectState == "active")
                      Center(
                        child: ElevatedButton(
                          onPressed: () => _showDonationPopup(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Donate',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (userType == 1 &&
                        projectState == "failed" &&
                        widget.projectCreatorWallet == globalWalletAddress)
                      Center(
                        child: ElevatedButton(
                          onPressed: () => print("voting"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Initiate Voting',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (userType == 1 &&
                        projectState == "in-progress" &&
                        widget.projectCreatorWallet == globalWalletAddress)
                      Center(
                        child: ElevatedButton(
                          onPressed: () => print("post update"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Post Update',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          text: '$title ',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.normal))
          ],
        ),
      ),
    );
  }

  void _showDonationPopup(BuildContext context) {
    TextEditingController amountController = TextEditingController();
    bool isAnonymous = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter Donation Amount',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Amount',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      errorText: errorMessage, // Show error message if invalid
                    ),
                    onChanged: (value) {
                      setState(() {
                        double? amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          errorMessage =
                              "Please enter a valid amount greater than zero";
                        } else {
                          errorMessage = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isAnonymous,
                        onChanged: (value) =>
                            setState(() => isAnonymous = value!),
                      ),
                      const Text('Donate anonymously'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: errorMessage == null
                        ? () async {
                            await _processDonation(amountController.text);
                            Navigator.pop(context);
                          }
                        : null, // Disable if input is invalid
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('Send',
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _processDonation(String amount) async {
    if (globalPrivateKey == null) {
      print("Error: No private key found.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private key is missing.')),
      );
      return;
    }

    if (widget.projectCreatorWallet.isEmpty) {
      print("Error: Invalid Ethereum address. The address is empty.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Project creator address is empty or invalid.')),
      );
      return;
    }

    try {
      final credentials = EthPrivateKey.fromHex(globalPrivateKey!);
      final senderAddress = await credentials.extractAddress();

      // Convert the donation amount from ETH to wei
      final donationAmountInEth = double.parse(amount);
      final donationAmountInWei = BigInt.from(donationAmountInEth * 1e18);

      // Check wallet balance
      final balance = await _web3client.getBalance(senderAddress);

      // Estimate gas fees
      final gasPrice = await _web3client.getGasPrice();
      final gasLimit = BigInt.from(300000); // Example gas limit
      final totalGasFee = gasPrice.getInWei * gasLimit;

      // Check if the wallet has enough ETH for the donation and gas fees
      if (balance.getInWei < (donationAmountInWei + totalGasFee)) {
        print("Error: Insufficient funds for donation and gas fees.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Insufficient funds for donation and gas fees.')),
        );
        return;
      }

      // Load the DonationContract
      final donationContract = DeployedContract(
        ContractAbi.fromJson(_contractAbi, 'DonationContract'),
        EthereumAddress.fromHex('0x95a20778c2713a11ff61695e57cd562f78f75754'),
      );

      // Get the function reference
      final function = donationContract.function('donate');

      // Send the transaction to the DonationContract
      final transaction = Transaction.callContract(
        contract: donationContract,
        function: function,
        parameters: [
          BigInt.from(widget.projectId), // Pass project ID
        ],
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, donationAmountInWei),
        gasPrice: gasPrice,
        maxGas: gasLimit.toInt(),
      );

      final result = await _web3client.sendTransaction(
        credentials,
        transaction,
        chainId: 11155111, // Sepolia Testnet Chain ID
      );

      print("Transaction successful: $result");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation successful!')),
      );

      // Refresh the donated amount after a successful donation
      //_fetchDonatedAmount();
    } catch (e) {
      print("Error processing donation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing donation: $e')),
      );
    }
  }
}

final String _contractAbi = '''
[
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_postProjectAddress",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "donor",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "projectCreator",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "projectId",
        "type": "uint256"
      }
    ],
    "name": "DonationReceived",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "projectCreator",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "FundsTransferred",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "projectId",
        "type": "uint256"
      }
    ],
    "name": "donate",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getContractBalance",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "donor",
        "type": "address"
      }
    ],
    "name": "getDonorInfo",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "projectId",
        "type": "uint256"
      }
    ],
    "name": "getProjectDonations",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "postProject",
    "outputs": [
      {
        "internalType": "contract PostProject",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "name": "projectDonations",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';
