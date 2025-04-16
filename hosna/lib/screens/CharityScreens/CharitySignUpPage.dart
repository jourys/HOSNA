import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:hosna/screens/CharityScreens/charityLogin.dart';
import 'package:http/http.dart';
import 'package:web3dart/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharitySignUpPage extends StatefulWidget {
  const CharitySignUpPage({super.key});

  @override
  _CharitySignUpPageState createState() => _CharitySignUpPageState();
}

class _CharitySignUpPageState extends State<CharitySignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _organizationEmailController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _organizationCityController =
      TextEditingController();
  final TextEditingController _organizationDescriptionController =
      TextEditingController();
  final TextEditingController _organizationURLController =
      TextEditingController();
  final TextEditingController _establishmentDateController =
      TextEditingController();

  bool _isAgreedToTerms = false;

  late Web3Client _web3Client;
  late EthereumAddress _contractAddress;

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
  }

  void _initializeWeb3() {
    final String rpcUrl =
        'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
    _web3Client = Web3Client(rpcUrl, Client());
    _contractAddress =
        EthereumAddress.fromHex("0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7");
    print("✅ Web3 initialized with contract address: $_contractAddress");
  }

  String _generatePrivateKey() {
    final rng = Random.secure();
    EthPrivateKey key = EthPrivateKey.createRandom(rng);
    return bytesToHex(key.privateKey);
  }

  Future<void> saveCharityCredentials(
      String walletAddress, String privateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('walletAddress', walletAddress);
    await prefs.setString('privateKey', privateKey);
    print('✅ Saved walletAddress: $walletAddress');
    print('✅ Saved privateKey: $privateKey');
  }

  Uint8List hashPassword(String password) {
    Uint8List fullHash = keccak256(utf8.encode(password.trim()));
    return fullHash.sublist(0, 32); // Ensure it's exactly bytes32
  }

  Future<void> _registerCharity() async {
    print("🛠 Registering charity...");

    final String ownerPrivateKey =
        "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c";
    final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);
    final ownerWallet = await ownerCredentials.extractAddress();
    print("🔹 Owner's wallet address (paying gas): $ownerWallet");

    final String charityPrivateKey = _generatePrivateKey();
    final charityCredentials = EthPrivateKey.fromHex(charityPrivateKey);
    final charityWallet = await charityCredentials.extractAddress();
    print("🔹 Charity Wallet Address: $charityWallet");
    print("🔹 Charity Wallet private Address: $charityPrivateKey");
    // await saveCharityCredentials(charityWallet.toString(), charityPrivateKey);

    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[{
          "constant": false,
          "inputs": [
            {"name": "_name", "type": "string"},
            {"name": "_email", "type": "string"},
            {"name": "_phone", "type": "string"},
            {"name": "_licenseNumber", "type": "string"},
            {"name": "_city", "type": "string"},
            {"name": "_description", "type": "string"},
            {"name": "_website", "type": "string"},
            {"name": "_establishmentDate", "type": "string"},
            {"name": "_wallet", "type": "address"},
  {"name": "_password", "type": "string"}          ],
          "name": "registerCharity",
          "outputs": [],
          "payable": false,
          "stateMutability": "nonpayable",
          "type": "function"
        }]''',
        'CharityRegistry',
      ),
      _contractAddress,
    );

    final registerCharity = contract.function('registerCharity');

    //  Check if the email is already registered
    try {
      final existingCharity = await _web3Client.call(
        contract: contract,
        function: contract.function('getCharityAddressByEmail'),
        params: [_organizationEmailController.text.toLowerCase()],
      );

      if (existingCharity.isNotEmpty &&
          existingCharity[0] !=
              EthereumAddress.fromHex(
                  "0x0000000000000000000000000000000000000000")) {
        print("❌ Charity with this email already exists!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Charity with this email is already registered!')),
        );
        return;
      }
    } catch (e) {
      print("ℹ️ No existing charity found, proceeding with registration.");
    }

    try {
      final result = await _web3Client.sendTransaction(
        ownerCredentials,
        web3.Transaction.callContract(
          contract: contract,
          function: registerCharity,
          parameters: [
            _organizationNameController.text,
            _organizationEmailController.text.toLowerCase(),
            _phoneController.text,
            _licenseNumberController.text,
            _organizationCityController.text,
            _organizationDescriptionController.text,
            _organizationURLController.text,
            _establishmentDateController.text,
            charityWallet,
            _passwordController.text.trim()
          ],
          maxGas: 4000000,
        ),
        chainId: 11155111,
      );

      print("✅ Transaction successful! Hash: $result");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Account created successfully!')),
      );

      await _storeDonorInFirebase(charityWallet.toString(),
          _organizationEmailController.text.toLowerCase());
      await _storePrivateKey(charityWallet.toString(), charityPrivateKey);
      print("private key stored in shared prefs ✅");

// 🔐 Register with Firebase Auth for reset password support
      await _registerWithFirebase(
        _organizationEmailController.text.trim().toLowerCase(),
        _passwordController.text.trim(),
      );
      _storePrivateKey(charityWallet.toString(), charityPrivateKey);
      print("private key stoooored in shared pref.");

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const CharityLogInPage(),
        ),
      );
    } catch (e) {
      print("❌ Error registering charity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Registration failed: $e')),
      );
    }
  }

  Future<void> _checkAccountStatusAndNavigate(
      BuildContext context, String walletAddress) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (userDoc.exists) {
        String accountStatus = userDoc['accountStatus'];

        if (accountStatus == 'approved') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const CharityLogInPage(),
            ),
          );
        } else {
          String message = accountStatus == 'pending'
              ? "Your account is pending approval. Please wait."
              : "Your account has been rejected. Contact support for details.";

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User not found. Please register."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("❌ Error checking account status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred. Please try again."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _storePrivateKey(String walletAddress, String privateKey) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Use a unique key format for storing the private key
      String privateKeyKey = 'privateKey_$walletAddress';

      // Save the private key
      bool isSaved = await prefs.setString(privateKeyKey, privateKey);

      if (isSaved) {
        print('✅ Private key for wallet $walletAddress saved successfully!');
      } else {
        print('❌ Failed to save private key for wallet $walletAddress');
      }
    } catch (e) {
      print('⚠️ Error saving private key: $e');
    }
  }

  Future<void> _storeDonorInFirebase(String walletAddress, String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .set({
        'walletAddress': walletAddress,
        'email': email,
        'userType': 1, // 1 means charity
        'isSuspend': false,
        'accountStatus': 'pending', // Default status is 'pending'
      });
      print("✅ Charity data successfully stored in Firebase! 🎉");
    } catch (e) {
      print("❌ Error storing charity in Firebase: $e ");
    }
  }

  Future<void> _registerWithFirebase(String email, String password) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      print('✅ Firebase account created for ${userCredential.user?.email}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration successful')),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak.';
      } else {
        errorMessage = 'Registration failed: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('❌ Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error occurred')),
      );
    }
  }

  Future<void> getCharityDetails() async {
    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[{
        "constant": true,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "getCharity",
        "outputs": [
          {"name": "name", "type": "string"},
          {"name": "email", "type": "string"},
          {"name": "phone", "type": "string"},
          {"name": "licenseNumber", "type": "string"},
          {"name": "city", "type": "string"},
          {"name": "description", "type": "string"},
          {"name": "website", "type": "string"},
          {"name": "establishmentDate", "type": "string"},
          {"name": "wallet", "type": "address"}
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
      }]''',
        'CharityRegistry',
      ),
      _contractAddress,
    );

    final getCharity = contract.function('getCharity');
    final prefs = await SharedPreferences.getInstance();
    final storedWallet = prefs.getString('walletAddress');

    if (storedWallet == null || storedWallet.isEmpty) {
      print("❌ Error: No wallet address found in storage!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No wallet address found! Please log in again.')),
      );
      return;
    }

    final result = await _web3Client.call(
      contract: contract,
      function: getCharity,
      params: [EthereumAddress.fromHex(storedWallet)], // ✅ Use stored wallet
    );

    print("📌 Charity Details:");
    print("Name: ${result[0]}");
    print("Email: ${result[1]}");
    print("Phone: ${result[2]}");
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
          color: Color.fromRGBO(24, 71, 137, 1), // Updated arrow color
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
                _buildTextField(
                    _organizationNameController, 'Organization Name',
                    isRequired: true),
                const SizedBox(height: 30),
                _buildTextField(_organizationEmailController, 'Email',
                    isEmail: true, isRequired: true),
                const SizedBox(height: 30),
                _buildTextField(_phoneController, 'Phone',
                    isPhone: true,
                    isRequired: true,
                    hintText: 'Must start with 05'),
                const SizedBox(height: 30),
                _buildTextField(_passwordController, 'Password',
                    obscureText: true, isRequired: true, isPassword: true),
                const SizedBox(height: 30),
                _buildTextField(_confirmPasswordController, 'Confirm Password',
                    obscureText: true,
                    isRequired: true,
                    isConfirmPassword: true),
                const SizedBox(height: 30),
                _buildTextField(_licenseNumberController, 'License Number',
                    isRequired: true),
                const SizedBox(height: 30),
                _buildTextField(_organizationCityController, 'City',
                    isRequired: true, isCity: true),
                const SizedBox(height: 30),
                _buildTextField(
                  _organizationDescriptionController,
                  'Description',
                ),
                const SizedBox(height: 30),
                _buildTextField(_organizationURLController, 'Website'),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _establishmentDateController,
                  decoration: InputDecoration(
                    labelText: 'Establishment Date',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _establishmentDateController.text =
                            pickedDate.toString().split(" ")[0];
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
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
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        if (_isAgreedToTerms) {
                          _registerCharity();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please agree to the terms and conditions')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(300, 50),
                      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
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
                            builder: (context) => const CharityLogInPage()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
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
                              color: const Color.fromRGBO(24, 71, 137, 1),
                              fontWeight:
                                  FontWeight.bold, // Blue color for "Log In"
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isConfirmPasswordVisible =
      false; // New variable for confirm password visibility

  bool _isPasswordVisible = false;
  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false,
      bool isEmail = false,
      bool isPhone = false,
      bool isRequired = false,
      bool isPassword = false,
      bool isConfirmPassword = false,
      bool isCity = false,
      bool isDescription = false,
      String? hintText}) {
    return TextFormField(
      controller: controller,
      obscureText: (isPassword && !_isPasswordVisible) ||
          (isConfirmPassword && !_isConfirmPasswordVisible),
      keyboardType: isPhone
          ? TextInputType.number
          : TextInputType.text, // ✅ Numeric keyboard for phone
      inputFormatters: isPhone
          ? [
              FilteringTextInputFormatter.digitsOnly, // ✅ Allow only numbers
              LengthLimitingTextInputFormatter(10), // ✅ Limit to 10 digits
            ]
          : [],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(),
        suffixIcon: (isPassword ||
                isConfirmPassword) // Show icon for both fields
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
          return 'Invalid phone number';
        }
        if (isPassword &&
            !RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                .hasMatch(value!)) {
          return 'Password must be at least 8 characters, include an uppercase letter, lowercase, a number, and a special character';
        }
        if (isConfirmPassword && value != _passwordController.text) {
          return 'Passwords do not match';
        }
        if (isCity && !RegExp(r'^[a-zA-Z ]{1,20}$').hasMatch(value!)) {
          return 'City must contain only letters';
        }

        if (isDescription && value!.length < 30) {
          return 'Description must be at least 30 characters';
        }
        if (label == 'Website' &&
            value!.isNotEmpty && // ✅ Check if not empty
            !RegExp(r'^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$')
                .hasMatch(value!)) {
          return 'Enter a valid website URL';
        }
        return null;
      },
    );
  }
}
