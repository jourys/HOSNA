import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

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
  bool _isAgreedToTerms = false;

  // Focus nodes for text fields
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late Web3Client _web3Client;
  late String _privateKey;
  late EthereumAddress _contractAddress;

  @override
  void initState() {
    super.initState();
    _firstNameFocus.addListener(() => setState(() {}));
    _lastNameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));

    // Initialize Web3Client, contract address, and private key
    _initializeWeb3();
  }

  @override
  void dispose() {
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // Initialize Web3 client and set up the contract interaction
  void _initializeWeb3() {
    final String rpcUrl =
        'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // E.g., Infura, Alchemy, or local node
    _web3Client = Web3Client(rpcUrl, http.Client());

    // Example private key and contract address
    _privateKey =
        "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c";
    _contractAddress =
        EthereumAddress.fromHex("0x091BdA2a6Abc8cbf95512ace8C8608dE8755E914");
    print("Web3 initialized with contract address: $_contractAddress");
  }

  // Register donor function that interacts with the smart contract
  Future<void> _registerDonor() async {
    print("Registering donor...");

    final credentials =
        await _web3Client.credentialsFromPrivateKey(_privateKey);
    print("Credentials obtained: $credentials");

    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[{
          "constant": false,
          "inputs": [
            {"name": "_firstName", "type": "string"},
            {"name": "_lastName", "type": "string"},
            {"name": "_email", "type": "string"},
            {"name": "_phone", "type": "string"},
            {"name": "_password", "type": "string"},
            {"name": "_wallet", "type": "address"}
          ],
          "name": "registerDonor",
          "outputs": [],
          "payable": false,
          "stateMutability": "nonpayable",
          "type": "function"
        }]''',
        'DonorRegistry', // Contract name
      ),
      _contractAddress,
    );
    print("Contract instantiated: $contract");

    final registerDonor = contract.function('registerDonor');
    print("Function reference obtained: $registerDonor");

    // Prepare parameters
    final firstName = _firstNameController.text;
    final lastName = _lastNameController.text;
    final email = _emailController.text;
    final phone = _phoneController.text;
    final password = _passwordController.text;

    print("Form inputs: $firstName, $lastName, $email, $phone, $password");

    final wallet = await _web3Client
        .credentialsFromPrivateKey(_privateKey)
        .then((credentials) => credentials.address);
    print("Wallet address: $wallet");

    // Send the transaction to register the donor
    try {
      final result = await _web3Client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: registerDonor,
          parameters: [
            firstName,
            lastName,
            email,
            phone,
            password,
            wallet,
          ],
        ),
        chainId: 11155111, // Replace with your network chain ID
      );
      print("Transaction result: $result");
    } catch (e) {
      print("Error registering donor: $e");
    }
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
                    _firstNameController, 'First Name', _firstNameFocus, 30,
                    isName: true),
                const SizedBox(height: 30),
                _buildTextField(
                    _lastNameController, 'Last Name', _lastNameFocus, 30,
                    isName: true),
                const SizedBox(height: 30),
                _buildTextField(
                    _emailController, 'Email Address', _emailFocus, 250,
                    isEmail: true),
                const SizedBox(height: 30),
                _buildTextField(
                    _phoneController, 'Phone Number', _phoneFocus, 10,
                    isPhone: true),
                const SizedBox(height: 30),
                _buildTextField(
                    _passwordController, 'Password', _passwordFocus, 250,
                    obscureText: true),
                const SizedBox(height: 40),
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
                const SizedBox(height: 50),
                Column(
                  children: [
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            if (_isAgreedToTerms) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Signing up...')),
                              );
                              _registerDonor(); // Register donor on the blockchain
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please agree to the terms and conditions'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(300, 50),
                          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1),
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(
                              context, '/donor_login');
                        },
                        child: const Text(
                          'Already have an account? Log in',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(24, 71, 137, 1),
                          ),
                        ),
                      ),
                    ),
                  ],
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
    String hintText,
    FocusNode focusNode,
    int maxLength, {
    bool isEmail = false,
    bool isPhone = false,
    bool isName = false,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLength: maxLength,
      obscureText: obscureText,
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : isPhone
              ? TextInputType.phone
              : TextInputType.text,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color.fromRGBO(24, 71, 137, 1)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: focusNode.hasFocus
                ? const Color.fromRGBO(24, 71, 137, 1)
                : Colors.grey,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Color.fromRGBO(24, 71, 137, 1),
            width: 2,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field cannot be empty';
        }
        if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        if (isPhone && value.length != 10) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
    );
  }
}
