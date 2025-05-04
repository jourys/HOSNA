import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:hosna/screens/NotificationListener.dart';
import 'package:hosna/screens/NotificationManager.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/SuspensionListener.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:hosna/screens/PasswordResetPage.dart';

class CharityLogInPage extends StatefulWidget {
  const CharityLogInPage({super.key});

  @override
  _CharityLogInPageState createState() => _CharityLogInPageState();
}

class _CharityLogInPageState extends State<CharityLogInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late Web3Client _web3Client;
  final String _rpcUrl =
      "https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac";
  final String _contractAddress = "0xFa8d16A4FF659c9c2E22C6f937eEcB4AC015A7a1";
  final String _lookupContractAddress =
      "0x2068dEC57b32b387f38daB251D06206b8d33481D";
  bool _isPasswordVisible = false; // Track password visibility
  final creatorPrivateKey =
      "9181d712c0e799db4d98d248877b048ec4045461b639ee56941d1067de83868c";
  final String _charityRegistryAddress =
      "0x25ef93ac312D387fdDeFD62CD852a29328c4B122";

  @override
  void initState() {
    super.initState();
    _web3Client = Web3Client(_rpcUrl, Client());
    print('✅ Web3Client initialized');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticateCharity() async {
    print("🟢 Charity Login Button Pressed!");

    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    print("📌 Raw Email: $email");
    print("📌 Raw Password: $password");

    try {
      bool authSuccess = await _checkAuth(email, password);

      if (authSuccess) {
        print("✅ Login successful!");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Login successful!')),
        // );

        // Perform wallet lookup
        String walletAddress = await _getWalletAddressByEmail(email);

        if (walletAddress.isNotEmpty) {
          // Save wallet address and private key to SharedPreferences
          try {
            // Save wallet address to SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('walletAddress', walletAddress);
            print('Wallet address saved to SharedPreferences');

            // Retrieve private key
            String? privateKey = await _getPrivateKey(walletAddress);

            if (privateKey != null) {
              print("✅ Loaded Private Key: $privateKey");
            } else {
              print("❌ No private key found for this wallet.");
            }
          } catch (e) {
            print('Error saving wallet address or retrieving private key: $e');
          }

          SuspensionListener(walletAddress);
          _checkAccountStatusAndNavigate(context, walletAddress.toString());
          // Navigate to main screen
          // Future.delayed(const Duration(seconds: 1), () {
          //   Navigator.pushReplacement(
          //     context,
          //     MaterialPageRoute(
          //       builder: (context) =>
          //           CharityMainScreen(walletAddress: walletAddress),
          //     ),
          //   );
          // });
        } else {
          print("❌ No Email address found!");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No wallet address found!')),
          );
        }
      } else {
        print("❌ Invalid credentials!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid credentials!')),
        );
      }
    } catch (e) {
      print('❌ Error in authentication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

// Function to retrieve the private key from SharedPreferences
  Future<String?> _getPrivateKey(String walletAddress) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (snapshot.exists && snapshot['isSuspend'] == true) {
        print("🚫 Access denied! Account is suspended.");
        return null;
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Retrieve private key using the correct key format
      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('Private key retrieved for wallet $walletAddress');
      } else {
        print('Private key not found for wallet $walletAddress');
      }

      return privateKey;
    } catch (e) {
      print('Error retrieving private key: $e');
      return null;
    }
  }

  /// Fetch wallet address from contract using email
  Future<String> _getWalletAddressByEmail(String email) async {
    try {
      final lookupContract = DeployedContract(
        ContractAbi.fromJson(
          '[{"constant":true,"inputs":[{"name":"_email","type":"string"}],"name":"getCharityWalletAddressByEmail","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"}]',
          'CharityEmailFetcher',
        ),
        EthereumAddress.fromHex(_lookupContractAddress),
      );

      final lookupFunction =
          lookupContract.function('getCharityWalletAddressByEmail');
      final walletResult = await _web3Client.call(
        contract: lookupContract,
        function: lookupFunction,
        params: [email],
      );

      if (walletResult.isNotEmpty &&
          walletResult[0] !=
              EthereumAddress.fromHex(
                  "0x0000000000000000000000000000000000000000")) {
        print("✅ Wallet Address Found: ${walletResult[0].hex}");
        return walletResult[0].hex;
      } else {
        print("No valid wallet address found!");
        return "";
      }
    } catch (e) {
      print('Error in wallet lookup: $e');
      return "";
    }
  }

  /// Save wallet address and private key to SharedPreferences
  Future<void> _saveWalletDetails(String walletAddress) async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (snapshot.exists && snapshot['isSuspend'] == true) {
        print("🚫 Access denied! Account is suspended.");
        return null;
      }
      final blockchainService = BlockchainService();
      final credentials = await blockchainService.getCharityCredentials();
      final privateKey = credentials['privateKey'];

      if (privateKey != null && privateKey.isNotEmpty) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('walletAddress', walletAddress);
        await prefs.setString('privateKey', privateKey);

        // ✅ Debug Logs
        print("✅ Private Key Successfully Saved: $privateKey");

        // 🔍 Immediately check if it is accessible
        String? storedKey = prefs.getString('privateKey');
        print("🔍 Retrieved Private Key After Saving: $storedKey");
      } else {
        print("Private Key is null or empty! Check login process.");
      }
    } catch (e) {
      print("Error saving wallet details: $e");
    }
  }

  Future<void> _checkAccountStatusAndNavigate(
      BuildContext context, String walletAddress) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (userDoc.exists) {
        String accountStatus = userDoc['accountStatus'];

        if (accountStatus == 'approved') {
          late ProjectNotificationListener projectNotificationListener;

          projectNotificationListener = ProjectNotificationListener(
            blockchainService: BlockchainService(),
            notificationService: NotificationService(),
          );

          projectNotificationListener.checkProjectsForCreator();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CharityMainScreen(walletAddress: walletAddress),
            ),
            (route) => false,
          );
        } else if (accountStatus == 'pending') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingPage(), // Navigate to a waiting page
            ),
          );
        } else if (accountStatus == 'rejected') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Your account has been rejected. Contact support for details."),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User not found. Please register."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("Error checking account status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An error occurred. Please try again."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool> _checkAuth(String email, String password) async {
    bool authSuccess = false;
    bool firebaseAuthSuccess = await _tryFirebaseAuth(email, password);
    print('Firebase authentication success: $firebaseAuthSuccess');
    bool blockchainAuthSuccess = await _tryBlockchainAuth(email, password);
    print('Blockchain authentication success: $blockchainAuthSuccess');
    // if (!firebaseAuthSuccess) {
    //   return;
    // }

    if (blockchainAuthSuccess && firebaseAuthSuccess) {
      authSuccess = true;
    } else if (!blockchainAuthSuccess && firebaseAuthSuccess) {
      authSuccess = true;
      await _blockchainPasswordChange(email, password);
    } else if (!firebaseAuthSuccess && blockchainAuthSuccess) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        authSuccess = true;
      } on FirebaseAuthException catch (e) {
        print("Firebase authentication error: ${e.code} - ${e.message}");
        authSuccess = false;
      }
    }
    return authSuccess;
  }

  Future<void> _blockchainPasswordChange(String email, String password) async {
    // Get the owner's credentials to pay for the gas fees
    final creatorCredentials = await _web3Client.credentialsFromPrivateKey(
        creatorPrivateKey); // Private key of contract owner
    final creatorWallet = await creatorCredentials.extractAddress();
    print("Creator's wallet address: $creatorWallet");

    // Define the contract and function reference
    final contract = DeployedContract(
      ContractAbi.fromJson(
        '''[
          {
            "inputs": [
              {
                "internalType": "address",
                "name": "_wallet",
                "type": "address"
              }
            ],
            "name": "getCharity",
            "outputs": [
              {
                "internalType": "string",
                "name": "name",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "email",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "phone",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "licenseNumber",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "city",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "description",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "website",
                "type": "string"
              },
              {
                "internalType": "string",
                "name": "establishmentDate",
                "type": "string"
              }
            ],
            "stateMutability": "view",
            "type": "function"
          },{
            "inputs": [
              {
                "internalType": "string",
                "name": "_email",
                "type": "string"
              }
            ],
            "name": "debugEmailMapping",
            "outputs": [
              {
                "internalType": "address",
                "name": "",
                "type": "address"
              }
            ],
            "stateMutability": "view",
            "type": "function"
          },{
          "inputs": [
            {
              "internalType": "address",
              "name": "_wallet",
              "type": "address"
            }
          ],
          "name": "deleteCharity",
          "outputs": [],
          "stateMutability": "nonpayable",
          "type": "function"
        },{
          "constant": false,
          "inputs": [
            {"name": "_name", "type": "string"},
            {"name": "_email", "type": "string"},
            {"name": "_phone", "type": "string"},
            {"name": "_licenseNumber", "type": "string"},
            {"name": "_city", "type": "string"},
            {"name": "_description", "type": "string"},
            {"name": "_website", "type": "string"},
            {"name": "_establishmentDate", "type": "string"},
            {"name": "_wallet", "type": "address"},
            {"name": "_password", "type": "string"}          
            ],
          "name": "registerCharity",
          "outputs": [],
          "payable": false,
          "stateMutability": "nonpayable",
          "type": "function"
        }]''',
        'CharityRegistry', // Contract name
      ),
      EthereumAddress.fromHex(_charityRegistryAddress),
    );
    print("Contract instantiated: $contract");

    final deleteCharity = contract.function('deleteCharity');
    final registerCharity = contract.function('registerCharity');
    final debugEmailMapping = contract.function('debugEmailMapping');
    final getCharity = contract.function('getCharity');
    print("Function reference obtained: $deleteCharity");

    final authResult = await _web3Client.call(
      contract: contract,
      function: debugEmailMapping,
      params: [email],
    );

    final charityWalletAddress = authResult[0];

    final charityDetails = await _web3Client.call(
      contract: contract,
      function: getCharity,
      params: [charityWalletAddress],
    );

    final charityName = charityDetails[0];
    final charityEmail = charityDetails[1];
    final charityPhone = charityDetails[2];
    final charityLicenseNumber = charityDetails[3];
    final charityCity = charityDetails[4];
    final charityDescription = charityDetails[5];
    final charityWebsite = charityDetails[6];
    final charityEstablishmentDate = charityDetails[7];

    print("Charity details: $charityDetails");

    try {
      // Send the transaction to register the donor using the creator's wallet for gas
      final result = await _web3Client.sendTransaction(
        creatorCredentials, // Use the creator's credentials to sign the transaction
        web3.Transaction.callContract(
          contract: contract,
          function: deleteCharity,
          parameters: [
            charityWalletAddress,
          ],
          gasPrice: web3.EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111, // Replace with your network chain ID
      );
      print("Transaction result: $result");
    } catch (e) {
      print("Error changing password: $e");
    }
    try {
      // Send the transaction to register the donor using the creator's wallet for gas
      final result = await _web3Client.sendTransaction(
        creatorCredentials, // Use the creator's credentials to sign the transaction
        web3.Transaction.callContract(
          contract: contract,
          function: registerCharity,
          parameters: [
            charityName,
            charityEmail,
            charityPhone,
            charityLicenseNumber,
            charityCity,
            charityDescription,
            charityWebsite,
            charityEstablishmentDate,
            charityWalletAddress,
            password,
          ],
          gasPrice: web3.EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111, // Replace with your network chain ID
      );
      print("Transaction result: $result");
    } catch (e) {
      print("Error changing password: $e");
    }
  }

  Future<bool> _tryFirebaseAuth(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("Firebase authentication successful");
      return true;
    } on FirebaseAuthException catch (e) {
      print("Firebase authentication error: ${e.code} - ${e.message}");
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        default:
          errorMessage = e.message ?? 'Authentication failed';
      }
      return false;
    }
  }

  Future<bool> _tryBlockchainAuth(String email, String password) async {
    try {
      final authContract = DeployedContract(
        ContractAbi.fromJson(
          '''[{"constant": true, "inputs": [{"name": "_email", "type": "string"}, {"name": "_password", "type": "string"}], "name": "loginCharity", "outputs": [{"name": "", "type": "bool"}], "payable": false, "stateMutability": "view", "type": "function"}]''',
          'CharityAuth',
        ),
        EthereumAddress.fromHex(_contractAddress),
      );

      final loginCharityFunction = authContract.function('loginCharity');

      final authResult = await _web3Client.call(
        contract: authContract,
        function: loginCharityFunction,
        params: [email, password],
      );

      print('Auth result: $authResult');

      return authResult.isNotEmpty && authResult[0] == true;
    } catch (e) {
      print('Error during blockchain authentication: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome Back',
                  style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(24, 71, 137, 1))),
              SizedBox(height: 80),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$')
                      .hasMatch(value.toLowerCase())) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),
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
                              const PasswordResetPage(), // الانتقال إلى صفحة إعادة تعيين كلمة المرور
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
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      _authenticateCharity();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(300, 50),
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1)),
                  child: Text('Log In',
                      style: TextStyle(fontSize: 20, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WaitingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Account Pending Approval"),
        centerTitle: true,

        backgroundColor:
            const Color.fromARGB(255, 255, 255, 255), // Dark blue header
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 55.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(LucideIcons.hourglass,
                size: 80,
                color:
                    const Color.fromARGB(159, 68, 113, 150)), // Hourglass icon

            const SizedBox(height: 20),
            const Text(
              "Your account is under review.",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF184789), // Dark blue text
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "We are verifying your information.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}
