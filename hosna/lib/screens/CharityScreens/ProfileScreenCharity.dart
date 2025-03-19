import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:hosna/screens/CharityScreens/_EditProfileScreenState.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:flutter/services.dart';

class ProfileScreenCharity extends StatefulWidget {
  const ProfileScreenCharity({super.key});

  @override
  _ProfileScreenCharityState createState() => _ProfileScreenCharityState();
}

class _ProfileScreenCharityState extends State<ProfileScreenCharity> {
  late Web3Client _web3Client; // For blockchain connection
  late String _charityAddress; // Wallet address of the charity
  String _organizationName = '';
  String _email = '';
  String _phone = '';
  String _licenseNumber = '';
  String _organizationCity = '';
  String _organizationURL = '';
  String _establishmentDate = '';
  String _description = '';
  bool _isLoading = true;

  final String rpcUrl =
      //  'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
      'https://bsc-testnet-rpc.publicnode.com';
  final String contractAddress =
      // '0x168ef53DA3d4B294D4c2651Ae39c64310D35AabE';
      '0x662b9eecf8a37d033eab58120132ac82ae1b09cf';
  late ContractAbi _contractAbi;

  @override
  void initState() {
    super.initState();
    _initializeWeb3AndLoadData();
  }

  Future<void> _initializeWeb3AndLoadData() async {
    setState(() => _isLoading = true);
    try {
      // Initialize Web3 client
      _web3Client = Web3Client(rpcUrl, Client());
      print("✅ Web3Client initialized");

      // Get wallet address
      final prefs = await SharedPreferences.getInstance();
      _charityAddress = prefs.getString('walletAddress') ?? '';

      if (_charityAddress.isEmpty) {
        throw Exception("Wallet address not found");
      }
      print("✅ Wallet address loaded: $_charityAddress");

      // Load ABI and get charity data
      await _loadContractAbi();
      await _getCharityData();
    } catch (e) {
      print("❌ Initialization error: $e");
      showError("Failed to load profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContractAbi() async {
    try {
      final String abiString = await rootBundle.loadString('assets/abi.json');
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print("✅ Contract ABI loaded successfully");
    } catch (e) {
      print("❌ Error loading ABI: $e");
      showError("Failed to load contract ABI");
      throw e;
    }
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
      {
        "constant": true,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "getCharity",
        "outputs": [
          {"name": "organizationName", "type": "string"},
          {"name": "email", "type": "string"},
          {"name": "phone", "type": "string"},
          {"name": "licenseNumber", "type": "string"},
          {"name": "city", "type": "string"},
          {"name": "website", "type": "string"},
          {"name": "establishmentDate", "type": "string"},
          {"name": "description", "type": "string"}
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'CharityRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  DeployedContract _getContract() {
    return DeployedContract(
      _contractAbi,
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<void> _getCharityData() async {
    try {
      final contract = _getContract();

      // Get basic charity info
      final getCharityFunction = contract.function('getCharity');
      final charityResult = await _web3Client.call(
        contract: contract,
        function: getCharityFunction,
        params: [EthereumAddress.fromHex(_charityAddress)],
      );

      print("📌 Basic charity data result: $charityResult");

      // Get detailed charity info
      final getDetailFunction = contract.function('getCharityDetails');
      final detailResult = await _web3Client.call(
        contract: contract,
        function: getDetailFunction,
        params: [EthereumAddress.fromHex(_charityAddress)],
      );

      print("📌 Charity detail result: $detailResult");

      setState(() {
        // Basic info from getCharity
        _organizationName = charityResult[0].toString();
        _email = charityResult[1].toString();
        _phone = charityResult[2].toString();
        _organizationCity = charityResult[3].toString();
        _organizationURL = charityResult[4].toString();

        // Detailed info from getCharityDetails
        _description = detailResult[0].toString();
        _licenseNumber = detailResult[1].toString();
        _establishmentDate = detailResult[2].toString();
      });

      print("✅ Profile data updated successfully");
    } catch (e) {
      print("❌ Error fetching charity data: $e");
      showError("Failed to fetch charity data");
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<List<dynamic>> _callGetCharityMethod(DeployedContract contract,
      String methodName, List<dynamic> params) async {
    try {
      final function = contract.function(methodName);
      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: params,
      );
      return result;
    } catch (e) {
      print("Error calling contract method: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const CharityMainScreen()),
            );
          },
        ),
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(
                    organizationName: _organizationName,
                    email: _email,
                    phone: _phone,
                    licenseNumber: _licenseNumber,
                    organizationCity: _organizationCity,
                    organizationURL: _organizationURL,
                    establishmentDate: _establishmentDate,
                    description: _description,
                  ),
                ),
              );

              if (result == true) {
                print("🔄 Refreshing profile after edit...");
                _getCharityData();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: Colors.blue[900],
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.all(50),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.account_circle,
                          size: 100, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    Text(_organizationName,
                        style: TextStyle(
                            color: Colors.blue[900],
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 60),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            infoRow('Phone Number : ', _phone),
                            infoRow('Email : ', _email),
                            infoRow('License Number : ', _licenseNumber),
                            infoRow('City : ', _organizationCity),
                            infoRow('Website : ', _organizationURL),
                            infoRow(
                                'Establishment Date : ', _establishmentDate),
                            infoRow('Description : ', _description),
                            const SizedBox(height: 200),
                            _buildLogoutButton(context),
                            const SizedBox(height: 20),
                            _buildDeleteAccountButton(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .066,
        width: MediaQuery.of(context).size.width * .8,
        child: ElevatedButton(
          onPressed: () => _handleLogout(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[900],
              shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.blue[900]!),
                  borderRadius: const BorderRadius.all(Radius.circular(24)))),
          child: const Text(
            'Log out',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Center(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .066,
        width: MediaQuery.of(context).size.width * .8,
        child: ElevatedButton(
          onPressed: () => _handleDeleteAccount(),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.red[900]!),
                  borderRadius: const BorderRadius.all(Radius.circular(24)))),
          child: const Text(
            'Delete Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Store credentials temporarily
      String? privateKey = prefs.getString('privateKey');
      String? walletAddress = prefs.getString('walletAddress');

      // Clear session data
      await prefs.clear();

      // Restore credentials
      if (privateKey != null) await prefs.setString('privateKey', privateKey);
      if (walletAddress != null)
        await prefs.setString('walletAddress', walletAddress);

      print('✅ Logged out successfully');

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UsersPage()),
      );
    } catch (e) {
      print('❌ Error during logout: $e');
      showError('Failed to log out');
    }
  }

  void _handleDeleteAccount() {
    // TODO: Implement account deletion
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This feature is not yet implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.blue[900],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
