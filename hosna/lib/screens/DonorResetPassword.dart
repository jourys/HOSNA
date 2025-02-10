import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class DonorResetPasswordPage extends StatefulWidget {
  const DonorResetPasswordPage({super.key});

  @override
  _DonorResetPasswordPageState createState() => _DonorResetPasswordPageState();
}

class _DonorResetPasswordPageState extends State<DonorResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  late Web3Client _web3Client;
  final String _rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final String _contractAddress = "0x50cB68ccF69E388c407C0e1eb19177eC70D3F6e9";

  @override
  void initState() {
    super.initState();
    _web3Client = Web3Client(_rpcUrl, Client());
    print('Web3Client initialized');
  }

  Future<void> _resetPassword() async {
    print('Password reset started');
    final contract = DeployedContract(
      ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_email","type":"string"}],"name":"resetDonorPassword","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"}]',
          'DonorAuth'),
      EthereumAddress.fromHex(_contractAddress),
    );

    final resetPasswordFunction = contract.function('resetDonorPassword');

    try {
      print('Calling the contract function...');
      final result = await _web3Client.call(
        contract: contract,
        function: resetPasswordFunction,
        params: [_emailController.text],
      );

      print('Contract call result: $result');

      // Checking the result of the contract call (boolean)
      if (result.isNotEmpty && result[0] == true) {
        print('Password reset successful');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successful!')),
        );
        // Navigate to login page or another page after successful reset
        Navigator.pop(context); // Go back to previous page (login)
      } else {
        print('Invalid email or failed to reset password');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reset password!')),
        );
      }
    } catch (e) {
      print('Error in password reset: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An error occurred!')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reset Password',
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
                  'Enter your email to reset your password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                const SizedBox(height: 80),
                _buildTextField(_emailController, 'Email Address', 250,
                    isEmail: true),
                const SizedBox(height: 20),
                Column(
                  children: [
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState?.validate() ?? false) {
                            _resetPassword();
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
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

  Widget _buildTextField(
      TextEditingController controller, String label, int maxLength,
      {bool isEmail = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color.fromRGBO(24, 71, 137, 1),
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
      ),
      maxLength: maxLength,
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
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
    );
  }
}
