import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

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
  final String _contractAddress = "0xbCDE877f2f9043F79fc03C691E774f4289D055ED";
  final String _lookupContractAddress =
      "0xBD732aE611e101d0aDC7A792785b07ee634adDE2";
  bool _isPasswordVisible = false; // Track password visibility

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

  Future<void> _authenticateCharity() async {
    print("🟢 Charity Login Button Pressed!");

    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    print("📌 Raw Email: $email");
    print("📌 Raw Password: $password");

    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''[{"constant": true, "inputs": [{"name": "_email", "type": "string"}, {"name": "_password", "type": "string"}], "name": "loginCharity", "outputs": [{"name": "", "type": "bool"}], "payable": false, "stateMutability": "view", "type": "function"}]''',
          'CharityAuth',
        ),
        EthereumAddress.fromHex(_contractAddress),
      );

      final loginCharityFunction = contract.function('loginCharity');
      final result = await _web3Client.call(
        contract: contract,
        function: loginCharityFunction,
        params: [email, password],
      );

      print("📌 Contract call result: $result");

      if (result.isNotEmpty && result[0] == true) {
        print("✅ Login successful!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );

        // Perform wallet lookup
        String walletAddress = await _getWalletAddressByEmail(email);

        if (walletAddress.isNotEmpty) {
          // Save wallet address and private key to SharedPreferences
          await _saveWalletDetails(walletAddress);

          // Navigate to main screen
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    CharityMainScreen(walletAddress: walletAddress),
              ),
            );
          });
        } else {
          print("❌ No wallet address found!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No wallet address found!')),
          );
        }
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

  /// Fetch wallet address from contract using email
  Future<String> _getWalletAddressByEmail(String email) async {
    try {
      final lookupContract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_email","type":"string"}],"name":"getCharityWalletAddressByEmail","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"}]',
          'CharityEmailFetcher',
        ),
        EthereumAddress.fromHex(_lookupContractAddress),
      );

      final lookupFunction =
          lookupContract.function('getCharityWalletAddressByEmail');
      final walletResult = await _web3Client.call(
        contract: lookupContract,
        function: lookupFunction,
        params: [email],
      );

      if (walletResult.isNotEmpty &&
          walletResult[0] !=
              EthereumAddress.fromHex(
                  "0x0000000000000000000000000000000000000000")) {
        print("✅ Wallet Address Found: ${walletResult[0].hex}");
        return walletResult[0].hex;
      } else {
        print("❌ No valid wallet address found!");
        return "";
      }
    } catch (e) {
      print('❌ Error in wallet lookup: $e');
      return "";
    }
  }

  /// Save wallet address and private key to SharedPreferences
  Future<void> _saveWalletDetails(String walletAddress) async {
    try {
      final blockchainService = BlockchainService();
      final credentials = await blockchainService.getCharityCredentials();
      final privateKey = credentials['privateKey'];

      if (privateKey != null && privateKey.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('walletAddress', walletAddress);
        await prefs.setString('privateKey', privateKey);

        // ✅ Debug Logs
        print("✅ Private Key Successfully Saved: $privateKey");

        // 🔍 Immediately check if it is accessible
        String? storedKey = prefs.getString('privateKey');
        print("🔍 Retrieved Private Key After Saving: $storedKey");
      } else {
        print("❌ Private Key is null or empty! Check login process.");
      }
    } catch (e) {
      print("❌ Error saving wallet details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Log In',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(24, 71, 137, 1),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color.fromRGBO(24, 71, 137, 1),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(24, 71, 137, 1))),
              SizedBox(height: 80),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                    labelText: 'Email Address', border: OutlineInputBorder()),
              ),
              SizedBox(height: 30),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible, // Toggle visibility
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () => _authenticateCharity(),
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(300, 50),
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1)),
                  child: Text('Log In',
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}