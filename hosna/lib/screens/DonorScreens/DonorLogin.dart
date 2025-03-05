import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorNavBar.dart';
import 'package:hosna/screens/DonorScreens/DonorResetPassword.dart';
import 'package:hosna/screens/DonorScreens/DonorSignup.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

class DonorLogInPage extends StatefulWidget {
  const DonorLogInPage({super.key});

  @override
  _DonorLogInPageState createState() => _DonorLogInPageState();
}

class _DonorLogInPageState extends State<DonorLogInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true; // Initially password is hidden

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  // Focus nodes for text fields
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late Web3Client _web3Client;
  final String _rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final String _contractAddress = "0xa93d9eBB2e6fE211847e98C1d8f1BB4c166C01EE";
  final String _lookupContractAddress =
      "0xe58Af90506dc0a86d271AE02E83b7392adE4C13A";

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _web3Client = Web3Client(_rpcUrl, Client());
    print('Web3Client initialized');
  }

  Future<void> _authenticateUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password')),
      );
      return;
    }

    final email = _emailController.text.toLowerCase();
    final password = _passwordController.text;

    print(
        'Attempting to authenticate user with email: $email and password: $password');

    // Contract for donor authentication
    final authContract = DeployedContract(
      ContractAbi.fromJson(
        '[{"constant":true,"inputs":[{"name":"_email","type":"string"},{"name":"_password","type":"string"}],"name":"loginDonor","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"}]',
        'DonorAuth',
      ),
      EthereumAddress.fromHex(_contractAddress.toString()),
    );

    final authFunction = authContract.function('loginDonor');

    try {
      print('Calling the loginDonor function on the contract...');
      final authResult = await _web3Client.call(
        contract: authContract,
        function: authFunction,
        params: [email, password],
      );

      print('Auth result: $authResult');

      if (authResult.isNotEmpty && authResult[0] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        print('Login successful');

        // Lookup wallet address
        final lookupContract = DeployedContract(
          ContractAbi.fromJson(
            '[{"constant":true,"inputs":[{"name":"_email","type":"string"}],"name":"getWalletAddressByEmail","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"}]',
            'DonorLookup',
          ),
          EthereumAddress.fromHex(_lookupContractAddress.toString()),
        );

        final lookupFunction =
            lookupContract.function('getWalletAddressByEmail');

        print('Calling the getWalletAddressByEmail function...');
        final walletResult = await _web3Client.call(
          contract: lookupContract,
          function: lookupFunction,
          params: [email],
        );

        print('Wallet result: $walletResult');

        if (walletResult.isNotEmpty &&
            walletResult[0] !=
                EthereumAddress.fromHex(
                    '0x0000000000000000000000000000000000000000')) {
          String walletAddress = walletResult[0]
              .toString()
              .trim()
              .toLowerCase(); // Normalize address
          print('Wallet address found: $walletAddress');

          try {
            // Save wallet address to SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('walletAddress', walletAddress);
            print('Wallet address saved to SharedPreferences');

            // Retrieve private key
            String? privateKey = await _getPrivateKey(walletAddress);

            if (privateKey != null) {
              print("✅ Loaded Private Key: $privateKey");
            } else {
              print("❌ No private key found for this wallet.");
            }

            // Save private key if not found
            if (privateKey == null) {
              String newPrivateKey =
                  "new_private_key_example"; // Retrieve this securely
              await prefs.setString('privateKey_$walletAddress', newPrivateKey);
              print('✅ New private key saved for wallet $walletAddress');
            }
          } catch (e) {
            print('Error saving wallet address or retrieving private key: $e');
          }

          // Navigate to MainScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(walletAddress: walletAddress),
            ),
          );
        } else {
          print('❌ Wallet address not found or invalid address');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wallet address not found!')),
          );
        }
      } else {
        print('❌ Invalid credentials');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials!')),
        );
      }
    } catch (e) {
      print('❌ Error during authentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

// Function to retrieve the private key from SharedPreferences
  Future<String?> _getPrivateKey(String walletAddress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Retrieve private key using the correct key format
      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
      } else {
        print('❌ Private key not found for wallet $walletAddress');
      }

      return privateKey;
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
      return null;
    }
  }

// Sample method to get Ethereum address (replace with actual logic)
  Future<String> _getEthereumAddressForEmail(String email) async {
    // If the email-to-wallet mapping is stored in a smart contract or database,
    // you can fetch the corresponding Ethereum address for the given email.

    // Assuming you fetch it from a database or API:
    String ethereumAddress =
        ''; // Replace with actual logic to fetch the address

    if (email == 'z@z.com') {
      ethereumAddress =
          '0x84F41a8f4e9d394Ff77Df64FFCc4447BA17d7809'; // Example address
    }

    return ethereumAddress;
  }

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _web3Client.dispose(); // Dispose Web3Client when done
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Building DonorLogInPage UI');
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                const SizedBox(height: 80),
                _buildTextField(
                    _emailController, 'Email Address', _emailFocus, 250,
                    isEmail: true),
                const SizedBox(height: 30),
                _buildTextField(
                  _passwordController,
                  'Password',
                  _passwordFocus,
                  250,
                  obscureText: _obscureText,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Navigate to the Reset Password page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DonorResetPasswordPage(), // Your Reset Password page widget
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color.fromRGBO(24, 71, 137, 1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 300),
                Column(
                  children: [
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          print('Login button pressed');

                          if (_formKey.currentState?.validate() ?? false) {
                            print('Form validation successful');
                            _authenticateUser();
                          } else {
                            print('Form validation failed');
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
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 102, 100, 100),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            print('Navigating to Sign Up page');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DonorSignUpPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromRGBO(24, 71, 137, 1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      FocusNode focusNode, int maxLength,
      {bool obscureText = false,
      bool isEmail = false,
      bool isPhone = false,
      bool isName = false}) {
    print('Building TextField for $label');
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
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
        suffixIcon: label == 'Password'
            ? IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: focusNode.hasFocus
                      ? const Color.fromRGBO(24, 71, 137, 1)
                      : Colors.grey,
                ),
                onPressed: _togglePasswordVisibility,
              )
            : null, // Show eye icon only for password field
      ),
      maxLength: maxLength,
      buildCounter: (_,
          {required currentLength, required isFocused, maxLength}) {
        return null; // Remove counter
      },
      validator: (value) {
        print('Validating $label field');
        if (value == null || value.isEmpty || value.trim().isEmpty) {
          return 'Please enter your $label';
        }
        if (isEmail &&
            !RegExp(r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
                .hasMatch(value.toLowerCase())) {
          return 'Please enter a valid email';
        }

        return null;
      },
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : isPhone
              ? TextInputType.phone
              : TextInputType.text,
      inputFormatters: [
        FilteringTextInputFormatter.deny(
            RegExp(r'\s')), // Deny whitespace input
        if (isName)
          FilteringTextInputFormatter.allow(
              RegExp(r'[a-zA-Z]')) // Allow only letters for name fields
      ],
    );
  }
}

class DonorService {
  final Web3Client _client;
  final DeployedContract _contract;

  DonorService(String rpcUrl, String contractAddress)
      : _client = Web3Client(rpcUrl, Client()),
        _contract = DeployedContract(
          ContractAbi.fromJson(
            '[{"constant":true,"inputs":[{"name":"_email","type":"string"},{"name":"_password","type":"string"}],"name":"loginDonor","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_wallet","type":"address"}],"name":"getDonor","outputs":[{"name":"firstName","type":"string"},{"name":"lastName","type":"string"},{"name":"email","type":"string"},{"name":"phone","type":"string"},{"name":"walletAddress","type":"address"},{"name":"registered","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_wallet","type":"address"}],"name":"getPasswordHash","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"}]',
            'DonorAuth',
          ),
          EthereumAddress.fromHex(contractAddress),
        );

  // Method to authenticate donor
  Future<bool> authenticateDonor(String email, String password) async {
    final loginFunction = _contract.function('loginDonor');

    try {
      final result = await _client.call(
        contract: _contract,
        function: loginFunction,
        params: [email, password],
      );

      return result.isNotEmpty && result[0] == true;
    } catch (e) {
      print('Error in authentication: $e');
      return false;
    }
  }

  // Method to get the donor's wallet address
  Future<String> getDonorWalletAddress(String email) async {
    final getDonorFunction = _contract.function('getDonor');

    try {
      final result = await _client.call(
        contract: _contract,
        function: getDonorFunction,
        params: [email],
      );

      // Extract wallet address from the result
      String walletAddress = result[4] as String;
      return walletAddress.toString();
    } catch (e) {
      print('Error fetching donor wallet address: $e');
      return '';
    }
  }
}
