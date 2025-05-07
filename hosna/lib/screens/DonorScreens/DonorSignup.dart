import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorLogin.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/SuspensionListener.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';

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
  bool _isPasswordVisible = false; // Track password visibility
  bool _isPasswordFocused = false; // Track if password field is focused

  // Focus nodes for text fields
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

// Toggle the password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

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
    _passwordFocus.addListener(() => setState(() {
          _isPasswordFocused = _passwordFocus.hasFocus;
        }));

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
        'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac'; 
    _web3Client = Web3Client(rpcUrl, Client());

 
    _contractAddress =
        EthereumAddress.fromHex("0xF565D5C3907aBA80e1e613030C250c6addea6443");
    print("Web3 initialized with contract address: $_contractAddress");
  }

  // Function to generate a unique private key and Ethereum address for each donor
  String _generatePrivateKey() {
    final String randomSeed = DateTime.now()
        .toString(); // Generate a unique string based on current time
    final bytes = utf8.encode(randomSeed);
    final hash =
        sha256.convert(bytes); // Hash the string to generate a unique key
    return hash.toString();
  }


Future<void> sendEth(String toAddress) async {
  final privateKey = '9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c';
  final rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // Replace with your Infura endpoint or use Alchemy

  final httpClient = Client();
  final ethClient = Web3Client(rpcUrl, httpClient);

  final credentials = EthPrivateKey.fromHex(privateKey);
  final myAddress = await credentials.extractAddress();

  final transaction = web3.Transaction(
    to: EthereumAddress.fromHex(toAddress),
    from: myAddress,
    value: EtherAmount.fromUnitAndValue(EtherUnit.wei, BigInt.from(0.03 * 1e18)),
    gasPrice: await ethClient.getGasPrice(),
    maxGas: 21000,
  );

  try {
    final txHash = await ethClient.sendTransaction(
      credentials,
      transaction,
      chainId: 11155111, // Sepolia testnet chain ID
    );

    print('Transaction sent. Hash: $txHash');
  } catch (e) {
    print('Transaction failed: $e');
  } finally {
    httpClient.close();
  }
}

  // Register donor function that interacts with the smart contract
  Future<void> _registerDonor() async {
    print("Registering donor...");
    final creatorPrivateKey =
        "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c";
    // Generate a unique private key for the donor
    _privateKey = _generatePrivateKey();
    print("Generated private key: $_privateKey");

    // Create credentials from the generated private key
    final credentials =
        await _web3Client.credentialsFromPrivateKey(_privateKey);
    print("Credentials obtained: $credentials");

    // Create a new wallet for the donor using the generated private key
    final donorWallet =
        await _web3Client.credentialsFromPrivateKey(_privateKey);
    final walletAddress = await donorWallet.extractAddress();
    print("Created wallet address for the donor: $walletAddress");

    // Get the owner's credentials to pay for the gas fees
    final creatorCredentials = await _web3Client.credentialsFromPrivateKey(
        creatorPrivateKey); // Private key of contract owner
    final creatorWallet = await creatorCredentials.extractAddress();
    print("Creator's wallet address: $creatorWallet");

    // Define the contract and function reference
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
    final email = _emailController.text.toLowerCase();
    final phone = _phoneController.text;
    final password = _passwordController.text;

    print("Form inputs: $firstName, $lastName, $email, $phone, $password");
bool phoneTaken = await isPhoneNumberTaken(_phoneController.text);
    if (phoneTaken) {
      print("donor with this phone number already exists!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number is already registered!')),
      );
      return;
    }
    try {
       checkBalance();
      // Send the transaction to register the donor using the creator's wallet for gas
      final result = await _web3Client.sendTransaction(
        creatorCredentials, // Use the creator's credentials to sign the transaction
        web3.Transaction.callContract(
          contract: contract,
          function: registerDonor,
          parameters: [
            firstName,
            lastName,
            email,
            phone,
            password,
            walletAddress, // Use the created wallet address
          ],
        ),
        chainId: 11155111, // Replace with your network chain ID
      );
      print("Transaction result: $result");

      // Show success message
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Signup successful!')),
      // );

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _storePrivateKey(walletAddress.toString(), _privateKey);
      print("private key stored .");
      // Store donor details in Firebase
      await _storeDonorInFirebase(walletAddress.toString(), email);
      SuspensionListener(walletAddress.toString());
      reloadPrivateKey(walletAddress.toString());
       

      // sendEth(walletAddress.toString());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DonorLogInPage()),
      );
    }catch (e) {
  print("Error registering donor: $e");

  // Clean the error message
  String errorMessage = e.toString();

  // Remove the known prefix if it exists
  if (errorMessage.contains('RPCError: got code 3 with msg "execution reverted:')) {
    errorMessage = errorMessage.replaceAll(
      RegExp(r'RPCError: got code 3 with msg "execution reverted:\s*'), '');
    errorMessage = errorMessage.replaceAll('"', ''); // remove trailing quote
  }

  // Show the cleaned error message
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to sign up: $errorMessage'),
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
         'phone': _phoneController.text,
        'userType': 0, // 0 means donor
        'isSuspend': false,
      });
      print("✅ Donor data successfully stored in Firebase! 🎉");
    } catch (e) {
      print("❌ Error storing donor in Firebase: $e ");
    }
  }

  Future<void> reloadPrivateKey(String walletAddress) async {
    String? privateKey = await _fetchPrivateKeyFromSecureStorage(walletAddress);

    if (privateKey != null && privateKey.isNotEmpty) {
      // Proceed with using the private key
      print("✅ Private key loaded for wallet $walletAddress.");
    } else {
      print("❌ Failed to load private key for wallet $walletAddress.");
    }
  }

  Future<String?> _fetchPrivateKeyFromSecureStorage(
      String walletAddress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print("✅ Private key retrieved for wallet $walletAddress.");
        return privateKey;
      } else {
        print("❌ No private key found for wallet $walletAddress.");
      }
    } catch (e) {
      print("⚠️ Error retrieving private key: $e");
    }
    return null;
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

   Future<void> checkBalance() async {
    
    final walletAddress = "0x6d910d38827AF569011b4a5AeCC0AC9a15Ff85A3";

    try {
      EthereumAddress address = EthereumAddress.fromHex(walletAddress);
      EtherAmount balance = await _web3Client.getBalance(address);
      print(
          "💰 Wallet Balance: ${balance.getValueInUnit(EtherUnit.ether)} ETH");
    } catch (e) {
      print("❌ Error fetching balance: $e");
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
                    obscureText: !_isPasswordVisible, isPassword: true),
                const SizedBox(height: 40),
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
                          text: 'Terms & Conditions ',
                          style: const TextStyle(
                            color: Color.fromRGBO(24, 71, 137, 1),
                            fontWeight: FontWeight.bold,
                            decoration:
                                TextDecoration.none, 
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              _showTermsConditionsDialog(context);
                            },
                        ),
                        const TextSpan(
                            text: '* ' , style: TextStyle(color: Colors.red),),
                        
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
                              final stopwatch = Stopwatch()..start();
                              _registerDonor(); // Register donor on the blockchain
                              stopwatch.stop();
                                print('Response time: ${stopwatch.elapsedMicroseconds} microseconds');

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
                                builder: (context) => const DonorLogInPage()),
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
                                  fontWeight: FontWeight
                                      .bold, // Blue color for "Log In"
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsConditionsDialog(BuildContext context) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('terms_conditions').get();

      final termsList = querySnapshot.docs
          .map((doc) => {
                'title': doc.data()['title']?.toString() ??
                    '', // Default to empty string if null
                'text': doc.data()['text']?.toString() ??
                    '' // Default to empty string if null
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
                fontSize: 22, // Larger size for the title
                fontWeight: FontWeight.bold, // Bold title
                color:
                    Color.fromRGBO(24, 71, 137, 1), // You can adjust the color
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
      print('❌ Error fetching terms: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load terms and conditions.')),
      );
    }
  }

// Helper function to build a text field with validation and focus
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    FocusNode focusNode,
    int maxLength, {
    bool obscureText = false,
    bool isName = false,
    bool isEmail = false,
    bool isPhone = false,
    bool isPassword = false, 
  
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      decoration: InputDecoration(
        label: RichText(
  text: TextSpan(
    text: label,
    style: TextStyle(
      color: focusNode.hasFocus
          ? const Color.fromRGBO(24, 71, 137, 1)
          : Colors.grey,
      fontSize: 16,
    ),
    children: const [
      TextSpan(
        text: ' *',
        style: TextStyle(color: Colors.red),
      ),
    ],
  ),
),

        labelStyle: TextStyle(
          color: focusNode.hasFocus
              ? const Color.fromRGBO(24, 71, 137, 1)
              : Colors.grey,
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
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: _isPasswordFocused
                      ? Color.fromRGBO(24, 71, 137, 1) // Color when focused
                      : Colors.grey, // Gray when not focused
                ),
                onPressed: () {
                  // Toggle the password visibility when the icon is pressed
                  _togglePasswordVisibility();
                },
              )
            : null,
      ),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength), // Limit input to maxLength
        FilteringTextInputFormatter.deny(
            RegExp(r'\s')), // Deny whitespace characters
        if (isPhone)
          FilteringTextInputFormatter.allow(
              RegExp(r'^[0-9]*$')), // Allow only numbers for phone
      ],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }

        // Deny fields starting with whitespace
        if (value.startsWith(' ')) {
          return 'Input cannot start with whitespace';
        }

        if (isEmail &&
            !RegExp(r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
                .hasMatch(value)) {
          return 'Please enter a valid email';
        }
        // Ensure phone number starts with "05" and is 10 digits long
        if (isPhone) {
          if (value.length != 10) {
            return 'Please enter a valid phone number (10 digits)';
          }
          if (!value.startsWith('05')) {
            return 'Phone number must start with 05';
          }
        }

        return null;
      },
    );
  }
}
