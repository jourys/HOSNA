import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    _firstNameFocus.addListener(() => setState(() {}));
    _lastNameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
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
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Space between button and text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Have an account? ",
                          style: TextStyle(
                            fontSize: 16,
                            color: Color.fromARGB(255, 102, 100, 100),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: Replace with actual navigation to login page
                            print("Navigate to Log in page");
                          },
                          child: const Text(
                            "Log in",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color.fromRGBO(24, 71, 137, 1),
                              fontWeight: FontWeight.bold,
                              decoration:
                                  TextDecoration.underline, // Hyperlink effect
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
            !RegExp(r'^[a-zA-Z0-9]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
                .hasMatch(value)) {
          return 'Please enter a valid email';
        }
        if (isPhone && !value.startsWith('05')) {
          return 'Phone number must start with "05"';
        }
        if (isPhone && value.length != 10) {
          return 'Phone number must be 10 digits';
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
