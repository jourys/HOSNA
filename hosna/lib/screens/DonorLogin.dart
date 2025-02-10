import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorResetPassword.dart';
import 'package:hosna/screens/DonorSignup.dart';
import 'package:hosna/screens/navigation_bar.dart';
import 'package:http/http.dart';
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
  final String _contractAddress = "0x79FB556a6A12568B9DceA18EE474d05437Dc5987";

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _web3Client = Web3Client(_rpcUrl, Client());
    print('Web3Client initialized');
  }

  Future<void> _authenticateUser() async {
    print('Authentication started');
    final contract = DeployedContract(
      ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_email","type":"string"},{"name":"_password","type":"string"}],"name":"loginDonor","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"}]',
          'DonorAuth'),
      EthereumAddress.fromHex(_contractAddress),
    );

    final authenticateFunction = contract.function('loginDonor');
// Convert email to lowercase before passing it to the smart contract
    final email = _emailController.text.toLowerCase();

    try {
      print('Calling the contract function...');
      final result = await _web3Client.call(
        contract: contract,
        function: authenticateFunction,
        params: [email, _passwordController.text],
      );

      print('Contract call result: $result');

      // Checking the result of the contract call (boolean)
      if (result.isNotEmpty && result[0] == true) {
        print('Login successful');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Future.delayed(Duration(seconds: 2), () {
          // Navigate to MainScreen after successful login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen()),
          );
        });
        // Navigate to the donor's dashboard or home page here if needed
      } else {
        print('Invalid credentials: result is empty or false');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials!')),
        );
      }
    } catch (e) {
      print('Error in authentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred!')),
      );
    }
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
