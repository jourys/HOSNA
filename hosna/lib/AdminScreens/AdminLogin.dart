
// flutter run -d chrome --target=lib/AdminScreens/AdminLogin.dart --debug
// Email : Admin@gmail.com
// Password : Pass@12345678
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

const MaterialColor customColor = MaterialColor(
  _customColorPrimaryValue, <int, Color>{
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

void main() {
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

  late Web3Client _web3Client;
  late DeployedContract _contract;
  late ContractFunction _verifyLogin;
  final String rpcUrl = "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final String contractAddress = "0xbdcdc97957ea9342410474b14cbefa7f8673fe72";

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
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

    _contract = DeployedContract(
      ContractAbi.fromJson(abi, "AdminAccount"),
      EthereumAddress.fromHex(contractAddress),
    );

    _verifyLogin = _contract.function("verifyLogin");
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
    
    final result = await _web3Client.call(
      contract: _contract,
      function: _verifyLogin,
      params: [email, password],
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
                width: 350,  // Adjust the size as needed
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
                _emailController, 
                'Email Address', 
                _emailFocus, 
                250,
                isEmail: true
              ),
              const SizedBox(height: 20), // Space between email and password fields

              // Password text field
              _buildTextField(
                _passwordController,
                'Password',
                _passwordFocus,
                250,
                obscureText: _obscureText,
              ),
              const SizedBox(height: 20), // Space between password and forgot password text

              // Forgot password link
           Padding(
  padding: const EdgeInsets.only(left: 340), // Adjust left padding to shift right
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center, 
    children: [
      GestureDetector(
        onTap: () {
          // Implement navigation to reset password page
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
),


              const SizedBox(height: 40), // Space between forgot password and login button

              // Login button
              ElevatedButton(
             onPressed: () async {

    if (_isLoading) {
      print("⚠️ Debug: Login process is already in progress. Ignoring duplicate request.");
      return;
    }

    print("🔍 Debug: Starting login process...");
    bool isAuthenticated = await _login(); // Call the function and wait for the result

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
      print("❌ Debug: Authentication failed. Showing error message.");
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage),
          backgroundColor: Colors.red,
        ),
      );
    }
  
}
,

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
      ),
    );
  }

Widget _buildTextField(TextEditingController controller, String label,
    FocusNode focusNode, int maxLength,
    {bool obscureText = false, bool isEmail = false}) {
  return Container(
    width: 500,  // Fixed width
    height: 60,  // Fixed height (adjust as needed)
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
     counterText: '',  // Remove the counter text
        counterStyle: TextStyle(height: 0),  // Remove the counter's vertical space
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
