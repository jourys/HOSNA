import 'package:flutter/material.dart';

class CharitySignUpPage extends StatefulWidget {
  const CharitySignUpPage({super.key});

  @override
  _CharitySignUpPageState createState() => _CharitySignUpPageState();
}

class _CharitySignUpPageState extends State<CharitySignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _organizationNameController =
      TextEditingController();
  final TextEditingController _organizationEmailController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _organizationCityController =
      TextEditingController();
  final TextEditingController _organizationDescriptionController =
      TextEditingController();
  final TextEditingController _organizationURLController =
      TextEditingController();
  final TextEditingController _establishmentDateController =
      TextEditingController();
  bool _isAgreedToTerms = false;

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
                  'Welcome to us',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField(
                    _organizationNameController, 'Organization Name',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(
                    _organizationEmailController, 'Organization Email',
                    isEmail: true, isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_phoneController, 'Phone Number',
                    isPhone: true, isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_passwordController, 'Password',
                    obscureText: true, isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_confirmPasswordController, 'Confirm Password',
                    obscureText: true, isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_licenseNumberController, 'License Number',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(
                    _organizationCityController, 'Organization City',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_organizationDescriptionController,
                    'Organization Description',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_organizationURLController, 'Organization URL',
                    isRequired: true),
                const SizedBox(height: 20),
                _buildTextField(_establishmentDateController,
                    'Organization Establishment Date',
                    isRequired: true),
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: const Text(
                    'By creating an account, you agree to our Terms and Conditions',
                    style: TextStyle(fontSize: 14),
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
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (!_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Please fill in all required fields.')),
                        );
                        return;
                      }
                      if (!_isAgreedToTerms) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please agree to the terms and conditions')),
                        );
                        return;
                      }
                      if (_passwordController.text !=
                          _confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Passwords do not match')),
                        );
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signing up...')),
                      );
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Have an account? ",
                      style: TextStyle(fontSize: 16),
                    ),
                    GestureDetector(
                      onTap: () {
                        print("Navigate to Log in page");
                      },
                      child: const Text(
                        "Log in",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color.fromRGBO(24, 71, 137, 1),
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
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

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscureText = false,
      bool isEmail = false,
      bool isPhone = false,
      bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black),
            children: isRequired
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        if (isEmail &&
            !RegExp(r'^[a-zA-Z0-9]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}\$')
                .hasMatch(value!)) {
          return 'Please enter a valid email';
        }
        if (isPhone && (value!.length != 10 || !value.startsWith('05'))) {
          return 'Phone number must be 10 digits and start with "05"';
        }
        if (label == 'Organization URL' && !Uri.parse(value!).isAbsolute) {
          return 'Please enter a valid URL';
        }
        if (label == 'Organization Establishment Date' &&
            !RegExp(r'^\d{4}-\d{2}-\d{2}\$').hasMatch(value!)) {
          return 'Please enter a valid date (YYYY-MM-DD)';
        }
        return null;
      },
      keyboardType: isEmail
          ? TextInputType.emailAddress
          : isPhone
              ? TextInputType.phone
              : TextInputType.text,
    );
  }
}
