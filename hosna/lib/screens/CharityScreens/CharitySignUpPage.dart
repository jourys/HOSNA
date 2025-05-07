import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
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

class NoLeadingSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    return newValue;
  }
}

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
        EthereumAddress.fromHex("0x583472AFc3f8655FF4B22bf5253c884081e3a794");
    print("Web3 initialized with contract address: $_contractAddress");
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
    print('Saved walletAddress: $walletAddress');
    print('Saved privateKey: $privateKey');
  }

  Uint8List hashPassword(String password) {
    Uint8List fullHash = keccak256(utf8.encode(password.trim()));
    return fullHash.sublist(0, 32); // Ensure it's exactly bytes32
  }

  Future<bool> isPhoneNumberTaken(String phone) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking phone duplication: $e');
      return false;
    }
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
        print("Charity with this email already exists!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Charity with this email is already registered!')),
        );
        return;
      }
    } catch (e) {
      print("No existing charity found, proceeding with registration.");
    }
// 🔵 Check if phone is already used
    bool phoneTaken = await isPhoneNumberTaken(_phoneController.text);
    if (phoneTaken) {
      print("Charity with this phone number already exists!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is already registered!')),
      );
      return;
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
          gasPrice: EtherAmount.inWei(BigInt.from(10000000000)), // 10 Gwei

          maxGas: 4000000,
        ),
        chainId: 11155111,
      );

      print("Transaction successful! Hash: $result");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      await _storeDonorInFirebase(charityWallet.toString(),
          _organizationEmailController.text.toLowerCase());
      await _storePrivateKey(charityWallet.toString(), charityPrivateKey);
      print("private key stored in shared prefs");

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
      print("Error registering charity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(' Registration failed: $e')),
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
      print("Error checking account status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred. Please try again."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showTermsConditionsDialog(BuildContext context) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('terms_conditions').get();

      final termsList = querySnapshot.docs
          .map((doc) => {
                'title': doc.data()['title']?.toString() ?? '',
                'text': doc.data()['text']?.toString() ?? ''
              })
          .where((term) =>
              term['title']?.isNotEmpty == true &&
              term['text']?.isNotEmpty == true)
          .toList();

      final allTerms = termsList
          .asMap()
          .entries
          .map((entry) =>
              '${entry.key + 1}. \n${entry.value['title']}: \n${entry.value['text']}')
          .join('\n\n');

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Terms and Conditions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(24, 71, 137, 1),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: termsList.map((term) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        Text(
                          term['title']!,
                          style: TextStyle(
                            fontSize:
                                16, // Larger font size for title from Firebase
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        // Display the term text
                        Text(
                          term['text']!,
                          style: TextStyle(
                              fontSize: 14), // Standard font size for content
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('Error fetching terms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load terms and conditions.')),
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
        print('Private key for wallet $walletAddress saved successfully!');
      } else {
        print('Failed to save private key for wallet $walletAddress');
      }
    } catch (e) {
      print('Error saving private key: $e');
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
        'phone': _phoneController.text,

        'userType': 1, // 1 means charity
        'isSuspend': false,
        'accountStatus': 'pending', // Default status is 'pending'
      });
      print("Charity data successfully stored in Firebase! 🎉");
    } catch (e) {
      print("Error storing charity in Firebase: $e ");
    }
  }

  Future<void> _registerWithFirebase(String email, String password) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      print('Firebase account created for ${userCredential.user?.email}');
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
      print('Error: $e');
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
      print("Error: No wallet address found in storage!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No wallet address found! Please log in again.')),
      );
      return;
    }

    final result = await _web3Client.call(
      contract: contract,
      function: getCharity,
      params: [EthereumAddress.fromHex(storedWallet)],
    );

    print("Charity Details:");
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
                  isDescription: true,
                ),
                const SizedBox(height: 30),
                _buildTextField(_organizationURLController, 'Website'),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _establishmentDateController,
                  decoration: InputDecoration(
                    label: RichText(
                      text: const TextSpan(
                        text: 'Establishment Date',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        children: [
                          TextSpan(
                            text: ' *',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
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
                    try {
                      DateTime selectedDate = DateTime.parse(value);
                      if (selectedDate.isAfter(DateTime.now())) {
                        return 'Establishment date cannot be in the future';
                      }
                    } catch (e) {
                      return 'Invalid date format';
                    }
                    return null;
                  },
                ),
                CheckboxListTile(
                  title: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: _isAgreedToTerms
                            ? const Color.fromRGBO(24, 71, 137, 1)
                            : const Color.fromARGB(255, 102, 100, 100),
                      ),
                      children: [
                        const TextSpan(
                            text: 'By creating an account, you agree to our '),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: const TextStyle(
                            color: Color.fromRGBO(24, 71, 137, 1),
                            fontWeight: FontWeight.bold,
                            decoration:
                                TextDecoration.none, // أزلنا التسطير كما طلبت
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _showTermsConditionsDialog(context);
                            },
                        ),
                      ],
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

  bool _isConfirmPasswordVisible = false;

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
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        NoLeadingSpaceFormatter(),
        if (isPhone) ...[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        if (isEmail || isPassword || label == 'Website')
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      maxLines: isDescription ? 2 : 1,
      decoration: InputDecoration(
        label: isRequired
            ? RichText(
                text: TextSpan(
                  text: label,
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              )
            : Text(label),
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
          return 'Please enter $label';
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
        if (isCity && !RegExp(r"^[a-zA-Z\s,.'-]{2,50}$").hasMatch(value!)) {
          return 'Enter a valid city name';
        }

        // if (isDescription && value!.length < 30) {
        //   return 'Description must be at least 30 characters';
        // }
        if (label == 'Website' &&
            value!.isNotEmpty &&
            !RegExp(r'^www\.[a-zA-Z0-9-]+\.com$').hasMatch(value)) {
          return 'Enter a valid website URL (e.g., www.HOSNA.com)';
        }

        return null;
      },
    );
  }
}
