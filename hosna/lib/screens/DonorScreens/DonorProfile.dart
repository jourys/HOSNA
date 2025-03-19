import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/EditDonorProfile.dart';
import 'package:hosna/screens/users.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/DonorScreens/DonorNavBar.dart';
import 'package:flutter/services.dart';

class ProfileScreenTwo extends StatefulWidget {
  const ProfileScreenTwo({super.key});

  @override
  _ProfileScreenTwoState createState() => _ProfileScreenTwoState();
}

class _ProfileScreenTwoState extends State<ProfileScreenTwo> {
  late Web3Client _web3Client;
  late String _donorAddress;
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  bool _isLoading = true;

  final String _rpcUrl = 'https://bsc-testnet-rpc.publicnode.com';
  final String _contractAddress = '0x662b9eecf8a37d033eab58120132ac82ae1b09cf';
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
      _web3Client = Web3Client(_rpcUrl, Client());
      print("✅ Web3Client initialized");

      // Get wallet address
      final prefs = await SharedPreferences.getInstance();
      _donorAddress = prefs.getString('walletAddress') ?? '';

      if (_donorAddress.isEmpty) {
        throw Exception("Wallet address not found");
      }
      print("✅ Wallet address loaded: $_donorAddress");

      // Load ABI and get donor data
      await _loadContractAbi();
      await _getDonorData();
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

  DeployedContract _getContract() {
    return DeployedContract(
      _contractAbi,
      EthereumAddress.fromHex(_contractAddress),
    );
  }

  Future<void> _getDonorData() async {
    try {
      final contract = _getContract();
      final getDonorFunction = contract.function('getDonor');

      final result = await _web3Client.call(
        contract: contract,
        function: getDonorFunction,
        params: [EthereumAddress.fromHex(_donorAddress)],
      );

      print("📌 Donor data result: $result");

      if (result.isEmpty) {
        throw Exception("No donor data found");
      }

      setState(() {
        _firstName = result[0].toString();
        _lastName = result[1].toString();
        _email = result[2].toString();
        _phone = result[3].toString();
      });

      print("✅ Profile data updated successfully");
    } catch (e) {
      print("❌ Error fetching donor data: $e");
      showError("Failed to fetch donor data");
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditDonorProfileScreen(
                    firstName: _firstName,
                    lastName: _lastName,
                    email: _email,
                    phone: _phone,
                  ),
                ),
              );

              if (result == true) {
                print("🔄 Refreshing profile after edit...");
                await _getDonorData();
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
                    Text(
                      '$_firstName $_lastName',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 50),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            infoRow('Phone Number : ', _phone),
                            infoRow('Email : ', _email),
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
              borderRadius: const BorderRadius.all(Radius.circular(24)),
            ),
          ),
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
              borderRadius: const BorderRadius.all(Radius.circular(24)),
            ),
          ),
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
      if (walletAddress != null) {
        await prefs.setString('walletAddress', walletAddress);
      }

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
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
