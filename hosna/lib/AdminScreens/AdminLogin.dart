// flutter run -d chrome --target=lib/AdminScreens/AdminLogin.dart --debug
// Email : Admin@gmail.com
// Password : Pass@12345678
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hosna/firebase_options.dart';

const MaterialColor customColor = MaterialColor(
  _customColorPrimaryValue,
  <int, Color>{
    50: Color(0xFFE1F2FB),
    100: Color(0xFFB3D5F5),
    200: Color(0xFF80B8F0),
    300: Color(0xFF4D9BEA),
    400: Color(0xFF2682E4),
    500: Color(_customColorPrimaryValue),
    600: Color(0xFF0069C0),
    700: Color(0xFF0058A2),
    800: Color(0xFF00478B),
    900: Color(0xFF003166),
  },
);

const int _customColorPrimaryValue = 0xFF184787;

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // ✅ التأكد من تهيئة الـ Widgets قبل Firebase
  try {
    await Firebase.initializeApp(
      // 🚀 تهيئة Firebase عند بدء التطبيق
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully 🎉");
  } catch (e) {
    print("❌ Error initializing Firebase: $e ");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Login',
      theme: ThemeData(
        primarySwatch: customColor,
      ),
      home: AdminLoginPage(),
    );
  }
}

class AdminLoginPage extends StatefulWidget {
  @override
  _AdminLoginPageState createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isResettingPassword = false;
  String? _resetPasswordError;
  bool _resetEmailSent = false;

  late Web3Client _web3Client;
  late DeployedContract _contract;
  late ContractFunction _verifyLogin;
  late ContractAbi _contractAbi;
  final String rpcUrl =
      // "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
      "https://bsc-testnet-rpc.publicnode.com";

  // final String contractAddress = "0xbdcdc97957ea9342410474b14cbefa7f8673fe72";
  final String contractAddress = "0x662b9eecf8a37d033eab58120132ac82ae1b09cf";

  @override
  void initState() {
    super.initState();
    _loadContractAbi();
    _initializeWeb3();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _web3Client.dispose(); // Add this line to clean up web3 client
    super.dispose();
  }

  // Future<void> _initRegisterFirebase() async {
  //   await createFirebaseUser("Admin@gmail.com", "Pass@12345678");
  // }

  Future<void> _loadContractAbi() async {
    try {
      final String abiString = await rootBundle.loadString('assets/abi.json');
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print("✅ Contract ABI loaded successfully");
    } catch (e) {
      print("❌ Error loading ABI: $e");
    }
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    String abi = '''
    [
      {
        "constant": true,
        "inputs": [
          { "name": "_email", "type": "string" },
          { "name": "_password", "type": "string" }
        ],
        "name": "verifyLogin",
        "outputs": [{ "name": "", "type": "bool" }],
        "stateMutability": "view",
        "type": "function"
      }
    ]
    ''';

    // _verifyLogin = _contract.function("login");
  }

  Future<void> createFirebaseUser(String email, String password) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Firebase user created successfully");
    } catch (e) {
      print("❌ Failed to create Firebase user: $e");
      // Handle error appropriately
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isResettingPassword = true;
      _resetPasswordError = null;
    });

    String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _resetPasswordError = 'Please enter your email address';
        _isResettingPassword = false;
      });
      return;
    }

    try {
      print("🔄 Sending password reset email to: $email");

      // First check if the user exists in blockchain
      String walletAddress = await _getWalletAddressByEmail(email);

      if (walletAddress.isEmpty) {
        setState(() {
          _resetPasswordError = 'No account found with this email address';
          _isResettingPassword = false;
        });
        return;
      }

      // Then send the reset email through Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      print("✅ Password reset email sent successfully");

      setState(() {
        _resetEmailSent = true;
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase error: ${e.code} - ${e.message}");

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      setState(() {
        _resetPasswordError = errorMessage;
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resetPasswordError!)),
      );
    } catch (e) {
      print("❌ General error: $e");

      setState(() {
        _resetPasswordError = 'An unexpected error occurred';
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  Future<String> _getWalletAddressByEmail(String email) async {
    try {
      final contract = DeployedContract(
        _contractAbi,
        EthereumAddress.fromHex(contractAddress),
      );

      final lookupFunction = contract.function('getAdminAddressByEmail');

      final result = await _web3Client.call(
        contract: contract,
        function: lookupFunction,
        params: [email],
      );

      if (result.isNotEmpty &&
          result[0] !=
              EthereumAddress.fromHex(
                  "0x0000000000000000000000000000000000000000")) {
        print("✅ Wallet address found: ${result[0].hex}");
        return result[0].hex;
      } else {
        print("❌ No wallet address found");
        return "";
      }
    } catch (e) {
      print("❌ Error getting wallet address: $e");
      return "";
    }
  }

  Future<void> _authenticateAdmin() async {
    if (!mounted) return;
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });
    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    print("🔄 Starting admin authentication process for email: $email");

    try {
      // 1. Try Firebase authentication first
      await _tryFirebaseAuth(email, password);
      print("✅ Firebase authentication successful");

      // 2. Try blockchain authentication
      bool blockchainAuthSuccess = await _tryBlockchainAuth(email, password);

      if (blockchainAuthSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
      } else {
        try {
          await _updateAdminPassword(email, password);

          // Try blockchain authentication again
          blockchainAuthSuccess = await _tryBlockchainAuth(email, password);

          if (!blockchainAuthSuccess) {
            throw Exception("Failed to authenticate after password sync");
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
        } catch (e) {
          print("❌ Error syncing passwords: $e");
          // Sign out from Firebase since sync failed
          await FirebaseAuth.instance.signOut();
          throw Exception("Failed to sync passwords: $e");
        }
      }
    } catch (e) {
      print("❌ Authentication error: $e");
      setState(() {
        _isLoading = false;
        _statusMessage = e.toString();
      });
      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        // Add mounted check in finally block
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryFirebaseAuth(String email, String password) async {
    try {
      print("🔍 Attempting Firebase authentication");
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Firebase authentication successful");
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase authentication error: ${e.code} - ${e.message}");
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No admin account found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Invalid password.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }
      throw errorMessage;
    }
  }

  Future<bool> _tryBlockchainAuth(String email, String password) async {
    try {
      print("🔍 Attempting blockchain authentication");

      final contract = DeployedContract(
          _contractAbi, EthereumAddress.fromHex(contractAddress));
      final authenticateFunction = contract.function('login');

      final result = await _web3Client.call(
        contract: contract,
        function: authenticateFunction,
        params: [email, password, BigInt.from(3)], // 3 for admin type
      );

      if (result.isNotEmpty && result[0] == true) {
        String walletAddress = result[1].hex;
        String privateKey = result[2];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AdminHomePage(),
          ),
        );

        return true;
      }
      return false;
    } catch (e) {
      print("❌ Error in blockchain authentication: $e");
      return false;
    }
  }

  Future<void> _updateAdminPassword(String email, String newPassword) async {
    try {
      // Get charity address from email
      String walletAddress = await _getWalletAddressByEmail(email);
      if (walletAddress.isEmpty) {
        throw Exception('No charity found with this email');
      }

      final contract = DeployedContract(
          _contractAbi, EthereumAddress.fromHex(contractAddress));
      final resetPasswordFunction = contract.function('resetPassword');

      // Get owner credentials for the transaction
      final String ownerPrivateKey =
          "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
      final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);

      final txHash = await _web3Client.sendTransaction(
        ownerCredentials,
        Transaction.callContract(
          contract: contract,
          function: resetPasswordFunction,
          parameters: [
            EthereumAddress.fromHex(walletAddress),
            newPassword,
          ],
          maxGas: 2000000,
        ),
        chainId: 97,
      );

      // Wait for transaction confirmation
      for (int i = 0; i < 12; i++) {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status!) {
            return;
          } else {
            throw Exception("Transaction failed");
          }
        }
        if (i == 11) {
          throw Exception("Transaction timeout");
        }
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      print("❌ Error updating blockchain password: $e");
      throw e;
    }
  }

  Future<bool> _login() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    print("🔍 Debug: Attempting login...");
    print("📧 Email: $email");
    print("🔑 Password: $password");

    try {
      print("🛠 Calling smart contract...");

      final contract = DeployedContract(
        _contractAbi,
        EthereumAddress.fromHex(contractAddress),
      );

      final result = await _web3Client.call(
        contract: contract,
        function: contract.function("login"),
        params: [email, password, BigInt.from(3)],
      );

      print("✅ Smart contract response: $result");

      bool isValid = result.isNotEmpty && result[0] as bool;
      print("🔍 Debug: Login valid? $isValid");

      setState(() {
        _statusMessage = isValid ? "Login Successful!" : "Invalid credentials!";
      });

      return isValid; // Return the result for navigation handling
    } catch (e, stackTrace) {
      print("❌ Error during login: $e");
      print("📜 StackTrace: $stackTrace");

      setState(() {
        _statusMessage = "Error: ${e.toString()}";
      });
      return false; // Return false if an error occurs
    } finally {
      setState(() {
        _isLoading = false;
      });
      print("🛑 Login process finished.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Log In',
          style: TextStyle(
            fontSize: 30,
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
      body: Center(
          child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Display the image first
              Image.asset(
                'assets/HOSNA.jpg',
                height: 350, // Adjust the size as needed
                width: 350, // Adjust the size as needed
              ),

              // Welcome back text
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              const SizedBox(height: 20), // Space between text and email input

              // Email text field
              _buildTextField(
                  _emailController, 'Email Address', _emailFocus, 250,
                  isEmail: true),
              const SizedBox(
                  height: 20), // Space between email and password fields

              // Password text field
              _buildTextField(
                _passwordController,
                'Password',
                _passwordFocus,
                250,
                obscureText: _obscureText,
              ),
              const SizedBox(
                  height:
                      20), // Space between password and forgot password text

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResettingPassword ? null : _resetPassword,
                  child: _isResettingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color.fromRGBO(24, 71, 137, 1),
                          ),
                        ),
                ),
              ),
              if (_resetPasswordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _resetPasswordError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_resetEmailSent)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Password reset email sent to ${_emailController.text}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticateAdmin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(300, 50),
                    backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      FocusNode focusNode, int maxLength,
      {bool obscureText = false, bool isEmail = false}) {
    return Container(
      width: 500, // Fixed width
      height: 60, // Fixed height (adjust as needed)
      child: TextFormField(
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
          counterText: '', // Remove the counter text
          counterStyle:
              TextStyle(height: 0), // Remove the counter's vertical space
        ),
        maxLength: maxLength,
        validator: (value) {
          if (value == null || value.isEmpty || value.trim().isEmpty) {
            return 'Please enter your $label';
          }
          if (value.contains(' ')) {
            return 'No spaces allowed';
          }
          if (isEmail &&
              !RegExp(r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
                  .hasMatch(value.toLowerCase())) {
            return 'Please enter a valid email';
          }
          return null;
        },
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')), // Blocks spaces
        ],
      ),
    );
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }
}
