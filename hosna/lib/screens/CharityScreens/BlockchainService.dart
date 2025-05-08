import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xb03502E0bfB7df492F95619BB33E074D87132caD';
  final String votingContractAddress =
      '0x10cB71B23561853CB19fEB587f31B1962b4fc802';
  late Web3Client _web3Client;
  late EthPrivateKey _credentials;
  late EthereumAddress _ownAddress;
  late DeployedContract _contract;

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

  Future<void> _loadContract() async {
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, "CharityContract"),
      EthereumAddress.fromHex(contractAddress),
    );
  }



Future<void> sendEth(String toAddress) async {
  final privateKey = '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c';
  final rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // Replace with your Infura endpoint or use Alchemy

  final httpClient = http.Client();
  final ethClient = Web3Client(rpcUrl, httpClient);

  final credentials = EthPrivateKey.fromHex(privateKey);
  final myAddress = await credentials.extractAddress();

  final transaction = Transaction(
    to: EthereumAddress.fromHex(toAddress),
    from: myAddress,
    value: EtherAmount.fromUnitAndValue(EtherUnit.ether, 0.03),
    gasPrice: await ethClient.getGasPrice(),
    maxGas: 21000,
  );

  try {
    final txHash = await ethClient.sendTransaction(
      credentials,
      transaction,
      chainId: 11155111, // Sepolia testnet chain ID
    );

    print('Transaction sent. Hash: $txHash');
  } catch (e) {
    print('Transaction failed: $e');
  } finally {
    httpClient.close();
  }
}


  Future<List<Map<String, dynamic>>> getFailedOrCanceledProjects(
      BlockchainService blockchainService) async {
    List<Map<String, dynamic>> filteredProjects = [];

    try {
      int count = await blockchainService.getProjectCount();

      for (int i = 0; i < count; i++) {
        final project = await blockchainService.getProjectDetails(i);

        if (!project.containsKey('error')) {
          final status = project['status'].toString().toLowerCase();

          if (status == 'active') {
            filteredProjects.add(project);
          }
        }
      }
    } catch (e) {
      print('Error while filtering projects: $e');
    }

    return filteredProjects;
  }

  Future<double> getTotalFailedProjectAmount() async {
    try {
      await _loadContract();
      final function = _contract.function("getFailedProjects");

      final result = await _web3Client.call(
        contract: _contract,
        function: function,
        params: [],
      );

      double totalFailedAmount = 0.0;
      final failedProjectIds = result[0] as List<dynamic>;

      for (var projectId in failedProjectIds) {
        try {
          final projectDetails = await getProjectDetails(projectId.toInt());
          final amount = (projectDetails["totalAmount"] ?? 0).toDouble();
          totalFailedAmount += amount;
        } catch (e) {
          print("⚠️ Error fetching details for project ID $projectId: $e");
        }
      }

      return totalFailedAmount;
    } catch (e) {
      print("❌ Error fetching failed projects: $e");
      return 0.0;
    }
  }

  Future<void> initiateVoting(BigInt projectId, List<BigInt> selectedProjectIds,
      BigInt startDate, BigInt endDate) async {
    try {
      await connect(); // Ensure you are authenticated

      // First check if project is in Failed state
      final projectDetails = await getProjectDetails(projectId.toInt());
      print("📊 Project state check:");
      print("- Project ID: $projectId");
      print("- Current state: ${projectDetails['state']}");
      print("- Total amount: ${projectDetails['totalAmount']} ETH");
      print("- Donated amount: ${projectDetails['donatedAmount']} ETH");
      print("- End date: ${projectDetails['endDate']}");

      if (projectDetails['state'] != 4) {
        print(
            "Project must be in Failed state to initiate voting. Current state: ${projectDetails['state']}");
        return;
      }

      // Check if all selected projects are active
      for (var optionId in selectedProjectIds) {
        final optionDetails = await getProjectDetails(optionId.toInt());
        print("📊 Option project check:");
        print("- Option ID: $optionId");
        print("- Current state: ${optionDetails['state']}");

        if (optionDetails['state'] != 1) {
          // 1 is Active state
          throw Exception(
              "Selected project ${optionId} is not active. All voting options must be active projects.");
        }
      }

      // ✅ Load the voting contract
      final votingContract = await _getVotingContract();
      final function = votingContract.function("initiateVote");

      print("📝 Initiating voting for project $projectId");
      print("📝 Selected options: $selectedProjectIds");
      print("📝 Start date: $startDate");
      print("📝 End date: $endDate");

      // ✅ Call the transaction
      final result = await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: votingContract,
          function: function,
          parameters: [projectId, selectedProjectIds, startDate, endDate],
          gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      print("✅ Voting initiated successfully! Transaction: $result");
    } catch (e) {
      print("❌ Error initiating voting: $e");
      throw e;
    }
  }

  /// **Fetch active voting sessions**
  Future<List<Map<String, dynamic>>> getActiveVotingSessions() async {
    try {
      await connect();
      final votingContract = await _getVotingContract();
      final function = votingContract.function('getActiveVotings');

      print("🔍 Fetching active voting sessions...");
      print("📝 Contract address: ${votingContract.address.hex}");
      print("📝 Function name: ${function.name}");

      try {
        final result = await _web3Client.call(
          contract: votingContract,
          function: function,
          params: [],
        );

        print("📊 Raw result: $result");

        if (result.isEmpty) {
          print("ℹ️ No active voting sessions found");
          return [];
        }

        // The contract returns 4 arrays: projectIds, optionIds, startTimes, endTimes
        final projectIds = result[0] as List<BigInt>;
        final optionIds = result[1] as List<List<BigInt>>;
        final startTimes = result[2] as List<BigInt>;
        final endTimes = result[3] as List<BigInt>;

        print("📊 Found ${projectIds.length} active voting sessions");

        List<Map<String, dynamic>> activeVotings = [];
        for (int i = 0; i < projectIds.length; i++) {
          try {
            final projectDetails =
                await getProjectDetails(projectIds[i].toInt());
            activeVotings.add({
              'projectId': projectIds[i].toInt(),
              'projectName': projectDetails['name'],
              'startTime': startTimes[i].toInt(),
              'endTime': endTimes[i].toInt(),
              'optionIds': optionIds[i].map((id) => id.toInt()).toList(),
            });
          } catch (e) {
            print("⚠️ Error processing voting session ${projectIds[i]}: $e");
          }
        }

        print("✅ Active voting sessions processed successfully");
        return activeVotings;
      } catch (e) {
        if (e.toString().contains("execution reverted")) {
          print("ℹ️ No active voting sessions found (execution reverted)");
          return [];
        }
        rethrow;
      }
    } catch (e) {
      print("❌ Error fetching active voting sessions: $e");
      // Return empty list instead of throwing error
      return [];
    }
  }

  /// **Check if the donor has already voted**
  Future<bool> hasDonorVoted(int projectId, String donorAddress) async {
    try {
      await _loadContract();
      final function = _contract.function("hasVoted");

      final result = await _web3Client.call(
        contract: _contract,
        function: function,
        params: [BigInt.from(projectId), EthereumAddress.fromHex(donorAddress)],
      );

      return result[0];
    } catch (e) {
      print("❌ Error checking donor vote status: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllProjects() async {
    try {
      await _loadContract();
      final function = _contract.function("getProjectCount");

      // Fetch total number of projects
      final result = await _web3Client.call(
        contract: _contract,
        function: function,
        params: [],
      );

      int projectCount = result[0].toInt();
      print("📌 Total Projects Found: $projectCount");

      List<Map<String, dynamic>> allProjects = [];

      // Loop through all project IDs and get details
      for (int i = 0; i < projectCount; i++) {
        var projectDetails = await getProjectDetails(i);

        if (projectDetails.isNotEmpty) {
          print("➡️ Project Fetched: $projectDetails");
          allProjects.add(projectDetails);
        }
      }

      return allProjects;
    } catch (e) {
      print("❌ Error fetching all projects: $e");
      return [];
    }
  }

  final String votingAbi = '''
[
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" },
      { "internalType": "uint256[]", "name": "_optionProjectIds", "type": "uint256[]" },
      { "internalType": "uint256", "name": "_startDate", "type": "uint256" },
      { "internalType": "uint256", "name": "_endDate", "type": "uint256" }
    ],
    "name": "addVoting",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" },
      { "internalType": "uint256", "name": "_optionIndex", "type": "uint256" }
    ],
    "name": "submitVote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" }
    ],
    "name": "getVotingResults",
    "outputs": [
      { "internalType": "uint256[]", "name": "", "type": "uint256[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" },
      { "internalType": "address", "name": "_donor", "type": "address" }
    ],
    "name": "hasVoted",
    "outputs": [
      { "internalType": "bool", "name": "", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getActiveVotings",
    "outputs": [
      { "internalType": "uint256[]", "name": "", "type": "uint256[]" },
      { "internalType": "uint256[][]", "name": "", "type": "uint256[][]" },
      { "internalType": "uint256[]", "name": "", "type": "uint256[]" },
      { "internalType": "uint256[]", "name": "", "type": "uint256[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" }
    ],
    "name": "hasExistingVoting",
    "outputs": [
      { "internalType": "bool", "name": "", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" },
      { "internalType": "address", "name": "_donor", "type": "address" }
    ],
    "name": "hasDonated",
    "outputs": [
      { "internalType": "bool", "name": "", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" }
    ],
    "name": "getVotingOptions",
    "outputs": [
      { "internalType": "string[]", "name": "", "type": "string[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  Future<List<Map<String, dynamic>>> getFailedProjectsForDonor(
      String donorAddress) async {
    try {
      await _loadContract();
      final function = _contract.function("getFailedProjectsForDonor");

      print("🔍 Fetching failed projects for donor: $donorAddress");

      final result = await _web3Client.call(
        contract: _contract,
        function: function,
        params: [EthereumAddress.fromHex(donorAddress)],
      );

      if (result.isEmpty || result[0].isEmpty) {
        print("⚠️ No failed projects found for donor: $donorAddress");
        return [];
      }

      print("✅ Raw Failed Project IDs: ${result[0]}");

      List<Map<String, dynamic>> failedProjects = [];
      for (var projectId in result[0]) {
        var projectDetails = await getProjectDetails(projectId.toInt());
        if (projectDetails.isNotEmpty && projectDetails.containsKey("id")) {
          failedProjects.add(projectDetails);
        }
      }

      print("✅ Retrieved Failed Projects: $failedProjects");
      return failedProjects;
    } catch (e) {
      print(
          "❌ Critical Error fetching failed projects for donor $donorAddress: $e");
      return []; // Always return an empty list to prevent crashes
    }
  }

  Future<DeployedContract> _getVotingContract() async {
    return DeployedContract(
      ContractAbi.fromJson(votingAbi, 'VotingContract'),
      EthereumAddress.fromHex(votingContractAddress),
    );
  }

  /// **Submit Vote**
  Future<void> submitVote(
      int projectId, String selectedOption, String donorAddress) async {
    try {
      await connect();

      // Get the voting ID
      final votingContract = await _getVotingContract();
      final votingIdFunction = votingContract.function('projectToVoting');
      final votingIdResult = await _web3Client.call(
        contract: votingContract,
        function: votingIdFunction,
        params: [BigInt.from(projectId)],
      );

      if (votingIdResult.isEmpty || votingIdResult[0] == BigInt.zero) {
        throw Exception("No active voting found for this project");
      }

      final votingId = votingIdResult[0] as BigInt;

      // Get the option ID
      final optionsFunction = votingContract.function('getAvailableOptions');
      final optionsResult = await _web3Client.call(
        contract: votingContract,
        function: optionsFunction,
        params: [votingId],
      );

      if (optionsResult.isEmpty || optionsResult[0].isEmpty) {
        throw Exception("No voting options found");
      }

      List<BigInt> optionIds = (optionsResult[0] as List).cast<BigInt>();
      BigInt selectedOptionId = BigInt.zero; // Default to refund option

      if (selectedOption != "Request a Refund") {
        // Find the project ID for the selected option
        for (var id in optionIds) {
          if (id != BigInt.zero) {
            final projectDetails = await getProjectDetails(id.toInt());
            if (projectDetails['name'] == selectedOption) {
              selectedOptionId = id;
              break;
            }
          }
        }
      }

      // Submit the vote
      final voteFunction = votingContract.function('vote');
      final result = await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: votingContract,
          function: voteFunction,
          parameters: [votingId, selectedOptionId],
          gasPrice: EtherAmount.inWei(BigInt.from(20000000000)),
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      print("✅ Vote submitted successfully! Transaction: $result");
    } catch (e) {
      print("❌ Error submitting vote: $e");
      throw e;
    }
  }

Future<TransactionReceipt?> waitForReceipt(String txHash) async {
  const int maxTries = 20;
  const Duration delay = Duration(seconds: 3);

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

  /// **Fetch voting results**
  Future<Map<String, int>> getVotingResults(int projectId) async {
    try {
      final votingContract = await _getVotingContract();
      final function = votingContract.function('getVotingResults');

      final result = await _web3Client.call(
        contract: votingContract,
        function: function,
        params: [BigInt.from(projectId)],
      );

      Map<String, int> results = {};
      if (result.isEmpty || result[0].isEmpty || result[1].isEmpty) {
        print("⚠️ No votes found for project ID $projectId");
        return {}; // Return an empty map if no votes exist
      }

      List<String> options = List<String>.from(result[0]);
      List<BigInt> votes = List<BigInt>.from(result[1]);

      for (int i = 0; i < options.length; i++) {
        results[options[i]] = votes[i].toInt();
      }

      return results;
    } catch (e) {
      print("❌ Error fetching voting results: $e");
      return {};
    }
  }

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
      print(
          '🔍 Retrieved Private Key: ${privateKey != null ? "Exists ✅" : "Not Found ❌"}');

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

  Future<void> cancelPendingTransaction() async {
    try {
      // Step 1: Ensure the wallet is connected
      await connect();

      // Step 2: Get your wallet address
      final address = await _credentials.extractAddress();

      // Step 3: Get the current pending nonce (should match the stuck transaction)
      final nonce = await _web3Client.getTransactionCount(
        address,
        atBlock: const BlockNum.pending(),
      );

      // Step 4: Send a 0 ETH transaction to yourself with higher gas price
      final txHash = await _web3Client.sendTransaction(
        _credentials,
        Transaction(
          to: address, // Sending to self
          value: EtherAmount.zero(), // 0 ETH
          gasPrice: EtherAmount.inWei(
              BigInt.from(2 * 1000000000)), // 2 Gwei (higher than old tx)
          maxGas: 21000, // Minimum required gas for basic tx
          nonce: nonce, // Use same nonce to replace the pending tx
        ),
        chainId: 11155111, // Sepolia
      );

      print("✅ Fake transaction sent to cancel pending tx. Hash: $txHash");
    } catch (e) {
      print("❌ Failed to cancel pending transaction: $e");
      throw e;
    }
  }

 Future<String> addProject(
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

    checkBalance();

    final estimatedGas = await _web3Client.estimateGas(
      sender: _ownAddress,
      to: EthereumAddress.fromHex(contractAddress),
      data: function.encodeCall([
        name,
        description,
        BigInt.from(startDate),
        BigInt.from(endDate),
        totalAmountInWei,
        projectType,
      ]),
    );

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
          totalAmountInWei,
          projectType,
        ],
        gasPrice: await _web3Client.getGasPrice(),
        maxGas: estimatedGas.toInt(),
      ),
      chainId: 11155111,
    );

    print("✅ Transaction sent. Hash: $transactionHash");

    // Optional: wait for receipt here, or let the UI handle it
    // final receipt = await _web3Client.getTransactionReceipt(transactionHash);

    return transactionHash; // ✅ Return the hash
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
        var projectDetails = await getProjectDetails(projectId.toInt());
        
        // Ensure projectId is included for sorting
        projectDetails['projectId'] = projectId.toInt();

        projects.add(projectDetails);
      } else {
        print("Unexpected project ID type: $projectId");
      }
    }

    // Sort by projectId in descending order
    projects.sort((a, b) => b['projectId'].compareTo(a['projectId']));

    return projects;
  } catch (e) {
    print("❌ Error fetching organization projects: $e");
    return [];
  }
}

  // Check if voting exists for a project
  Future<bool> hasExistingVoting(int projectId) async {
    try {
      final votingContract = await _getVotingContract();
      final function = votingContract.function('projectToVoting');

      final result = await _web3Client.call(
        contract: votingContract,
        function: function,
        params: [BigInt.from(projectId)],
      );

      if (result.isEmpty || result[0] == null) {
        print("⚠️ No voting status found for project ID $projectId");
        return false;
      }

      final votingId = result[0] as BigInt;
      final hasVoting = votingId != BigInt.zero;

      print(
          "📊 Project $projectId has voting: $hasVoting (Voting ID: $votingId)");
      return hasVoting;
    } catch (e) {
      print("❌ Error checking existing voting for project ID $projectId: $e");
      return false;
    }
  }

  // Check if a donor has donated to a project
  Future<bool> hasDonatedToProject(int projectId, String donorAddress) async {
    try {
      final votingContract = await _getVotingContract();
      final function = votingContract.function('hasDonated');

      print(
          "🔍 Checking if donor $donorAddress has donated to project $projectId");

      final result = await _web3Client.call(
        contract: votingContract,
        function: function,
        params: [BigInt.from(projectId), EthereumAddress.fromHex(donorAddress)],
      );

      if (result.isEmpty) {
        print("⚠️ No donation data found for project $projectId");
        return false;
      }

      final hasDonated = result[0] as bool;
      print(
          "📊 Donation status for project $projectId: ${hasDonated ? "Donated ✅" : "Not Donated ❌"}");
      return hasDonated;
    } catch (e) {
      print("❌ Error checking donation status: $e");
      return false;
    }
  }

  // Get voting options for a project
  Future<List<String>> getVotingOptions(int projectId) async {
    try {
      final votingContract = await _getVotingContract();

      // First get the voting ID
      final votingIdFunction = votingContract.function('projectToVoting');
      final votingIdResult = await _web3Client.call(
        contract: votingContract,
        function: votingIdFunction,
        params: [BigInt.from(projectId)],
      );

      if (votingIdResult.isEmpty || votingIdResult[0] == BigInt.zero) {
        print("⚠️ No voting found for project ID $projectId");
        return [];
      }

      final votingId = votingIdResult[0] as BigInt;

      // Then get the available options
      final optionsFunction = votingContract.function('getAvailableOptions');
      final optionsResult = await _web3Client.call(
        contract: votingContract,
        function: optionsFunction,
        params: [votingId],
      );

      if (optionsResult.isEmpty || optionsResult[0].isEmpty) {
        print("⚠️ No options found for voting ID $votingId");
        return [];
      }

      List<BigInt> optionIds = (optionsResult[0] as List).cast<BigInt>();
      List<String> options = [];

      for (var id in optionIds) {
        if (id == BigInt.zero) {
          options.add("Request a Refund");
        } else {
          // Get project name for this option
          final projectDetails = await getProjectDetails(id.toInt());
          options.add(projectDetails['name'] ?? "Project ${id}");
        }
      }

      print("✅ Found voting options: $options");
      return options;
    } catch (e) {
      print("❌ Error getting voting options: $e");
      return [];
    }
  }

  // Submit a vote for a donor
  Future<void> submitDonorVote(
    int projectId,
    String selectedOption,
    String donorAddress,
  ) async {
    try {
      final votingContract = DeployedContract(
        ContractAbi.fromJson(votingAbi, 'VotingContract'),
        EthereumAddress.fromHex(votingContractAddress),
      );

      final function = votingContract.function('submitVote');
      await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: votingContract,
          function: function,
          parameters: [
            BigInt.from(projectId),
            selectedOption,
            EthereumAddress.fromHex(donorAddress),
          ],
        ),
        chainId: 11155111,
      );
    } catch (e) {
      print("Error submitting vote: $e");
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getAllVotingSessions() async {
    try {
      await connect();
      final votingContract = await _getVotingContract();
      final function = votingContract.function('getAllVotings');

      print("🔍 Fetching all voting sessions...");
      print("📝 Contract address: ${votingContract.address.hex}");
      print("📝 Function name: ${function.name}");

      try {
        final result = await _web3Client.call(
          contract: votingContract,
          function: function,
          params: [],
        );

        print("📊 Raw result: $result");

        if (result.isEmpty) {
          print("ℹ️ No voting sessions found");
          return [];
        }

        // The contract returns 4 arrays: projectIds, optionIds, startTimes, endTimes
        final projectIds = result[0] as List<BigInt>;
        final optionIds = result[1] as List<List<BigInt>>;
        final startTimes = result[2] as List<BigInt>;
        final endTimes = result[3] as List<BigInt>;

        print("📊 Found ${projectIds.length} voting sessions");

        List<Map<String, dynamic>> votingSessions = [];
        for (int i = 0; i < projectIds.length; i++) {
          try {
            final projectDetails =
                await getProjectDetails(projectIds[i].toInt());
            votingSessions.add({
              'projectId': projectIds[i].toInt(),
              'projectName': projectDetails['name'],
              'startTime': startTimes[i].toInt(),
              'endTime': endTimes[i].toInt(),
              'optionIds': optionIds[i].map((id) => id.toInt()).toList(),
              'status': 1, // Active by default
            });
          } catch (e) {
            print("⚠️ Error processing voting session ${projectIds[i]}: $e");
          }
        }

        print("✅ Voting sessions processed successfully");
        return votingSessions;
      } catch (e) {
        if (e.toString().contains("execution reverted")) {
          print("ℹ️ No voting sessions found (execution reverted)");
          return [];
        }
        rethrow;
      }
    } catch (e) {
      print("❌ Error fetching voting sessions: $e");
      // Return empty list instead of throwing error
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjectsAwaitingVote(
      String donorAddress) async {
    try {
      if (donorAddress.isEmpty) {
        print("⚠️ Empty donor address provided");
        return [];
      }

      // Get all active voting sessions
      final activeVotings = await getActiveVotingSessions();
      List<Map<String, dynamic>> votingProjects = [];

      for (var voting in activeVotings) {
        // Check if the donor has already voted
        bool hasVoted = await hasDonorVoted(voting['projectId'], donorAddress);

        // Check if the donor has donated to the project
        bool hasDonated =
            await hasDonatedToProject(voting['projectId'], donorAddress);

        // Only include projects where the donor has donated but hasn't voted yet
        if (hasDonated && !hasVoted) {
          final projectDetails = await getProjectDetails(voting['projectId']);
          if (projectDetails.containsKey('name')) {
            projectDetails['votingId'] = voting['projectId'];
            projectDetails['votingDeadline'] =
                DateTime.fromMillisecondsSinceEpoch(voting['endTime'] * 1000)
                    .toString();
            votingProjects.add(projectDetails);
          }
        }
      }

      print(
          "📊 Found ${votingProjects.length} projects awaiting vote for donor $donorAddress");
      return votingProjects;
    } catch (e) {
      print("❌ Error getting projects awaiting vote: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjectDonors(int projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');

      if (address == null) {
        print("❌ No wallet address found");
        return [];
      }

      final contract = await _getContract();
      final function = contract.function('hasDonatedToProject');

      print("🔍 Checking if donor $address has donated to project $projectId");

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [BigInt.from(projectId), EthereumAddress.fromHex(address)],
      );

      if (result.isEmpty) {
        print("⚠️ No donation data found for project $projectId");
        return [];
      }

      final hasDonated = result[0] as bool;

      if (!hasDonated) {
        print("ℹ️ Donor has not donated to project $projectId");
        return [];
      }

      // Get project details to include in the result
      final projectDetails = await getProjectDetails(projectId);

      if (projectDetails.containsKey('error')) {
        print("⚠️ Error getting project details: ${projectDetails['error']}");
        return [];
      }

      // Get the donated amount
      final donationFunction = contract.function('getProjectDonations');
      final donationResult = await _web3Client.call(
        contract: contract,
        function: donationFunction,
        params: [BigInt.from(projectId)],
      );

      final donatedAmount = donationResult[0] as BigInt;

      // Return project details with donation amount
      return [
        {
          'id': projectId,
          'name': projectDetails['name'],
          'description': projectDetails['description'],
          'donatedAmount':
              donatedAmount.toDouble() / 1e18, // Convert from wei to ETH
          'totalAmount': projectDetails['totalAmount'],
          'projectType': projectDetails['projectType'],
          'endDate': projectDetails['endDate'],
          'projectCreatorWallet': projectDetails['organization'],
        }
      ];
    } catch (e) {
      print("❌ Error fetching project donors: $e");
      return [];
    }
  }

  // Get donor's specific donation amounts for a project
  Future<Map<String, dynamic>?> getDonorInfo(
      int projectId, String donorAddress) async {
    try {
      final contract = await _getContract();
      final function = contract.function('getDonorInfo');

      print(
          "🔍 Getting donor info for project $projectId and donor $donorAddress");

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [BigInt.from(projectId), EthereumAddress.fromHex(donorAddress)],
      );

      if (result.isEmpty) {
        print("⚠️ No donor info found for project $projectId");
        return null;
      }

      final anonymousAmount = result[0] as BigInt;
      final nonAnonymousAmount = result[1] as BigInt;

      print("📊 Donor info for project $projectId:");
      print("   - Anonymous amount: ${anonymousAmount.toDouble() / 1e18} ETH");
      print(
          "   - Non-anonymous amount: ${nonAnonymousAmount.toDouble() / 1e18} ETH");

      return {
        'anonymousAmount': anonymousAmount,
        'nonAnonymousAmount': nonAnonymousAmount,
      };
    } catch (e) {
      print("❌ Error getting donor info: $e");
      return null;
    }
  }

  Future<double> fetchDonatedAmountForProject(int projectId) async {
    try {
      final contract =
          await _getContract(); // Replace with your contract loading logic
      final getProjectFunction = contract.function('getProject');

      final result = await _web3Client.call(
        contract: contract,
        function: getProjectFunction,
        params: [BigInt.from(projectId)],
      );

      // result[5] = donatedAmount in Wei
      BigInt donatedAmountInWei = result[5] as BigInt;

      // Convert from Wei to Ether
      double donatedInEth = donatedAmountInWei / BigInt.from(10).pow(18);

      print(
          "🔵 Fetched donated amount for project $projectId: $donatedInEth ETH");
      return donatedInEth;
    } catch (e) {
      print("🔻 Error fetching donated amount for project $projectId: $e");
      return 0.0;
    }
  }
}
