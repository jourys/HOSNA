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
  final String _contractAddress = "0xD3d7bBa269c92cb694ca27B2E7C3b6FF26b1178E";
  final String _lookupContractAddress =
      "0x798746E48755909Df18C7Fbb9486290871FB054d";

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
    _emailFocus.dispose(); // Dispose of the email focus node
    super.dispose();
    _passwordFocus.dispose();
  }

  /// ✅ Converts Uint8List to Hex String (For Solidity)
  String bytesToHex(Uint8List bytes, {bool include0x = false}) {
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return include0x ? '0x$hex' : hex;
  }

  // Uint8List hashEmail(String email) {
  //   return keccak256(utf8.encode(email.trim()));
  // }

  Uint8List hashToBytes32(String input) {
    return keccak256(utf8.encode(input.trim().toLowerCase()));
  }

  /// Hash Password Before Sending to Solidity
  Uint8List hashPassword(String password) {
    return keccak256(utf8.encode(password.trim()));
  }

// For utf8.encode()

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
        try {
          final lookupContract = DeployedContract(
            ContractAbi.fromJson(
              '[{"constant":true,"inputs":[{"name":"_email","type":"string"}],"name":"getCharityWalletAddressByEmail","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"}]',
              'CharityEmailFetcher',
            ),
            EthereumAddress.fromHex(_lookupContractAddress.toString()),
          );

          final lookupFunction =
              lookupContract.function('getCharityWalletAddressByEmail');

          print('Calling the getCharityWalletAddressByEmail function...');

          // Send the plain email without hashing to the contract
          final walletResult = await _web3Client.call(
            contract: lookupContract,
            function: lookupFunction,
            params: [email],
          );

          print('Wallet result: $walletResult');

          // Check if the result is not empty and the wallet address is valid
          if (walletResult.isNotEmpty &&
              walletResult[0] !=
                  EthereumAddress.fromHex(
                      '0x0000000000000000000000000000000000000000')) {
            final walletAddress = walletResult[0].toString();
            print('Wallet address found: $walletAddress');

            if (walletAddress.isNotEmpty) {
              try {
                final blockchainService = BlockchainService();
                final credentials =
                    await blockchainService.getCharityCredentials();
                final privateKey = credentials['privateKey'];
                if (privateKey != null) {
                  // Save the wallet address to SharedPreferences
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  // bool isSaved =
                  await prefs.setString('walletAddress', walletAddress);
                  await prefs.setString('privatekey', privateKey);

                  // if (isSaved) {
                  print(
                      'Wallet address and private key saved to SharedPreferences');
                } else {
                  print('Failed to save wallet address to SharedPreferences');
                }
              } catch (e) {
                print('Error saving wallet address: $e');
              }
            } else {
              print('Wallet address is null or empty');
            }

            // Navigate to the next screen with the wallet address
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
            print('No wallet address found or invalid address');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('No wallet address found or invalid address')),
            );
          }
        } catch (e) {
          print('❌ Error in wallet lookup: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error in wallet lookup: $e')),
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

  bool _obscureText = true; // Add this variable at the top of your class

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  final FocusNode _passwordFocus = FocusNode();

  final FocusNode _emailFocus = FocusNode();

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
            crossAxisAlignment:
                CrossAxisAlignment.start, // Align content to the left

            children: [
              Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              SizedBox(height: 80), // Space after title

              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(
                    color: _emailFocus.hasFocus
                        ? Color.fromRGBO(24, 71, 137, 1)
                        : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
                  ),
                ),
              ),
              SizedBox(height: 30), // Space between fields

              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(
                    color: _passwordFocus.hasFocus
                        ? Color.fromRGBO(24, 71, 137, 1)
                        : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                      color: _passwordFocus.hasFocus
                          ? Color.fromRGBO(24, 71, 137, 1)
                          : Colors.grey,
                    ),
                    onPressed: _togglePasswordVisibility,
                  ),
                ),
              ),
              SizedBox(height: 300), // Large space before the button

              Center(
                child: ElevatedButton(
                  onPressed: () => _authenticateCharity(),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: Size(300, 50),
                    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                          color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                    ),
                  ),
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
