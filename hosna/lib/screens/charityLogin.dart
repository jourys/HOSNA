import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/crypto.dart';
import 'charityHome.dart';

class CharityLogInPage extends StatefulWidget {
  const CharityLogInPage({super.key});

  @override
  _CharityLogInPageState createState() => _CharityLogInPageState();
}

class _CharityLogInPageState extends State<CharityLogInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late Web3Client _web3Client;
  final String _rpcUrl =
      "https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac";
  final String _contractAddress = "0xD3d7bBa269c92cb694ca27B2E7C3b6FF26b1178E";

  @override
  void initState() {
    super.initState();
    _web3Client = Web3Client(_rpcUrl, Client());
    print('✅ Web3Client initialized');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ✅ Converts Uint8List to Hex String (For Solidity)
  String bytesToHex(Uint8List bytes, {bool include0x = false}) {
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return include0x ? '0x$hex' : hex;
  }

  Uint8List hashEmail(String email) {
    return keccak256(utf8.encode(email.trim()));
  }

  Uint8List hashToBytes32(String input) {
    return keccak256(utf8.encode(input.trim().toLowerCase()));
  }

  /// Hash Password Before Sending to Solidity
  Uint8List hashPassword(String password) {
    return keccak256(utf8.encode(password.trim()));
  }

  Future<void> _authenticateCharity() async {
    print("🟢 Charity Login Button Pressed!");

    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    print("📌 Raw Email: $email");
    print("📌 Raw Password: $password");

    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[{
      "constant": true,
      "inputs": [
        {"name": "_email", "type": "string"},  
        {"name": "_password", "type": "string"}  
      ],
      "name": "loginCharity",
      "outputs": [{"name": "", "type": "bool"}],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }]''',
          'CharityAuth',
        ),
        EthereumAddress.fromHex(_contractAddress),
      );

      final loginCharityFunction = contract.function('loginCharity');

      final result = await _web3Client.call(
        contract: contract,
        function: loginCharityFunction,
        params: [email.toLowerCase(), password], // ✅ Send as plain text
      );

      print("📌 Contract call result: $result");

      if (result.isNotEmpty && result[0] == true) {
        print("✅ Login successful!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );

        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => CharityEmployeeHomePage()),
          );
        });
      } else {
        print("❌ Invalid credentials!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials!')),
        );
      }
    } catch (e) {
      print('❌ Error in authentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Charity Login')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: "Email"),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _authenticateCharity(),
                child: Text('Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
