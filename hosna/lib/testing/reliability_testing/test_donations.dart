import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

void main() async {
  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x94F3a1791df973Bd599EC2a448e2F1A52e1cF5E3';
  final String privateKey = '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'; 
  final int projectId = 1; 
  final bool isAnonymous = false; 

  final client = Web3Client(rpcUrl, Client());
  final credentials = EthPrivateKey.fromHex(privateKey);
  final abi = '''[
    {
      "constant": false,
      "inputs": [
        {"name": "projectId", "type": "uint256"},
        {"name": "isAnonymous", "type": "bool"}
      ],
      "name": "donate",
      "outputs": [],
      "stateMutability": "payable",
      "type": "function"
    }
  ]''';

  final contract = DeployedContract(
    ContractAbi.fromJson(abi, 'DonationContract'),
    EthereumAddress.fromHex(contractAddress),
  );

  final donateFunction = contract.function('donate');

  final donationAmountInEth = 0.00001; 
  final donationAmountInWei = BigInt.from(donationAmountInEth * 1e18);

  int successCount = 0;

  for (int i = 0; i < 20; i++) {
    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: donateFunction,
          parameters: [BigInt.from(projectId), isAnonymous],
          value: EtherAmount.inWei(donationAmountInWei),
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      print("[$i] Transaction Success ✅ Hash: $txHash");
      successCount++;
    } catch (e) {
      print("[$i] Transaction Failed ❌ Error: $e");
    }
  }

  print("\nSummary:");
  print("Successful Donations: $successCount / 20");
  print("Failure Rate: ${(100 - (successCount / 20 * 100)).toStringAsFixed(2)}%");
  print("Reliability: ${(successCount / 20 * 100).toStringAsFixed(2)}%");
  client.dispose();
}