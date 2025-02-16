import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

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
        EthereumAddress.fromHex("0xc5A97194e3A6c4524D74D8872C91BbacfBd198E1");
    print("✅ Web3 initialized with contract address: $_contractAddress");
  }

  String _generatePrivateKey() {
    final rng = Random.secure();
    EthPrivateKey key = EthPrivateKey.createRandom(rng);
    return bytesToHex(key.privateKey);
  }

  Uint8List hashPassword(String password) {
    Uint8List fullHash = keccak256(utf8.encode(password.trim()));
    return fullHash.sublist(0, 32); // Ensure it's exactly bytes32
  }

  Future<void> _registerCharity() async {
    print("🛠 Registering charity...");

    final String ownerPrivateKey =
        "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
    final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);
    final ownerWallet = await ownerCredentials.extractAddress();
    print("🔹 Owner's wallet address (paying gas): $ownerWallet");

    final String charityPrivateKey = _generatePrivateKey();
    final charityCredentials = EthPrivateKey.fromHex(charityPrivateKey);
    final charityWallet = await charityCredentials.extractAddress();
    print("🔹 Charity Wallet Address: $charityWallet");
    print("🔹 Charity Wallet private Address: $charityPrivateKey");

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
        Transaction.callContract(
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
        const SnackBar(content: Text('🎉 Charity registered successfully!')),
      );

      Navigator.pushReplacementNamed(context, '/charityHome');
    } catch (e) {
      print("❌ Error registering charity: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Registration failed: $e')),
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

    final result = await _web3Client.call(
      contract: contract,
      function: getCharity,
      params: [
        EthereumAddress.fromHex("0x6AaebB1a5653fF9bF938E1365922362b6d8C2E0b")
      ],
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
        title: const Text('Sign Up'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                    _organizationDescriptionController, 'Description',
                    isRequired: true, isDescription: true),
                const SizedBox(height: 30),
                _buildTextField(_organizationURLController, 'Website',
                    isRequired: true),
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
                  title: const Text('Agree to Terms and Conditions'),
                  value: _isAgreedToTerms,
                  onChanged: (bool? value) {
                    setState(() {
                      _isAgreedToTerms = value ?? false;
                    });
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      if (_isAgreedToTerms) {
                        _registerCharity();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Agree to Terms')),
                        );
                      }
                    }
                  },
                  child: const Text('Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool obscureText = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isRequired = false,
    bool isPassword = false,
    bool isConfirmPassword = false,
    bool isCity = false,
    bool isDescription = false,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: 15.0), // Add spacing between fields
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color:
                const Color.fromRGBO(24, 71, 137, 1), // Consistent label color
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color.fromRGBO(24, 71, 137, 1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          hintText: hintText,
          suffixIcon: isPassword || isConfirmPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      obscureText = !obscureText;
                    });
                  },
                )
              : null,
        ),
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        inputFormatters: [
          LengthLimitingTextInputFormatter(250),
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
          if (isPhone) FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*$')),
        ],
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
              !RegExp(r'^(http:\/\/www\.|https:\/\/www\.|http:\/\/|https:\/\/)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$')
                  .hasMatch(value!)) {
            return 'Enter a valid website URL';
          }
          return null;
        },
      ),
    );
  }
}
