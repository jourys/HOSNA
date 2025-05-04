import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';


class PostProjectTester {
  final String rpcUrl = 'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x1e2140d77C1109f68bFfD126a75f3aa92Ad3bDBA';
  final String privateKey = '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'; // Replace with test private key

  late Web3Client _client;
  late EthPrivateKey _credentials;
  late EthereumAddress _ownAddress;
  late DeployedContract _contract;

  final String abi = '''[
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "projectId", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "donor", "type": "address" },
      { "indexed": false, "internalType": "uint256", "name": "amount", "type": "uint256" }
    ],
    "name": "DonationReceived",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": false, "internalType": "uint256", "name": "id", "type": "uint256" },
      { "indexed": false, "internalType": "string", "name": "name", "type": "string" },
      { "indexed": false, "internalType": "string", "name": "description", "type": "string" },
      { "indexed": false, "internalType": "uint256", "name": "startDate", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "endDate", "type": "uint256" },
      { "indexed": false, "internalType": "uint256", "name": "totalAmount", "type": "uint256" },
      { "indexed": true, "internalType": "address", "name": "organization", "type": "address" },
      { "indexed": false, "internalType": "string", "name": "projectType", "type": "string" }
    ],
    "name": "ProjectCreated",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "string", "name": "_name", "type": "string" },
      { "internalType": "string", "name": "_description", "type": "string" },
      { "internalType": "uint256", "name": "_startDate", "type": "uint256" },
      { "internalType": "uint256", "name": "_endDate", "type": "uint256" },
      { "internalType": "uint256", "name": "_totalAmountInWei", "type": "uint256" },
      { "internalType": "string", "name": "_projectType", "type": "string" }
    ],
    "name": "addProject",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "_organization", "type": "address" }
    ],
    "name": "getOrganizationProjects",
    "outputs": [
      { "internalType": "uint256[]", "name": "", "type": "uint256[]" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_id", "type": "uint256" }
    ],
    "name": "getProject",
    "outputs": [
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "string", "name": "description", "type": "string" },
      { "internalType": "uint256", "name": "startDate", "type": "uint256" },
      { "internalType": "uint256", "name": "endDate", "type": "uint256" },
      { "internalType": "uint256", "name": "totalAmount", "type": "uint256" },
      { "internalType": "uint256", "name": "donatedAmount", "type": "uint256" },
      { "internalType": "address", "name": "organization", "type": "address" },
      { "internalType": "string", "name": "projectType", "type": "string" },
      { "internalType": "enum PostProject.ProjectState", "name": "state", "type": "uint8" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getProjectCount",
    "outputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "name": "projectToOrganization",
    "outputs": [
      { "internalType": "address", "name": "", "type": "address" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "name": "projects",
    "outputs": [
      { "internalType": "uint256", "name": "id", "type": "uint256" },
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "string", "name": "description", "type": "string" },
      { "internalType": "uint256", "name": "startDate", "type": "uint256" },
      { "internalType": "uint256", "name": "endDate", "type": "uint256" },
      { "internalType": "uint256", "name": "totalAmount", "type": "uint256" },
      { "internalType": "uint256", "name": "donatedAmount", "type": "uint256" },
      { "internalType": "address", "name": "organization", "type": "address" },
      { "internalType": "string", "name": "projectType", "type": "string" },
      { "internalType": "enum PostProject.ProjectState", "name": "state", "type": "uint8" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_projectId", "type": "uint256" },
      { "internalType": "uint256", "name": "_amountInWei", "type": "uint256" }
    ],
    "name": "updateDonatedAmount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]'''; // Paste your full ABI here

  PostProjectTester() {
    _client = Web3Client(rpcUrl, Client());
    _credentials = EthPrivateKey.fromHex(privateKey);
    _ownAddress = _credentials.address;
  }

  Future<void> runTests(int count) async {
    print("Starting $count post project tests...\n");
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < count; i++) {
      try {
        final name = "Test Project #$i";
        final description = "This is a test project";
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final startDate = now;
        final endDate = now + 604800; // +7 days
        final amount = 0.01 ; 
        final projectType = "Health";

        print("Posting project $i...");
        await addProject(name, description, startDate, endDate, amount, projectType);
        successCount++;
      } catch (e) {
        print("❌ Failed to post project $i: $e");
        failCount++;
      }
    }

    print("\n Test Summary ");
    print("✅ Success: $successCount");
    print("❌ Failed: $failCount");
  }

  Future<DeployedContract> _getContract() async {
    final contract = DeployedContract(
      ContractAbi.fromJson(abi, 'PostProject'),
      EthereumAddress.fromHex(contractAddress),
    );
    return contract;
  }

  Future<void> addProject(
    String name,
    String description,
    int startDate,
    int endDate,
    double totalAmount,
    String projectType,
  ) async {
    final contract = await _getContract();
    final function = contract.function('addProject');
    final totalAmountInWei = BigInt.from(totalAmount * 1e18);

    await _client.sendTransaction(
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
        gasPrice: await _client.getGasPrice(),
        maxGas: 300000,
      ),
      chainId: 11155111,
    );

    print("✅ Project posted successfully.");
  }
}

void main() async {
  final tester = PostProjectTester();
  await tester.runTests(5); 
}