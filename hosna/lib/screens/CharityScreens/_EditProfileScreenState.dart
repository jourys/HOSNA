// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/ProfileScreenCharity.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

class EditProfileScreen extends StatefulWidget {
  final String organizationName;
  final String email;
  final String phone;
  final String licenseNumber;
  final String organizationCity;
  final String organizationURL;
  final String establishmentDate;
  final String description;

  EditProfileScreen({
    required this.organizationName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.organizationCity,
    required this.organizationURL,
    required this.establishmentDate,
    required this.description,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Web3Client _web3Client;
  late String _charityAddress;
  Map<String, dynamic> profileData = {};

  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x02b0d417D48eEA64Aae9AdA80570783034ED6839';

  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController licenseController;
  late TextEditingController cityController;
  late TextEditingController websiteController;
  late TextEditingController dateController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    nameController = TextEditingController(text: widget.organizationName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
    licenseController = TextEditingController(text: widget.licenseNumber);
    cityController = TextEditingController(text: widget.organizationCity);
    websiteController = TextEditingController(text: widget.organizationURL);
    dateController = TextEditingController(text: widget.establishmentDate);
    descriptionController = TextEditingController(text: widget.description);
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());
    final prefs = await SharedPreferences.getInstance();

    // Retrieve stored wallet address
    String storedAddress = prefs.getString('walletAddress') ?? '';

    _charityAddress = prefs.getString('walletAddress') ?? '';
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
    {
      "inputs": [
        { "internalType": "address", "name": "_wallet", "type": "address" },
        { "internalType": "string", "name": "_name", "type": "string" },
        { "internalType": "string", "name": "_email", "type": "string" },
        { "internalType": "string", "name": "_phone", "type": "string" },
        { "internalType": "string", "name": "_licenseNumber", "type": "string" },
        { "internalType": "string", "name": "_city", "type": "string" },
        { "internalType": "string", "name": "_description", "type": "string" },
        { "internalType": "string", "name": "_website", "type": "string" },
        { "internalType": "string", "name": "_establishmentDate", "type": "string" }
      ],
      "name": "updateCharity",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';
    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'CharityRegistration'),
      EthereumAddress.fromHex(contractAddress),
    );
    return contract;
  }

  Future<void> estimateGasCost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString('privateKey') ?? '';
      final walletAddress = prefs.getString('walletAddress') ?? '';

      if (privateKey.isEmpty || walletAddress.isEmpty) {
        print("❌ Private Key or Wallet Address missing!");
        return;
      }

      final contract = await _loadContract();
      final function = contract.function('updateCharity');

      final estimatedGas = await _web3Client.estimateGas(
        sender: EthereumAddress.fromHex(walletAddress),
        to: contract.address,
        data: function.encodeCall([
          EthereumAddress.fromHex(walletAddress),
          nameController.text.toString(),
          emailController.text.toString(),
          phoneController.text.toString(),
          licenseController.text.toString(),
          cityController.text.toString(),
          descriptionController.text.toString(),
          websiteController.text.toString(),
          dateController.text.toString(),
        ]),
      );

      print("⛽ Estimated Gas Cost: ${estimatedGas.toString()} Wei");
      final estimatedGasEth =
          EtherAmount.inWei(estimatedGas).getValueInUnit(EtherUnit.ether);

      print("⛽ Estimated Gas in ETH: $estimatedGasEth ETH");
    } catch (e) {
      print("❌ Error estimating gas: $e");
    }
  }

  Future<Map<String, dynamic>> fetchCharityData(String walletAddress) async {
    try {
      print("🔍 Fetching updated profile data for wallet: $walletAddress");

      if (walletAddress.isEmpty) {
        print("❌ Error: Wallet address is empty.");
        return {};
      }

      final contract = await _loadContract();
      final function = contract.function('getCharity');

      // Call the contract and fetch data
      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(walletAddress)],
      );

      // ✅ Debugging: Print the raw result before processing
      print("📌 Raw Result from Blockchain: $result");

      if (result.isEmpty) {
        print("❌ No data found for wallet: $walletAddress");
        return {};
      }

      Map<String, dynamic> data = {
        "name": result[0].toString(),
        "email": result[1].toString(),
        "phone": result[2].toString(),
        "license": result[3].toString(),
        "city": result[4].toString(),
        "description": result[5].toString(),
        "website": result[6].toString(),
        "date": result[7].toString(),
      };

      print("✅ Data fetched successfully: $data");
      return data;
    } catch (e) {
      print("❌ Error fetching charity data: $e");
      return {};
    }
  }

  Future<void> _updateCharityData() async {
    print("🟢 _updateCharityData() called!");

    final prefs = await SharedPreferences.getInstance();
    final storedAddress = prefs.getString('walletAddress') ?? '';

    if (storedAddress.isEmpty) {
      print("❌ Error: Wallet Address not found in SharedPreferences.");
      return;
    }

    final privateKey = prefs.getString('privateKey');
    if (privateKey == null || privateKey.isEmpty) {
      print("❌ No private key found!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Private key not found! Log in again.')),
      );
      return;
    }

    final derivedAddress = EthPrivateKey.fromHex(privateKey).address.hex;
    if (storedAddress != derivedAddress) {
      await prefs.setString('walletAddress', derivedAddress);
    }

    // 🔹 **Retrieve Form Inputs & Trim Whitespace**
    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String license = licenseController.text.trim();
    String city = cityController.text.trim();
    String date = dateController.text.trim();
    String website = websiteController.text.trim();
    String description = descriptionController.text.trim();

    // 🔹 **Validate Required Fields**
    if (name.isEmpty) {
      showError("Organization Name cannot be empty.");
      return;
    }
    if (email.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(email)) {
      showError("Enter a valid email address.");
      return;
    }
    if (phone.isEmpty || phone.length != 10 || !phone.startsWith('05')) {
      showError("Phone number must be 10 digits and start with 05.");
      return;
    }
    if (license.isEmpty) {
      showError("License Number cannot be empty.");
      return;
    }
    if (city.isEmpty) {
      showError("City cannot be empty.");
      return;
    }
    if (date.isEmpty) {
      showError("Establishment Date cannot be empty.");
      return;
    }

    // 🔹 **Optional Fields Validation**
    if (website.isNotEmpty && !Uri.parse(website).isAbsolute) {
      showError("Please enter a valid website URL.");
      return;
    }
    if (description.length > 250) {
      showError("Description must be at most 250 characters.");
      return;
    }

    print("🔹 Preparing transaction...");
    await estimateGasCost();

    final credentials = EthPrivateKey.fromHex(privateKey);

    try {
      final contract = await _loadContract();
      final function = contract.function('updateCharity');

      await _web3Client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [
            EthereumAddress.fromHex(storedAddress),
            name,
            email,
            phone,
            license,
            city,
            description.isEmpty ? " " : description,
            website.isEmpty ? " " : website,
            date,
          ],
          gasPrice: EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Waiting for updating your profile...'),
          duration: Duration(seconds: 10), // Display while waiting
        ),
      );
      print("✅ Transaction sent successfully!");
      await Future.delayed(
          Duration(seconds: 10)); // Allow time for blockchain update

      print("🔍 Fetching updated data...");
      final updatedData = await fetchCharityData(storedAddress);

      if (updatedData.isNotEmpty) {
        print("✅ Profile updated with new data: $updatedData");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );

      // await Future.delayed(Duration(seconds: 2));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreenCharity()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      showError('Failed to update profile: $e');
    }
  }

  void showError(String message) {
    print("❌ Validation Error: $message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              _buildTextField(nameController, 'Organization Name'),
              _buildTextField(emailController, 'Email'),
              _buildTextField(phoneController, 'Phone', isPhone: true),
              _buildTextField(licenseController, 'License Number'),
              _buildTextField(cityController, 'City'),
              _buildTextField(websiteController, 'Website'),
              _buildTextField(dateController, 'Establishment Date'),
              _buildTextField(descriptionController, 'Description',
                  maxLines: 3),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print("🟢 Save Changes Button Clicked!");
                  _updateCharityData(); // Wait for update to finish before navigating
                },
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: isPhone
            ? TextInputType.number
            : TextInputType.text, // ✅ Numeric keyboard for phone
        inputFormatters: isPhone
            ? [
                FilteringTextInputFormatter
                    .digitsOnly, // ✅ Only numbers allowed
                LengthLimitingTextInputFormatter(10), // ✅ Limit to 10 digits
              ]
            : [],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label cannot be empty';
          }
          if (isPhone) {
            if (value.length != 10) {
              return 'Phone number must be exactly 10 digits';
            }
            if (!value.startsWith('05')) {
              return 'Phone number must start with 05';
            }
          }
          return null;
        },
      ),
    );
  }
}
