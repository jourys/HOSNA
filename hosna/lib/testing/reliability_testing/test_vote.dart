import 'package:web3dart/json_rpc.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:async';

void main() async {
  final String rpcUrl = "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final EthereumAddress contractAddress = EthereumAddress.fromHex("0xE6bdFC7b16AB6B303C04f389B4F3B57BbAD62a15");

  final List<String> privateKeys = [
    "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c",
    "353dd3ae69d4257f6ae4c400ff8e7f0cf5add1df661f74680891f90979c0fc1b",
    "41d18b76c68ea16736643f91d29ad709f25fe829d789695154a2e7fd3381921c",
    'c93d0fa275a26cdce1750f0acbc6c5a203dd8f6069b7485338405ac8a888e173',
    'eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90',
  ];

  final String abi = '''[
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

  final client = Web3Client(rpcUrl, Client());
  final contract = DeployedContract(ContractAbi.fromJson(abi, 'CharityVoting'), contractAddress);
  final voteFunction = contract.function('vote');

  final votingId = BigInt.from(23);
  final projectIndex = BigInt.from(0);

  int successCount = 0;
  int failCount = 0;

  final stopwatch = Stopwatch()..start();

  for (int i = 0; i < privateKeys.length; i++) {
    final credentials = EthPrivateKey.fromHex(privateKeys[i]);
    final sender = await credentials.extractAddress();
    print("Attempt #${i + 1} from wallet: ${sender.hex}");

    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: voteFunction,
          parameters: [votingId, projectIndex],
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      print("✅ Transaction sent: $txHash");
      successCount++;
    } catch (e) {
      print("❌ Error during vote: $e");
      failCount++;
    }
  }

  stopwatch.stop();

  print("\nTest Summary:");
  print("Total time: ${stopwatch.elapsed}");
  print("Successful votes: $successCount");
  print("Failed votes: $failCount");

  final totalAttempts = successCount + failCount;
  final reliability = (successCount / totalAttempts) * 100;
  print("Reliability: ${reliability.toStringAsFixed(2)}%");

  client.dispose();
}