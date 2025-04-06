import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x2bbf496a6df44fbd91b14dbf682e43162ec4f3da';

  late Web3Client _web3Client;
  late EthPrivateKey _credentials;
  late EthereumAddress _ownAddress;

  // ABI for the contract
  final abi = '''[
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "uint256",
        "name": "projectId",
        "type": "uint256"
      },
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
      }
    ],
    "name": "DonationReceived",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "description",
        "type": "string"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "startDate",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "endDate",
        "type": "uint256"
      },
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "totalAmount",
        "type": "uint256"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "organization",
        "type": "address"
      },
      {
        "indexed": false,
        "internalType": "string",
        "name": "projectType",
        "type": "string"
      }
    ],
    "name": "ProjectCreated",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "_name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_description",
        "type": "string"
      },
      {
        "internalType": "uint256",
        "name": "_startDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "_endDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "_totalAmountInWei",
        "type": "uint256"
      },
      {
        "internalType": "string",
        "name": "_projectType",
        "type": "string"
      }
    ],
    "name": "addProject",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_organization",
        "type": "address"
      }
    ],
    "name": "getOrganizationProjects",
    "outputs": [
      {
        "internalType": "uint256[]",
        "name": "",
        "type": "uint256[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_id",
        "type": "uint256"
      }
    ],
    "name": "getProject",
    "outputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "description",
        "type": "string"
      },
      {
        "internalType": "uint256",
        "name": "startDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "endDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "totalAmount",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "donatedAmount",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "organization",
        "type": "address"
      },
      {
        "internalType": "string",
        "name": "projectType",
        "type": "string"
      },
      {
        "internalType": "enum PostProject.ProjectState",
        "name": "state",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getProjectCount",
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
        "name": "",
        "type": "uint256"
      }
    ],
    "name": "projectToOrganization",
    "outputs": [
      {
        "internalType": "address",
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
    "name": "projects",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "id",
        "type": "uint256"
      },
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "description",
        "type": "string"
      },
      {
        "internalType": "uint256",
        "name": "startDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "endDate",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "totalAmount",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "donatedAmount",
        "type": "uint256"
      },
      {
        "internalType": "address",
        "name": "organization",
        "type": "address"
      },
      {
        "internalType": "string",
        "name": "projectType",
        "type": "string"
      },
      {
        "internalType": "enum PostProject.ProjectState",
        "name": "state",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "_projectId",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "_amountInWei",
        "type": "uint256"
      }
    ],
    "name": "updateDonatedAmount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]''';

  BlockchainService() {
    _web3Client = Web3Client(rpcUrl, http.Client());
  }

  Future<void> verifyWalletBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('walletAddress');

    if (walletAddress == null || walletAddress.isEmpty) {
      print("❌ No wallet address found!");
      return;
    }

    try {
      EthereumAddress address = EthereumAddress.fromHex(walletAddress);
      EtherAmount balance = await _web3Client.getBalance(address);
      print(
          "💰 Wallet Balance Verified: ${balance.getValueInUnit(EtherUnit.ether)} ETH");
    } catch (e) {
      print("❌ Error fetching balance: $e");
    }
  }

  Future<void> checkBalance() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('walletAddress');

    if (walletAddress == null || walletAddress.isEmpty) {
      print("❌ No wallet address found!");
      return;
    }

    try {
      EthereumAddress address = EthereumAddress.fromHex(walletAddress);
      EtherAmount balance = await _web3Client.getBalance(address);
      print(
          "💰 Wallet Balance: ${balance.getValueInUnit(EtherUnit.ether)} ETH");
    } catch (e) {
      print("❌ Error fetching balance: $e");
    }
  }

Future<Map<String, String?>> getCharityCredentials() async {
  final prefs = await SharedPreferences.getInstance();

  // Retrieve the stored wallet address first
  final walletAddress = prefs.getString('walletAddress');

  // If wallet address is null, return early
  if (walletAddress == null) {
    print("❌ No wallet address found in SharedPreferences!");
    return {
      'privateKey': null,
      'walletAddress': null,
    };
  }

  // Retrieve the private key using the correct key format
  final privateKeyKey = 'privateKey_$walletAddress';
  String? privateKey = prefs.getString(privateKeyKey);

  if (privateKey == null) {
    print("❌ No private key found for wallet: $walletAddress.");
  } else {
    print("✅ Retrieved Private Key for wallet: $walletAddress.");
    print("✅ Retrieved Private Key: $privateKey.");
  }

  return {
    'privateKey': privateKey,
    'walletAddress': walletAddress,
  };
}



 Future<void> connect() async {
  try {
    // Retrieve the charity employee's credentials from storage
    final credentials = await getCharityCredentials();
    final walletAddress = credentials['walletAddress'];
    final privateKey = credentials['privateKey'];

    print('🔍 Retrieved Wallet Address: $walletAddress');
    print('🔍 Retrieved Private Key: ${privateKey != null ? "Exists ✅" : "Not Found ❌"}');

    if (walletAddress == null) {
      print("❌ Charity employee wallet address not found. Please log in.");
      throw Exception("Wallet address not found.");
    }

    if (privateKey == null) {
      print("❌ Private key not found. Cannot establish a secure connection.");
      throw Exception("Private key not found.");
    }

    // Initialize credentials using the private key
    _credentials = EthPrivateKey.fromHex(privateKey);
    _ownAddress = EthereumAddress.fromHex(walletAddress);

    print("✅ Successfully connected with wallet address: $_ownAddress");
  } catch (e) {
    print("⚠️ Error during wallet connection: $e");
    throw Exception("Failed to connect wallet: $e");
  }
}


  Future<void> addProject(
    String name,
    String description,
    int startDate,
    int endDate,
    double totalAmount, // Pass ETH value
    String projectType,
  ) async {
    try {
      // Ensure the charity employee is connected
      await connect();

      BigInt totalAmountInWei = BigInt.from(totalAmount * 1e18);

      final contract = await _getContract();
      final function = contract.function('addProject');

      final transactionHash = await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [
            name,
            description,
            BigInt.from(startDate),
            BigInt.from(endDate),
            totalAmountInWei, // Send Wei value
            projectType,
          ],
          gasPrice: EtherAmount.inWei(BigInt.from(20 * 1000000000)),
          maxGas: 5000000,
        ),
        chainId: 11155111, // Sepolia Testnet Chain ID
      );

      print("✅ Transaction sent. Hash: $transactionHash");
      final receipt = await _web3Client.getTransactionReceipt(transactionHash);
      //if (receipt == null || !receipt.status!) {
      //throw Exception("Transaction failed");
      //}

      print("✅ Project added successfully!");
    } catch (e) {
      print("❌ Error posting project: $e");
      throw e;
    }
  }

  Future<double> getProjectDonations(int projectId) async {
    try {
      final contract = await _getContract();
      final function = contract.function('getProjectDonations');

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [BigInt.from(projectId)],
      );

      final donatedAmountInWei = result[0] as BigInt;
      final donatedAmountInEth = donatedAmountInWei.toDouble() / 1e18;

      return donatedAmountInEth.toDouble();
    } catch (e) {
      print("❌ Error fetching donated amount: $e");
      throw e;
    }
  }

Future<String?> getWalletAddressFromPrivateKey() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final privateKey = prefs.getString('privateKey');

    if (privateKey == null || privateKey.isEmpty) {
      print("❌ No private key found in SharedPreferences.");
      return null; // Return null instead of an empty string
    }

    // Derive wallet address from the private key
    final credentials = EthPrivateKey.fromHex(privateKey);
    final walletAddress = credentials.address.hex;

    print("✅ Wallet address derived from private key: $walletAddress");
    return walletAddress;
  } catch (e) {
    print("❌ Error deriving wallet address: $e");
    return null; // Return null to indicate failure
  }
}


  Future<DeployedContract> _getContract() async {
    return DeployedContract(
      ContractAbi.fromJson(abi, 'PostProject'),
      EthereumAddress.fromHex(contractAddress),
    );
  }

  /// Get the total number of projects
  Future<int> getProjectCount() async {
    try {
      final contract = await _getContract();
      final function = contract.function('getProjectCount');
      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [],
      );
      return result[0].toInt(); // Ensure this returns a valid integer
    } catch (e) {
      print("Error fetching project count: $e");
      throw Exception("Failed to fetch project count: $e");
    }
  }

  static double weiToEth(BigInt wei) {
    //Use BigInt for precise division
    return wei / BigInt.from(10).pow(18);
  }

  /// Get project details by ID
  Future<Map<String, dynamic>> getProjectDetails(int projectId) async {
    try {
      final contract = await _getContract();
      final function = contract.function('getProject');

      var result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [BigInt.from(projectId)],
      );

      // Ensure the result is valid
      if (result.isEmpty) {
        throw Exception("No project found for ID: $projectId");
      }

      // Convert Wei to ETH
      double totalAmountInEth = weiToEth(result[4]);
      double donatedAmountInEth = weiToEth(result[5]);

      // Print to verify ETH values
      print("Total Amount in ETH: $totalAmountInEth");
      print("Donated Amount in ETH: $donatedAmountInEth");

      return {
        "id": projectId,
        "name": result[0].toString(),
        "description": result[1].toString(),
        "startDate": DateTime.fromMillisecondsSinceEpoch(
            int.parse(result[2].toString()) * 1000),
        "endDate": DateTime.fromMillisecondsSinceEpoch(
            int.parse(result[3].toString()) * 1000),
        "totalAmount": totalAmountInEth.toDouble(), // Display in ETH
        "donatedAmount": donatedAmountInEth.toDouble(), // Display in ETH
        "organization": result[6].toString(),
        "projectType": result[7].toString(), // New field
      };
    } catch (e) {
      print("Error fetching project details for ID $projectId: $e");
      return {"error": "Error fetching project details: $e"};
    }
  }

  /// Fetch all projects for a given organization address
  Future<List<Map<String, dynamic>>> fetchOrganizationProjects(
      String orgAddress) async {
    try {
      final contract = await _getContract();
      final function = contract.function("getOrganizationProjects");

      // Fetch project IDs for the given organization
      List<dynamic> projectIds = await _web3Client.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(orgAddress)],
      );

      // Flatten projectIds if it contains a list within a list
      List<dynamic> flattenedProjectIds =
          projectIds.expand((x) => x is List ? x : [x]).toList();

      List<Map<String, dynamic>> projects = [];

      for (var projectId in flattenedProjectIds) {
        // Ensure that projectId is a BigInt and convert it to int
        if (projectId is BigInt) {
          var projectDetails = await getProjectDetails(
              projectId.toInt()); // Convert BigInt to int
          projects.add(projectDetails);
        } else {
          print("Unexpected project ID type: $projectId");
        }
      }

      return projects;
    } catch (e) {
      print("❌ Error fetching organization projects: $e");
      return [];
    }
  }
}
