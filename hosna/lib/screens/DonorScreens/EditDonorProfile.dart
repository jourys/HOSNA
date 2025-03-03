import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class EditDonorProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  EditDonorProfileScreen({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  @override
  _EditDonorProfileScreenState createState() => _EditDonorProfileScreenState();
}

class _EditDonorProfileScreenState extends State<EditDonorProfileScreen> {
  late Web3Client _web3Client;
  late String _donorAddress;
  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0xC16cB636f27bAC0E27d3E14CEfCadd0f2D526b75';

  final _formKey = GlobalKey<FormState>();

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    _initializeWeb3();

    // ✅ Directly initialize controllers with provided values
    firstNameController = TextEditingController(text: widget.firstName);
    lastNameController = TextEditingController(text: widget.lastName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());
    final prefs = await SharedPreferences.getInstance();
    _donorAddress = prefs.getString('walletAddress') ?? '';
  }

  Future<void> _getDonorData() async {
    if (_donorAddress.isEmpty) {
      print("⚠️ No donor wallet address found.");
      return;
    }

    try {
      final contract = await _loadContract();
      final function = contract.function('getDonor');

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(_donorAddress)],
      );

      if (result.isNotEmpty) {
        setState(() {
          firstNameController.text = result[0] as String;
          lastNameController.text = result[1] as String;
          emailController.text = result[2] as String;
          phoneController.text = result[3] as String;
        });

        print("✅ Donor data retrieved successfully!");
      } else {
        print("⚠️ No donor data found for $_donorAddress");
      }
    } catch (e) {
      print("❌ Error fetching donor data: $e");
    }
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
    {
      "constant": true,
      "inputs": [{"name": "_wallet", "type": "address"}],
      "name": "getDonor",
      "outputs": [
        {"name": "firstName", "type": "string"},
        {"name": "lastName", "type": "string"},
        {"name": "email", "type": "string"},
        {"name": "phone", "type": "string"},
        {"name": "walletAddress", "type": "address"},
        {"name": "registered", "type": "bool"}
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]''';

    return DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<void> _updateDonorData() async {
    final prefs = await SharedPreferences.getInstance();
    String? privateKey = prefs.getString('privateKey');

    _donorAddress = prefs.getString('walletAddress') ?? '';

    if (privateKey == null || privateKey.isEmpty) {
      print("❌ Error: Private key not found!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Error: Private key not found! Please re-login.")),
      );
      return;
    }

    // ✅ Validate Private Key Format
    privateKey = privateKey.replaceAll("0x", "").trim();
    if (privateKey.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey)) {
      print("❌ Error: Invalid private key format!");
      return;
    }

    if (_donorAddress.isEmpty) {
      print("❌ Error: Invalid wallet address - $_donorAddress");
      return;
    }

    print("🟢 Updating donor profile...");

    final contract = await _loadContract();
    final function = contract.function('updateDonor');

    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      await _web3Client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [
            EthereumAddress.fromHex(_donorAddress),
            firstNameController.text,
            lastNameController.text,
            emailController.text,
            phoneController.text,
          ],
          gasPrice:
              EtherAmount.inWei(BigInt.from(30000000000)), // ✅ Added gas price
          maxGas: 1000000, // ✅ Increased gas limit
        ),
        chainId: 11155111,
      );

      print("✅ Profile updated successfully!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      print("❌ Error updating profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(firstNameController, 'First Name'),
              _buildTextField(lastNameController, 'Last Name'),
              _buildTextField(emailController, 'Email', isEmail: true),
              _buildTextField(phoneController, 'Phone', isPhone: true),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _updateDonorData,
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isEmail = false, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Enter $label';
          }
          if (isEmail &&
              value != widget.email && // ✅ Only validate if changed
              !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(value)) {
            return 'Enter a valid email';
          }
          if (isPhone &&
              value != widget.phone && // ✅ Only validate if changed
              !RegExp(r'^05\d{8}$').hasMatch(value)) {
            return 'Invalid phone number';
          }

          return null;
        },
      ),
    );
  }
}
