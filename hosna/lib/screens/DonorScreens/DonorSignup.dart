import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorLogin.dart';
import 'package:http/http.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonorSignUpPage extends StatefulWidget {
  const DonorSignUpPage({super.key});

  @override
  _DonorSignUpPageState createState() => _DonorSignUpPageState();
}

class _DonorSignUpPageState extends State<DonorSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isAgreedToTerms = false;
  bool _isRegistering = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late Web3Client _web3Client;
  late EthereumAddress _contractAddress;
  late ContractAbi _contractAbi;

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    _loadContractAbi();
  }

  void _initializeWeb3() {
    final String rpcUrl = 'https://bsc-testnet-rpc.publicnode.com';
    _web3Client = Web3Client(rpcUrl, Client());
    _contractAddress =
        EthereumAddress.fromHex("0x662b9eecf8a37d033eab58120132ac82ae1b09cf");
    print("✅ Web3 initialized with contract address: $_contractAddress");
  }

  Future<void> _loadContractAbi() async {
    try {
      final String abiString = await rootBundle.loadString('assets/abi.json');
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print("✅ Contract ABI loaded successfully");
    } catch (e) {
      print("❌ Error loading ABI: $e");
    }
  }

  String _generatePrivateKey() {
    final rng = Random.secure();
    EthPrivateKey key = EthPrivateKey.createRandom(rng);
    return bytesToHex(key.privateKey);
  }

  Future<void> _saveDonorCredentials(
      String walletAddress, String privateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String privateKeyKey = 'privateKey_$walletAddress';
      await prefs.setString('walletAddress', walletAddress);
      await prefs.setString(privateKeyKey, privateKey);
      print('✅ Saved walletAddress: $walletAddress');
      print('✅ Saved privateKey with key: $privateKeyKey');
    } catch (e) {
      print('❌ Error saving credentials: $e');
    }
  }

  Future<void> _registerDonor() async {
    if (!_formKey.currentState!.validate() || !_isAgreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please check all fields and agree to terms')),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    print("🛠 Registering donor...");

    final String ownerPrivateKey =
        "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
    final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);
    final ownerWallet = await ownerCredentials.extractAddress();
    print("🔹 Owner's wallet address (paying gas): $ownerWallet");

    final String donorPrivateKey = _generatePrivateKey();
    final donorCredentials = EthPrivateKey.fromHex(donorPrivateKey);
    final donorWallet = await donorCredentials.extractAddress();
    print("🔹 Donor Wallet Address: $donorWallet");

    final contract = DeployedContract(_contractAbi, _contractAddress);

    try {
      // Check if donor exists
      final getDonorAddressByEmailFunction =
          contract.function('getDonorAddressByEmail');
      final existingAddress = await _web3Client.call(
        contract: contract,
        function: getDonorAddressByEmailFunction,
        params: [_emailController.text.toLowerCase()],
      );

      if (existingAddress.isNotEmpty &&
          existingAddress[0] !=
              EthereumAddress.fromHex(
                  '0x0000000000000000000000000000000000000000')) {
        throw Exception('An account with this email already exists');
      }

      // Register donor
      final registerDonorFunction = contract.function('registerDonor');
      final txHash = await _web3Client.sendTransaction(
        ownerCredentials,
        Transaction.callContract(
          contract: contract,
          function: registerDonorFunction,
          parameters: [
            _firstNameController.text,
            _lastNameController.text,
            _emailController.text.toLowerCase(),
            _phoneController.text,
            donorWallet,
            _passwordController.text.trim(),
            donorPrivateKey,
          ],
          maxGas: 2000000,
        ),
        chainId: 97,
      );

      print("📤 Transaction sent: $txHash");

      // Wait for confirmation
      TransactionReceipt? receipt;
      for (int i = 0; i < 24; i++) {
        receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          break;
        }
        if (i == 23) {
          throw Exception("Transaction timed out after 2 minutes");
        }
        await Future.delayed(const Duration(seconds: 5));
        print("⏳ Waiting for confirmation... Attempt ${i + 1}/24");
      }

      if (receipt == null || !receipt.status!) {
        throw Exception("Transaction failed or was not confirmed");
      }

      print("✅ Transaction confirmed!");

      // Save credentials
      await _saveDonorCredentials(donorWallet.hex, donorPrivateKey);

      // Create Firebase user
      await _createFirebaseUser(
          _emailController.text.toLowerCase(), _passwordController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DonorLogInPage()),
      );
    } catch (e) {
      print("❌ Error registering donor: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isRegistering = false;
      });
    }
  }

  Future<void> _createFirebaseUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Firebase user created successfully");
    } catch (e) {
      print("❌ Failed to create Firebase user: $e");
      throw e;
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isRequired = true,
    bool isPassword = false,
    bool isConfirmPassword = false,
    bool isName = false,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: (isPassword && !_isPasswordVisible) ||
          (isConfirmPassword && !_isConfirmPasswordVisible),
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      inputFormatters: isPhone
          ? [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ]
          : [],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        suffixIcon: (isPassword || isConfirmPassword)
            ? IconButton(
                icon: Icon(
                  (isPassword && _isPasswordVisible) ||
                          (isConfirmPassword && _isConfirmPasswordVisible)
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    if (isPassword) {
                      _isPasswordVisible = !_isPasswordVisible;
                    } else if (isConfirmPassword) {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    }
                  });
                },
              )
            : null,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Required';
        }
        if (isEmail &&
            !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
          return 'Enter a valid email';
        }
        if (isPhone && !RegExp(r'^05\d{8}$').hasMatch(value!)) {
          return 'Phone number must start with 05 and be 10 digits';
        }
        if (isPassword &&
            !RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                .hasMatch(value!)) {
          return 'Password must be at least 8 characters with uppercase, lowercase, number, and special character';
        }
        if (isConfirmPassword && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        if (isName && !RegExp(r'^[a-zA-Z ]{2,30}$').hasMatch(value!)) {
          return 'Name must contain only letters (2-30 characters)';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sign Up',
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome to us',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                const SizedBox(height: 50),
                _buildTextField(_firstNameController, 'First Name',
                    isName: true),
                const SizedBox(height: 30),
                _buildTextField(_lastNameController, 'Last Name', isName: true),
                const SizedBox(height: 30),
                _buildTextField(_emailController, 'Email Address',
                    isEmail: true),
                const SizedBox(height: 30),
                _buildTextField(_phoneController, 'Phone Number',
                    isPhone: true, hintText: 'Must start with 05'),
                const SizedBox(height: 30),
                _buildTextField(_passwordController, 'Password',
                    obscureText: true, isPassword: true),
                const SizedBox(height: 30),
                _buildTextField(_confirmPasswordController, 'Confirm Password',
                    obscureText: true, isConfirmPassword: true),
                const SizedBox(height: 30),
                CheckboxListTile(
                  title: Text(
                    'By creating an account, you agree to our Terms and Conditions',
                    style: TextStyle(
                      fontSize: 14,
                      color: _isAgreedToTerms
                          ? const Color.fromRGBO(24, 71, 137, 1)
                          : const Color.fromARGB(255, 102, 100, 100),
                    ),
                  ),
                  value: _isAgreedToTerms,
                  onChanged: (bool? value) {
                    setState(() {
                      _isAgreedToTerms = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: const Color.fromRGBO(24, 71, 137, 1),
                ),
                const SizedBox(height: 30),
                Center(
                  child: ElevatedButton(
                    onPressed: _isRegistering ? null : _registerDonor,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                      minimumSize: const Size(300, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isRegistering
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 25),
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const DonorLogInPage()),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromARGB(255, 102, 100, 100),
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Log In',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromRGBO(24, 71, 137, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
