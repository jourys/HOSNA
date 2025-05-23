// flutter run -d chrome --target=lib/AdminScreens/AdminLogin.dart --debug
// Email : Admin@gmail.com
// Password : Pass@12345678
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web3dart/web3dart.dart' as web3;

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
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Login',
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(24, 71, 137, 1), // Set primary color
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: const MaterialColor(
            0xFF184787,
            <int, Color>{
              50: Color(0xFFE1E8F3),
              100: Color(0xFFB3C9E1),
              200: Color(0xFF80A8D0),
              300: Color(0xFF4D87BF),
              400: Color(0xFF2668A9),
              500: Color(0xFF184787),
              600: Color(0xFF165F75),
              700: Color(0xFF134D63),
              800: Color(0xFF104A52),
              900: Color(0xFF0D3841),
            },
          ),
        ).copyWith(
          primary: const Color.fromRGBO(24, 71, 137, 1),
          secondary: const Color.fromRGBO(24, 71, 137, 1),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Color.fromRGBO(24, 71, 137, 1),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.red),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          hintStyle: TextStyle(color: Colors.grey),
        ),
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

  late Web3Client _web3Client;
  late DeployedContract _contract;
  late ContractFunction _verifyLogin;
  late ContractFunction _updateAdminCredentials;
  final String rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final String contractAddress = "0xC933012E3293Cb81Be4cE8393A1fc24C9cD47E2A";
  final creatorPrivateKey =
        "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c";

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());

    String abi = '''
    [{
        "inputs": [
          {
            "internalType": "string",
            "name": "_newEmail",
            "type": "string"
          },
          {
            "internalType": "string",
            "name": "_newPassword",
            "type": "string"
          }
        ],
        "name": "updateAdminCredentials",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
      },
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

    _contract = DeployedContract(
      ContractAbi.fromJson(abi, "AdminAccount"),
      EthereumAddress.fromHex(contractAddress),
    );

    _verifyLogin = _contract.function("verifyLogin");
    _updateAdminCredentials = _contract.function("updateAdminCredentials");
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

      final authResult = await _checkAuth(email, password);
      return authResult;
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
      } 
      on FirebaseAuthException catch (e) {
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

    try {
      // Send the transaction to register the donor using the creator's wallet for gas
      final result = await _web3Client.sendTransaction(
        creatorCredentials, // Use the creator's credentials to sign the transaction
        web3.Transaction.callContract(
          contract: _contract,
          function: _updateAdminCredentials,
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
      final result = await _web3Client.call(
        contract: _contract,
        function: _verifyLogin,
        params: [email, password],
      );

      print('Auth result: $result');

      return result.isNotEmpty && result[0] == true;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 50), // Prevent content being too close to top
            Image.asset(
              'assets/HOSNA.jpg',
              height: 350,
              width: 350,
            ),
            const Text(
              'Welcome Back',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(24, 71, 137, 1),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField(_emailController, 'Email Address', _emailFocus, 250,
                isEmail: true),
            const SizedBox(height: 20),
            _buildTextField(
                _passwordController, 'Password', _passwordFocus, 250,
                obscureText: _obscureText),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {},
                child: const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color.fromRGBO(24, 71, 137, 1),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
                height: 40), // Space between forgot password and login button

            // Login button
            ElevatedButton(
              onPressed: () async {
                if (_isLoading) {
                  print(
                      "⚠️ Debug: Login process is already in progress. Ignoring duplicate request.");
                  return;
                }

                print("🔍 Debug: Starting login process...");
                bool isAuthenticated =
                    await _login(); // Call the function and wait for the result

                if (isAuthenticated) {
                  print("✅ Debug: Authentication successful!");

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Login successful!'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  print("🚀 Debug: Navigating to Admin Home Page...");
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => AdminHomePage()),
                  );
                } else {
                  print(
                      "❌ Debug: Authentication failed. Showing error message.");

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_statusMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
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
          ],
        ),
      ),
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
