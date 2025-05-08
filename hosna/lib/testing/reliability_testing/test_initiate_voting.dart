import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'dart:math';

void main() {
  const String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  const String contractAddress = '0x341AB50492Ed7b479685c0DC0A2bf8b89B3eB763';
  const String privateKey = '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c'; 

  final String contractABI = ''' 
  [ 
    {
      "constant": false,
      "inputs": [
        {
          "name": "votingDuration",
          "type": "uint256"
        },
        {
          "name": "_projectIds",
          "type": "uint256[]"
        },
        {
          "name": "_projectNames",
          "type": "string[]"
        }
      ],
      "name": "initiateVoting",
      "outputs": [
        {
          "name": "",
          "type": "uint256"
        }
      ],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]
  ''';

  group('Reliability test for initiateVoting()', () {
    late Web3Client client;
    late Credentials credentials;
    late EthereumAddress contractAddr;
    late DeployedContract contract;
    late ContractFunction initiateVoting;

    setUp(() async {

      client = Web3Client(rpcUrl, Client());
      credentials = EthPrivateKey.fromHex(privateKey);
      contractAddr = EthereumAddress.fromHex(contractAddress);
      contract = DeployedContract(
        ContractAbi.fromJson(contractABI, 'CharityVoting'),
        contractAddr,
      );
      initiateVoting = contract.function('initiateVoting');
    });

   test('should reliably initiate voting multiple times', () async {
  int successCount = 0;
  int failureCount = 0;

  for (int i = 0; i < 5; i++) {
    final List<BigInt> projectIds = [
      BigInt.from(Random().nextInt(10)), 
      BigInt.from(Random().nextInt(10)),
      BigInt.from(Random().nextInt(10))
    ];

    final List<String> projectNames = [
      'Test Project A #$i',
      'Test Project B #$i',
      'Test Project C #$i'
    ];

    try {
      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: initiateVoting,
          parameters: [BigInt.from(5), projectIds, projectNames],
          maxGas: 300000,
        ),
        chainId: 11155111,
      );

      print('✅ Test #$i passed. Transaction hash: $txHash');
      successCount++;
    } catch (e) {
      print('❌ Test #$i failed. Error: $e');
      failureCount++;
    }
  }

  print('\n Test Summary ');
  print('Total: ${successCount + failureCount}');
  print('Success: $successCount');
  print('Failure: $failureCount');
  print('Reliability: ${(successCount / (successCount + failureCount) * 100).toStringAsFixed(2)}%');
});
  });
}