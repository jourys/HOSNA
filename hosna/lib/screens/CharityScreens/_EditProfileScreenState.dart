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

  // Contract information
  final String rpcUrl =
      //  'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
      'https://bsc-testnet-rpc.publicnode.com';
  final String contractAddress =
      // '0x168ef53DA3d4B294D4c2651Ae39c64310D35AabE';
      '0x662b9eecf8a37d033eab58120132ac82ae1b09cf';

  // Contract ABI
  late ContractAbi _contractAbi;
  bool _isContractInitialized = false;
  bool _isLoading = true; // Start with loading state
  bool _dataFetched = false;

  final _formKey = GlobalKey<FormState>();

  // Form controllers
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
    _initializeControllers();
    _initializeWeb3AndLoadData();
  }

  void _initializeControllers() {
    // Initialize with values from widget, these will be updated after data fetch
    nameController = TextEditingController(text: widget.organizationName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
    licenseController = TextEditingController(text: widget.licenseNumber);
    cityController = TextEditingController(text: widget.organizationCity);
    websiteController = TextEditingController(text: widget.organizationURL);
    dateController = TextEditingController(text: widget.establishmentDate);
    descriptionController = TextEditingController(text: widget.description);
  }

  Future<void> _initializeWeb3AndLoadData() async {
    setState(() => _isLoading = true);

    try {
      // Initialize Web3 client
      _web3Client = Web3Client(rpcUrl, Client());
      print('✅ Web3Client initialized with URL: $rpcUrl');

      // Get wallet address from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _charityAddress = prefs.getString('walletAddress') ?? '';

      if (_charityAddress.isEmpty) {
        showError('Wallet address not found. Please log in again.');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ Charity wallet address loaded: $_charityAddress');

      // Load contract ABI from file
      await _loadContractAbi();
      setState(() => _isContractInitialized = true);

      // Fetch fresh charity data from blockchain
      final fetchedData = await fetchCharityData(_charityAddress);

      if (fetchedData.isNotEmpty) {
        // Update controllers with fresh data
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
      // Update controllers with data from blockchain
      nameController.text = data['name'] ?? widget.organizationName;
      emailController.text = data['email'] ?? widget.email;
      phoneController.text = data['phone'] ?? widget.phone;
      licenseController.text = data['license'] ?? widget.licenseNumber;
      cityController.text = data['city'] ?? widget.organizationCity;
      websiteController.text = data['website'] ?? widget.organizationURL;
      dateController.text = data['date'] ?? widget.establishmentDate;
      descriptionController.text = data['description'] ?? widget.description;

      // Also update profile data map
      profileData = Map.from(data);
    });
  }

  Future<void> _loadContractAbi() async {
    try {
      // Load ABI from the assets
      final abiString = await rootBundle.loadString('assets/abi.json');
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print('✅ Contract ABI loaded successfully');
    } catch (e) {
      print('❌ Error loading ABI from file: $e');

      print('⚠️ Using fallback hardcoded ABI');
    }
  }

  DeployedContract _getContract() {
    return DeployedContract(
      _contractAbi,
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<Map<String, dynamic>> fetchCharityData(String walletAddress) async {
    if (!_isContractInitialized) {
      print('❌ Contract not initialized yet');
      return {};
    }

    try {
      print("🔍 Fetching charity data for wallet: $walletAddress");

      if (walletAddress.isEmpty) {
        print("❌ Error: Wallet address is empty.");
        return {};
      }

      final contract = _getContract();

      // First get basic charity info
      final getCharityFunction = contract.function('getCharity');
      final charityResult = await _web3Client.call(
        contract: contract,
        function: getCharityFunction,
        params: [EthereumAddress.fromHex(walletAddress)],
      );

      print("📌 Basic charity data result: $charityResult");

      if (charityResult.isEmpty) {
        print("❌ No basic charity data found");
        return {};
      }

      // Then get detailed info
      final getDetailFunction = contract.function('getCharityDetails');
      final detailResult = await _web3Client.call(
        contract: contract,
        function: getDetailFunction,
        params: [EthereumAddress.fromHex(walletAddress)],
      );

      print("📌 Charity detail result: $detailResult");

      // Combine data from both calls
      Map<String, dynamic> data = {
        "name": charityResult[0]?.toString() ?? '',
        "email": charityResult[1]?.toString() ?? '',
        "phone": charityResult[2]?.toString() ?? '',
        "city": charityResult[3]?.toString() ?? '',
        "website": charityResult[4]?.toString() ?? '',
        "description": detailResult[0]?.toString() ?? '',
        "license": detailResult[1]?.toString() ?? '',
        "date": detailResult[2]?.toString() ?? '',
      };

      print("✅ Combined charity data: $data");
      return data;
    } catch (e) {
      print("❌ Error fetching charity data: $e");
      return {};
    }
  }

  Future<void> estimateGasCost() async {
    if (!_isContractInitialized) {
      print('❌ Contract not initialized yet');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final privateKey = prefs.getString('privateKey') ?? '';
      final walletAddress = prefs.getString('walletAddress') ?? '';

      if (privateKey.isEmpty || walletAddress.isEmpty) {
        print("❌ Private Key or Wallet Address missing!");
        return;
      }

      final contract = _getContract();
      final function = contract.function('updateCharity');

      final estimatedGas = await _web3Client.estimateGas(
        sender: EthereumAddress.fromHex(walletAddress),
        to: contract.address,
        data: function.encodeCall([
          EthereumAddress.fromHex(walletAddress),
          nameController.text,
          emailController.text,
          phoneController.text,
          licenseController.text,
          cityController.text,
          descriptionController.text,
          websiteController.text,
          dateController.text,
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

  Future<void> _updateCharityData() async {
    if (!_isContractInitialized) {
      showError('Please wait, initializing contract...');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("🟢 Updating charity data...");

      final prefs = await SharedPreferences.getInstance();
      final storedAddress = prefs.getString('walletAddress') ?? '';

      if (storedAddress.isEmpty) {
        showError("Wallet Address not found. Please log in again.");
        return;
      }

      final privateKey = prefs.getString('privateKey');
      if (privateKey == null || privateKey.isEmpty) {
        showError("Private key not found! Please log in again.");
        return;
      }

      // Validate the private key by deriving address
      final derivedAddress = EthPrivateKey.fromHex(privateKey).address.hex;
      if (storedAddress != derivedAddress) {
        await prefs.setString('walletAddress', derivedAddress);
        _charityAddress = derivedAddress;
      }

      // Prepare form data
      String name = nameController.text.trim();
      String email = emailController.text.trim();
      String phone = phoneController.text.trim();
      String license = licenseController.text.trim();
      String city = cityController.text.trim();
      String date = dateController.text.trim();
      String website = websiteController.text.trim();
      String description = descriptionController.text.trim();

      // Gas estimation for user feedback
      // await estimateGasCost();

      // Create credentials
      final credentials = EthPrivateKey.fromHex(privateKey);

      // Get contract and function
      final contract = _getContract();
      final function = contract.function('updateCharity');

      try {
        final String ownerPrivateKey =
            "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
        final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);
        // Send transaction
        final txHash = await _web3Client.sendTransaction(
          ownerCredentials,
          Transaction.callContract(
            contract: contract,
            function: function,
            parameters: [
              EthereumAddress.fromHex(_charityAddress),
              name,
              email,
              phone,
              license,
              city,
              description,
              website,
              date,
              privateKey,
            ],
            // gasPrice: EtherAmount.inWei(BigInt.from(300000000000)),
            maxGas: 4000000,
          ),
          // chainId: 11155111,
          chainId: 97,
        );

        TransactionReceipt? receipt;
        for (int i = 0; i < 24; i++) {
          receipt = await _web3Client.getTransactionReceipt(txHash);
          if (receipt != null) {
            break;
          }
          if (i == 23) {
            // Last attempt
            throw Exception(
                "Transaction timed out after 2 minutes. Please check your transaction on the blockchain explorer.");
          }
          await Future.delayed(const Duration(seconds: 5));
          print("⏳ Still waiting for confirmation... Attempt ${i + 1}/24");
        }

        // Check transaction status
        if (receipt == null || !receipt.status!) {
          throw Exception("Transaction failed or was not confirmed");
        }

        print("✅ Transaction sent successfully! Hash: $txHash");
      } catch (e) {
        print("❌ Error updating charity data: $e");
        showError('Failed to update profile: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('⏳ Updating your profile... This may take a few moments.'),
          duration: Duration(seconds: 15),
        ),
      );

      // Wait for transaction to be mined
      await Future.delayed(const Duration(seconds: 15));

      // Fetch updated data to confirm changes
      final updatedData = await fetchCharityData(_charityAddress);

      if (updatedData.isNotEmpty) {
        print("✅ Profile updated with new data: $updatedData");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );

        // Return to previous screen
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      } else {
        showError('Unable to confirm profile update. Please check later.');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    licenseController.dispose();
    cityController.dispose();
    websiteController.dispose();
    dateController.dispose();
    descriptionController.dispose();
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
                    // Data fetched indicator
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

                    _buildTextField(nameController, 'Organization Name',
                        required: true),
                    _buildTextField(emailController, 'Email',
                        required: true, isEmail: true),
                    _buildTextField(phoneController, 'Phone',
                        isPhone: true, required: true),
                    _buildTextField(licenseController, 'License Number',
                        required: true),
                    _buildTextField(cityController, 'City', required: true),
                    _buildTextField(websiteController, 'Website', isUrl: true),
                    _buildTextField(dateController, 'Establishment Date',
                        required: true),
                    _buildTextField(descriptionController, 'Description',
                        maxLines: 3),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateCharityData,
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
                    const SizedBox(height: 10),
                    // Reset to blockchain data button
                    if (_dataFetched)
                      TextButton(
                        onPressed: () async {
                          setState(() => _isLoading = true);
                          final data = await fetchCharityData(_charityAddress);
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
    int maxLines = 1,
    bool isPhone = false,
    bool isEmail = false,
    bool isUrl = false,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
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
                : isUrl
                    ? TextInputType.url
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
          if (isUrl && value != null && value.isNotEmpty) {
            try {
              final uri = Uri.parse(value);
              if (!uri.isAbsolute) {
                return 'Please enter a valid URL';
              }
            } catch (e) {
              return 'Please enter a valid URL';
            }
          }
          return null;
        },
      ),
    );
  }
}
