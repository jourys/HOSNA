import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class EditDonorProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  const EditDonorProfileScreen({
    Key? key,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  }) : super(key: key);

  @override
  _EditDonorProfileScreenState createState() => _EditDonorProfileScreenState();
}

class _EditDonorProfileScreenState extends State<EditDonorProfileScreen> {
  late Web3Client _web3Client;
  late String _donorAddress;
  late String _donorPrivateKey;
  Map<String, dynamic> profileData = {};
  bool _isContractInitialized = false;
  bool _isLoading = true;
  bool _dataFetched = false;

  final String _rpcUrl = 'https://bsc-testnet-rpc.publicnode.com';
  final String _contractAddress = '0x662b9eecf8a37d033eab58120132ac82ae1b09cf';
  late ContractAbi _contractAbi;

  final _formKey = GlobalKey<FormState>();

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeWeb3AndLoadData();
  }

  void _initializeControllers() {
    firstNameController = TextEditingController(text: widget.firstName);
    lastNameController = TextEditingController(text: widget.lastName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
  }

  Future<void> _initializeWeb3AndLoadData() async {
    setState(() => _isLoading = true);

    try {
      _web3Client = Web3Client(_rpcUrl, Client());
      print('✅ Web3Client initialized with URL: $_rpcUrl');

      final prefs = await SharedPreferences.getInstance();
      _donorAddress = prefs.getString('walletAddress') ?? '';
      _donorPrivateKey = prefs.getString('privateKey') ?? '';

      if (_donorAddress.isEmpty) {
        showError('Wallet address not found. Please log in again.');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Donor wallet address loaded: $_donorAddress');

      await _loadContractAbi();
      setState(() => _isContractInitialized = true);

      final fetchedData = await _fetchDonorData(_donorAddress);

      if (fetchedData.isNotEmpty) {
        _updateControllersWithFetchedData(fetchedData);
        setState(() => _dataFetched = true);
        print('✅ Profile data fetched and displayed successfully');
      } else {
        print('⚠️ Could not fetch fresh data, using initial values');
      }
    } catch (e) {
      print('❌ Error during initialization or data fetch: $e');
      showError('Failed to initialize or fetch data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateControllersWithFetchedData(Map<String, dynamic> data) {
    setState(() {
      firstNameController.text = data['firstName'] ?? widget.firstName;
      lastNameController.text = data['lastName'] ?? widget.lastName;
      emailController.text = data['email'] ?? widget.email;
      phoneController.text = data['phone'] ?? widget.phone;
      profileData = Map.from(data);
    });
  }

  Future<void> _loadContractAbi() async {
    try {
      final abiString = await rootBundle.loadString('assets/abi.json');
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print('✅ Contract ABI loaded successfully');
    } catch (e) {
      print('❌ Error loading ABI: $e');
      showError('Failed to load contract ABI');
      throw e;
    }
  }

  DeployedContract _getContract() {
    return DeployedContract(
      _contractAbi,
      EthereumAddress.fromHex(_contractAddress),
    );
  }

  Future<Map<String, dynamic>> _fetchDonorData(String walletAddress) async {
    if (!_isContractInitialized) {
      print('❌ Contract not initialized yet');
      return {};
    }

    try {
      print("🔍 Fetching donor data for wallet: $walletAddress");

      if (walletAddress.isEmpty) {
        print("❌ Error: Wallet address is empty.");
        return {};
      }

      final contract = _getContract();
      final getDonorFunction = contract.function('getDonor');
      final result = await _web3Client.call(
        contract: contract,
        function: getDonorFunction,
        params: [EthereumAddress.fromHex(walletAddress)],
      );

      print("📌 Donor data result: $result");

      if (result.isEmpty) {
        print("❌ No donor data found");
        return {};
      }

      Map<String, dynamic> data = {
        "firstName": result[0]?.toString() ?? '',
        "lastName": result[1]?.toString() ?? '',
        "email": result[2]?.toString() ?? '',
        "phone": result[3]?.toString() ?? '',
      };

      print("✅ Donor data: $data");
      return data;
    } catch (e) {
      print("❌ Error fetching donor data: $e");
      return {};
    }
  }

  Future<void> _updateDonorData() async {
    if (!_isContractInitialized) {
      showError('Please wait, initializing contract...');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("🟢 Updating donor data...");

      final prefs = await SharedPreferences.getInstance();
      final storedAddress = prefs.getString('walletAddress') ?? '';

      if (storedAddress.isEmpty) {
        showError("Wallet Address not found. Please log in again.");
        return;
      }

      String firstName = firstNameController.text.trim();
      String lastName = lastNameController.text.trim();
      String email = emailController.text.trim();
      String phone = phoneController.text.trim();

      final contract = _getContract();
      final function = contract.function('updateDonor');

      try {
        final String ownerPrivateKey =
            "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
        final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);

        final txHash = await _web3Client.sendTransaction(
          ownerCredentials,
          Transaction.callContract(
            contract: contract,
            function: function,
            parameters: [
              EthereumAddress.fromHex(_donorAddress),
              firstName,
              lastName,
              email,
              phone,
              _donorPrivateKey,
            ],
            maxGas: 2000000,
          ),
          chainId: 97,
        );

        TransactionReceipt? receipt;
        for (int i = 0; i < 24; i++) {
          receipt = await _web3Client.getTransactionReceipt(txHash);
          if (receipt != null) break;

          if (i == 23) {
            throw Exception(
                "Transaction timed out after 2 minutes. Please check your transaction on the blockchain explorer.");
          }
          await Future.delayed(const Duration(seconds: 5));
          print("⏳ Still waiting for confirmation... Attempt ${i + 1}/24");
        }

        if (receipt == null || !receipt.status!) {
          throw Exception("Transaction failed or was not confirmed");
        }

        print("✅ Transaction sent successfully! Hash: $txHash");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('⏳ Updating your profile... This may take a few moments.'),
            duration: Duration(seconds: 15),
          ),
        );

        await Future.delayed(const Duration(seconds: 15));

        final updatedData = await _fetchDonorData(_donorAddress);

        if (updatedData.isNotEmpty) {
          print("✅ Profile updated with new data: $updatedData");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );

          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pop(context, true);
          });
        } else {
          showError('Unable to confirm profile update. Please check later.');
        }
      } catch (e) {
        print("❌ Error updating donor data: $e");
        showError('Failed to update profile: $e');
      }
    } catch (e) {
      print("❌ Error updating profile: $e");
      showError('Failed to update profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void showError(String message) {
    print("❌ Error: $message");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blue[900],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                      _dataFetched ? 'Updating...' : 'Loading profile data...'),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    if (_dataFetched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Card(
                          color: Colors.green[50],
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Data loaded from blockchain',
                              style: TextStyle(color: Colors.green),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    _buildTextField(firstNameController, 'First Name',
                        required: true),
                    _buildTextField(lastNameController, 'Last Name',
                        required: true),
                    _buildTextField(emailController, 'Email',
                        required: true, isEmail: true),
                    _buildTextField(phoneController, 'Phone',
                        required: true, isPhone: true),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateDonorData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[900],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                          : const Text('Save Changes',
                              style: TextStyle(fontSize: 16)),
                    ),
                    if (_dataFetched)
                      TextButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          final data = await _fetchDonorData(_donorAddress);
                          if (data.isNotEmpty) {
                            _updateControllersWithFetchedData(data);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Reloaded data from blockchain')),
                            );
                          } else {
                            showError('Failed to reload data');
                          }
                          setState(() => _isLoading = false);
                        },
                        child: const Text('Reset to Blockchain Data'),
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
    bool isPhone = false,
    bool isEmail = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: required
              ? const Icon(Icons.star, size: 10, color: Colors.red)
              : null,
        ),
        keyboardType: isPhone
            ? TextInputType.phone
            : isEmail
                ? TextInputType.emailAddress
                : TextInputType.text,
        inputFormatters: isPhone
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]
            : [],
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return '$label is required';
          }
          if (isPhone && value != null && value.isNotEmpty) {
            if (value.length != 10) {
              return 'Phone number must be exactly 10 digits';
            }
            if (!value.startsWith('05')) {
              return 'Phone number must start with 05';
            }
          }
          if (isEmail && value != null && value.isNotEmpty) {
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Please enter a valid email address';
            }
          }
          return null;
        },
      ),
    );
  }
}
