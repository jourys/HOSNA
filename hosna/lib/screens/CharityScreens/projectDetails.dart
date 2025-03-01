import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class ProjectDetails extends StatefulWidget {
  final String projectName;
  final String description;
  final String startDate;
  final String deadline;
  final String totalAmount;
  final String projectType;
  final String projectCreatorWallet;

  const ProjectDetails({
    super.key,
    required this.projectName,
    required this.description,
    required this.startDate,
    required this.deadline,
    required this.totalAmount,
    required this.projectType,
    required this.projectCreatorWallet,
  });

  @override
  _ProjectDetailsState createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  int? userType;
  final TextEditingController amountController = TextEditingController();
  bool isAnonymous = false;
  // String? globalPrivateKey;
   // Declare global variables to store wallet address and private key
  String? globalWalletAddress;


  // Web3 Variables
  late Web3Client _web3client;
  final String rpcUrl = "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final EthereumAddress contractAddress =
      EthereumAddress.fromHex("0x204e30437e9B11b05AC644EfdEaCf0c680022Fe5");
@override
void initState() {
  super.initState();
  _getUserType();
  _web3client = Web3Client(rpcUrl, Client());

  // Check if globalWalletAddress is available
  if (globalWalletAddress == null) {
    // If not, retrieve wallet address from SharedPreferences
    _loadWalletAddress();
  } else {
    // If globalWalletAddress is already set, proceed to load the private key
    _loadPrivateKey(globalWalletAddress!).then((privateKey) {
      if (privateKey != null) {
        print("✅ Loaded Private Key: $privateKey");
        // You can handle the private key further if needed
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
        const SnackBar(content: Text('Wallet address not found. Please log in again.')),
      );
      return null; // Return null if wallet address is not found
    }

    // If wallet address is found, load private key for it
    print("Wallet address found: $walletAddress");
    setState(() {
      globalWalletAddress = walletAddress;
    });

    // Now load private key for this wallet address and return it
    String? privateKey = await _loadPrivateKey(walletAddress);
    
    if (privateKey == null) {
      print("Error: Private key not found for wallet address.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Private key not found for wallet address.')),
      );
      return null; // Return null if private key is not found
    }
    
    return privateKey; // Return the private key if found
  } catch (e) {
    print("Error loading wallet address: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading wallet address: $e')),
    );
    return null; // Return null in case of an error
  }
}

Future<String?> _loadPrivateKey(String walletAddress) async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Construct the key for the private key
    String privateKeyKey = 'privateKey_$walletAddress';
    print('Retrieving private key for address: $walletAddress');
    
    String? privateKey = prefs.getString(privateKeyKey);

    if (privateKey != null) {
      print('✅ Private key retrieved for wallet $walletAddress');
      print('✅ Private key : $privateKey');
      // Use setter to assign private key
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


  @override
  Widget build(BuildContext context) {
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
              _buildDetailItem('Total Amount:', '${widget.totalAmount} SR'),
              _buildDetailItem('Project Type:', widget.projectType),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text('30% of donors contributed',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                  value: 0.3,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue)),
              const SizedBox(height: 20),
              if (userType == 0)
                Center(
                  child: ElevatedButton(
                    onPressed: () => _showDonationPopup(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
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
                        hintText: 'Amount ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                          value: isAnonymous,
                          onChanged: (value) =>
                              setState(() => isAnonymous = value!)),
                      const Text('Donate anonymously'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _processDonation(amountController.text),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
      const SnackBar(content: Text('Project creator address is empty or invalid.')),
    );
    return;
  }

  try {
    final recipientAddress = EthereumAddress.fromHex(widget.projectCreatorWallet);
    print("Recipient address: $recipientAddress"); // Debug log

    final credentials = EthPrivateKey.fromHex(globalPrivateKey!);
    print("Private key loaded successfully"); // Debug log

    final senderAddress = await credentials.extractAddress();
    print("Sender address: $senderAddress"); // Debug log

    if (senderAddress == recipientAddress) {
      print("Error: The sender and receiver addresses are the same.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sender and receiver cannot be the same.')),
      );
      return;
    }

    final donationAmount = BigInt.from(double.parse(amount) * 1e18);
    print("Donation amount: $donationAmount"); // Debug log

    final transaction = Transaction(
      to: recipientAddress,
      value: EtherAmount.fromUnitAndValue(EtherUnit.wei, donationAmount),
    );
    print("Transaction created: $transaction"); // Debug log

    final result = await _web3client.sendTransaction(
      credentials,
      transaction,
      chainId: 11155111, // Sepolia Testnet Chain ID
    );

    print("Transaction successful: $result"); // Debug log
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Donation successful!')),
    );
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
        "internalType": "address payable",
        "name": "projectCreator",
        "type": "address"
      }
    ],
    "name": "donate",
    "outputs": [],
    "stateMutability": "payable",
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
        "name": "totalDonated",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
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
  }
]

''';
