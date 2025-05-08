import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/DonorScreens/DonorNavBar.dart';
import 'package:hosna/screens/NotificationListener.dart';
import 'package:hosna/screens/NotificationManager.dart';
import 'package:hosna/screens/PasswordResetPage.dart';
import 'package:hosna/screens/DonorScreens/DonorSignup.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For Firebase Authentication
import 'package:hosna/screens/SuspensionListener.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web3dart/web3dart.dart' as web3;

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
  final String _contractAddress = "0x0F1158c5973f8c47c0E174BCae136610443AD4D5";
  final String _lookupContractAddress =
      "0x785682069953038d2FeC599F2F5DBA964d6768B1";
  final creatorPrivateKey =
      "2741b8487256f4eb8769e5195c688f69cb985d89f9aae099d28d022d07428ba6";

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

    try {
      bool authSuccess = await _checkAuth(email, password);

      if (authSuccess) {
     
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
          } catch (e) {
            print('Error saving wallet address or retrieving private key: $e');
          }
          SuspensionListener(walletAddress);

          late ProjectNotificationListener projectNotificationListener;

          projectNotificationListener = ProjectNotificationListener(
            blockchainService: BlockchainService(),
            notificationService: NotificationService(),
          );

          projectNotificationListener.checkProjectsForCreator();
          

          // Navigate to MainScreen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(walletAddress: walletAddress),
            ),
            (route) => false,
          );
           showSuccessPopup( context);
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
void showSuccessPopup(BuildContext context) {
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding:
              EdgeInsets.all(20), // Add padding around the dialog content
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15), // R ounded corners for a better look
          ),
          content: SizedBox(
            width: 250, // Set a custom width for the dialog
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Ensure the column only takes the required space
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color.fromARGB(255, 54, 142, 57),
                  size: 50, // Bigger icon
                ),
                SizedBox(height: 20), // Add spacing between the icon and text
                Text(
                  'You have logged in successfully!'
,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 54, 142, 57),
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // Bigger text
                  ),
                  textAlign: TextAlign.center, // Center-align the text
                ),
              ],
            ),
          ),
        );
      },
    );

    // Automatically dismiss the dialog after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      // Check if the widget is still mounted before performing Navigator.pop
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
      }
      Navigator.pop(context, true);
    });
  }
  Future<bool> _checkAuth(String email, String password) async {
    bool authSuccess = false;
    bool firebaseAuthSuccess = await _tryFirebaseAuth(email, password);
    print('Firebase authentication success: $firebaseAuthSuccess');
    bool blockchainAuthSuccess = await _tryBlockchainAuth(email, password);
    print('Blockchain authentication success: $blockchainAuthSuccess');
    // if (!firebaseAuthSuccess) {
    //   return;
    // }

    if (blockchainAuthSuccess && firebaseAuthSuccess) {
      authSuccess = true;
    } else if (!blockchainAuthSuccess && firebaseAuthSuccess) {
      authSuccess = true;
      await _blockchainPasswordChange(email, password);
    } else if (!firebaseAuthSuccess && blockchainAuthSuccess) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        authSuccess = true;
      } on FirebaseAuthException catch (e) {
        print("Firebase authentication error: ${e.code} - ${e.message}");
        authSuccess = false;
      }
    }
    return authSuccess;
  }

  Future<void> _blockchainPasswordChange(String email, String password) async {
    // Get the owner's credentials to pay for the gas fees
    final creatorCredentials = await _web3Client.credentialsFromPrivateKey(
        creatorPrivateKey); // Private key of contract owner
    final creatorWallet = await creatorCredentials.extractAddress();
    print("Creator's wallet address: $creatorWallet");

    // Define the contract and function reference
    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[{
		"inputs": [
          {
            "internalType": "string",
            "name": "_email",
            "type": "string"
          },
          {
            "internalType": "string",
            "name": "_newPassword",
            "type": "string"
          }
        ],
        "name": "changePassword",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      }]''',
        'DonorAuth', // Contract name
      ),
      EthereumAddress.fromHex(_contractAddress.toString()),
    );
    print("Contract instantiated: $contract");

    final changePassword = contract.function('changePassword');
    print("Function reference obtained: $changePassword");

    try {
      // Send the transaction to register the donor using the creator's wallet for gas
      final result = await _web3Client.sendTransaction(
        creatorCredentials, // Use the creator's credentials to sign the transaction
        web3.Transaction.callContract(
          contract: contract,
          function: changePassword,
          parameters: [
            email,
            password,
          ],
          gasPrice: web3.EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111, // Replace with your network chain ID
      );
      print("Transaction result: $result");
    } catch (e) {
      print("Error changing password: $e");
    }
  }

  // Function to retrieve the private key from SharedPreferences
  Future<String?> _getPrivateKey(String walletAddress) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (snapshot.exists && snapshot['isSuspend'] == true) {
        print("🚫 Access denied! Account is suspended.");
        return null;
      }
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

  Future<bool> _tryFirebaseAuth(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Firebase authentication successful");
      return true;
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase authentication error: ${e.code} - ${e.message}");
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }
      return false;
    }
  }

  Future<bool> _tryBlockchainAuth(String email, String password) async {
    try {
      // Contract for donor authentication
      final authContract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_email","type":"string"},{"name":"_password","type":"string"}],"name":"loginDonor","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"}]',
          'DonorAuth',
        ),
        EthereumAddress.fromHex(_contractAddress.toString()),
      );

      final authFunction = authContract.function('loginDonor');

      final authResult = await _web3Client.call(
        contract: authContract,
        function: authFunction,
        params: [email, password],
      );

      print('Auth result: $authResult');

      return authResult.isNotEmpty && authResult[0] == true;
    } catch (e) {
      print('❌ Error during blockchain authentication: $e');
      return false;
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
                                const PasswordResetPage(), // الانتقال إلى صفحة إعادة تعيين كلمة المرور
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
                const SizedBox(
                    height: 30), // smaller spacing after password field
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final stopwatch = Stopwatch()..start();
                        _authenticateUser();
                         stopwatch.stop();
                          print('Response time: ${stopwatch.elapsedMicroseconds} microseconds');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(300, 50),
                      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(fontSize: 20, color: Colors.white),
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
