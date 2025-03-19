import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/CharityNavBar.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CharityLogInPage extends StatefulWidget {
  const CharityLogInPage({super.key});

  @override
  _CharityLogInPageState createState() => _CharityLogInPageState();
}

class _CharityLogInPageState extends State<CharityLogInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isResettingPassword = false;
  bool _isLoggingIn = false;
  String? _resetPasswordError;
  String? _loginError;
  bool _resetEmailSent = false;

  late Web3Client _web3Client;
  final String _rpcUrl =
      // "https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac";
      'https://bsc-testnet-rpc.publicnode.com';
  late EthereumAddress _contractAddress;
  bool _isPasswordVisible = false;

  // ABI definitions
  late ContractAbi _authContractAbi;
  late StreamSubscription<User?> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _initWeb3();
    _loadContractAbi();
    // _setupAuthStateListener();
  }

  void _initWeb3() {
    _web3Client = Web3Client(_rpcUrl, Client());
    print('✅ Web3Client initialized with URL: $_rpcUrl');
    _contractAddress =
        // EthereumAddress.fromHex("0x168ef53DA3d4B294D4c2651Ae39c64310D35AabE");
        EthereumAddress.fromHex("0x662b9eecf8a37d033eab58120132ac82ae1b09cf");
  }

  @override
  void dispose() {
    // _authStateSubscription.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadContractAbi() async {
    try {
      final String abiString = await rootBundle.loadString('assets/abi.json');
      _authContractAbi = ContractAbi.fromJson(abiString, 'Hosna');
      print("✅ Contract ABI loaded successfully");
    } catch (e) {
      print("❌ Error loading ABI: $e");
    }
  }

  void _setupAuthStateListener() {
    _authStateSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        print("👤 User state changed: ${user.email}");

        try {
          // Get the user's metadata
          final metadata = await user.reload();
          final currentUser = FirebaseAuth.instance.currentUser;

          if (user != null) {
            // Check if this is a password reset login
            final prefs = await SharedPreferences.getInstance();
            final lastLoginTime = prefs.getString('lastLoginTime');
            final currentTime = DateTime.now().toIso8601String();
            print("👤 Last login time: $lastLoginTime");

            if (lastLoginTime == null ||
                DateTime.parse(lastLoginTime).isBefore(
                    DateTime.now().subtract(const Duration(seconds: 5)))) {
              print("🔄 New login detected, checking for password reset");

              await Future.delayed(const Duration(seconds: 3));
              // Show dialog to confirm if password was reset
              if (!mounted) return;
              final shouldUpdate = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Password Reset'),
                    content:
                        const Text('Did you recently reset your password?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('No'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Yes'),
                      ),
                    ],
                  );
                },
              );

              if (shouldUpdate == true) {
                // Get new password from user
                final newPassword = await _showNewPasswordDialog();

                if (newPassword != null && newPassword.isNotEmpty) {
                  try {
                    // Update blockchain password
                    await _updateBlockchainPassword(user.email!, newPassword);

                    // Update last login time
                    await prefs.setString('lastLoginTime', currentTime);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Password successfully synchronized with blockchain'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("❌ Failed to update blockchain password: $e");
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update blockchain: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                // Update last login time anyway
                await prefs.setString('lastLoginTime', currentTime);
              }
            }
          }
        } catch (e) {
          print("❌ Error checking user state: $e");
        }
      }
    });
  }

  Future<String?> _showNewPasswordDialog() async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm New Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please enter your new password to sync with blockchain',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your new password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(passwordController.text);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateBlockchainPassword(
      String email, String newPassword) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Updating password in blockchain...'),
            ],
          ),
        );
      },
    );

    try {
      // Get charity address from email
      String walletAddress = await _getWalletAddressByEmail(email);
      if (walletAddress.isEmpty) {
        // Close loading dialog
        if (mounted) Navigator.of(context).pop();
        throw Exception('No charity found with this email');
      }

      final contract = DeployedContract(_authContractAbi, _contractAddress);
      final resetPasswordFunction = contract.function('resetPassword');

      // Get owner credentials for the transaction
      final String ownerPrivateKey =
          "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
      final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);

      print("📤 Updating blockchain password...");

      final txHash = await _web3Client.sendTransaction(
        ownerCredentials,
        Transaction.callContract(
          contract: contract,
          function: resetPasswordFunction,
          parameters: [
            EthereumAddress.fromHex(walletAddress),
            newPassword,
          ],
          maxGas: 2000000,
        ),
        chainId: 97, // BSC Testnet
      );

      // Wait for transaction confirmation with timeout
      for (int i = 0; i < 12; i++) {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status!) {
            print("✅ Blockchain password updated successfully");
            // Close loading dialog
            if (mounted) Navigator.of(context).pop();
            return;
          } else {
            // Close loading dialog
            if (mounted) Navigator.of(context).pop();
            throw Exception("Transaction failed");
          }
        }
        if (i == 11) {
          // Close loading dialog
          if (mounted) Navigator.of(context).pop();
          throw Exception("Transaction timeout");
        }
        // Update loading message with progress
        if (mounted) {
          Navigator.of(context).pop(); // Remove old dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Waiting for confirmation... (${i + 1}/12)'),
                  ],
                ),
              );
            },
          );
        }
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      print("❌ Error updating blockchain password: $e");
      // Close loading dialog if still showing
      if (mounted) {
        Navigator.of(context).pop();
      }
      throw e;
    }
  }

  Future<void> _updatedResetPassword(String email, String newPassword) async {
    try {
      // Get charity address from email
      String walletAddress = await _getWalletAddressByEmail(email);
      if (walletAddress.isEmpty) {
        throw Exception('No charity found with this email');
      }

      final contract = DeployedContract(_authContractAbi, _contractAddress);
      final resetPasswordFunction = contract.function('resetPassword');

      // Get owner credentials for the transaction
      final String ownerPrivateKey =
          "eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90";
      final ownerCredentials = EthPrivateKey.fromHex(ownerPrivateKey);

      final txHash = await _web3Client.sendTransaction(
        ownerCredentials,
        Transaction.callContract(
          contract: contract,
          function: resetPasswordFunction,
          parameters: [
            EthereumAddress.fromHex(walletAddress),
            newPassword,
          ],
          maxGas: 2000000,
        ),
        chainId: 97,
      );

      // Wait for transaction confirmation
      for (int i = 0; i < 12; i++) {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status!) {
            return;
          } else {
            throw Exception("Transaction failed");
          }
        }
        if (i == 11) {
          throw Exception("Transaction timeout");
        }
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      print("❌ Error updating blockchain password: $e");
      throw e;
    }
  }

  Future<void> _authenticateCharity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _loginError = null;
    });

    String email = _emailController.text.trim().toLowerCase();
    String password = _passwordController.text.trim();

    print("🔄 Starting authentication process for email: $email");

    try {
      // 1. Try Firebase authentication first
      await _tryFirebaseAuth(email, password);

      // 2. Then try blockchain authentication
      bool blockchainAuthSuccess = await _tryBlockchainAuth(email, password);

      if (blockchainAuthSuccess) {
        // Successfully authenticated with both Firebase and blockchain
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
      } else {
        // _setupAuthStateListener();
        try {
          // Update blockchain password to match Firebase password
          await _updatedResetPassword(email, password);

          // Try blockchain authentication again
          blockchainAuthSuccess = await _tryBlockchainAuth(email, password);

          if (!blockchainAuthSuccess) {
            throw Exception("Failed to authenticate after password sync");
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
        } catch (e) {
          print("❌ Error syncing passwords: $e");
          // Sign out from Firebase since sync failed
          await FirebaseAuth.instance.signOut();
          throw Exception("Failed to sync passwords: $e");
        }

        // If we got here, Firebase succeeded but blockchain failed
        // setState(() {
        //   _isLoggingIn = false;
        //   _loginError =
        //       'Blockchain authentication failed. Please contact support.';
        // });

        // Sign out from Firebase since blockchain auth failed
        // await FirebaseAuth.instance.signOut();

        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //       content: Text('Authentication failed with blockchain')),
        // );
      }
    } catch (e) {
      print("❌ Authentication error: $e");
      setState(() {
        _isLoggingIn = false;
        _loginError = e.toString();
      });
      await FirebaseAuth.instance.signOut();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _tryFirebaseAuth(String email, String password) async {
    try {
      print("🔍 Attempting Firebase authentication");

      // Try signing in with Firebase
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      print(
          "✅ Firebase authentication successful for user: ${userCredential.user?.email}");
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase authentication error: ${e.code} - ${e.message}");

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

      // Create user if they don't exist in Firebase but we'll verify with blockchain first
      if (e.code == 'user-not-found') {
        print(
            "⚠️ User not found in Firebase, will check blockchain before creating");
        return; // Continue to blockchain auth without throwing
      }

      throw errorMessage;
    }
  }

  Future<bool> _tryBlockchainAuth(String email, String password) async {
    try {
      print("🔍 Attempting blockchain authentication");

      final contract = DeployedContract(
        _authContractAbi,
        _contractAddress,
      );

      // Try the enhanced authentication method first
      final authenticateFunction = contract.function('login');

      print("📡 Calling authenticateCharityComplete with email: $email");

      final result = await _web3Client.call(
        contract: contract,
        function: authenticateFunction,
        params: [email, password, BigInt.from(1)],
      );

      print("📊 Authentication result: $result");

      if (result.isNotEmpty && result[0] == true) {
        // Authentication succeeded
        String walletAddress = result[1].hex;
        String privateKey = result[2];

        print("✅ Blockchain authentication successful!");
        print("🔑 Wallet address: $walletAddress");

        // Save the wallet details
        await _saveWalletDetails(walletAddress, privateKey);

        // Create Firebase user if it doesn't exist
        await _createFirebaseUserIfNeeded(email, password);

        // Navigate to main screen
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CharityMainScreen(walletAddress: walletAddress),
            ),
          );
        });

        return true;
      } else {
        // Fallback to the original loginCharity method if the enhanced one fails
        // return await _fallbackBlockchainAuth(email, password);
        return false;
      }
    } catch (e) {
      print("❌ Error in blockchain authentication: $e");

      // Try fallback login method
      // return await _fallbackBlockchainAuth(email, password);
      return false;
    }
  }

  // Future<bool> _fallbackBlockchainAuth(String email, String password) async {
  //   try {
  //     print("🔄 Falling back to original loginCharity method");

  //     final contract = DeployedContract(
  //       _authContractAbi,
  //       _contractAddress,
  //     );

  //     final loginFunction = contract.function('loginCharity');

  //     final result = await _web3Client.call(
  //       contract: contract,
  //       function: loginFunction,
  //       params: [email, password],
  //     );

  //     if (result.isNotEmpty && result[0] == true) {
  //       print("✅ Fallback authentication successful");

  //       // Get wallet address
  //       String walletAddress = await _getWalletAddressByEmail(email);

  //       if (walletAddress.isNotEmpty) {
  //         await _saveWalletDetails(walletAddress);

  //         // Create Firebase user if it doesn't exist
  //         await _createFirebaseUserIfNeeded(email, password);

  //         // Navigate to main screen
  //         Future.delayed(const Duration(seconds: 1), () {
  //           Navigator.pushReplacement(
  //             context,
  //             MaterialPageRoute(
  //               builder: (context) =>
  //                   CharityMainScreen(walletAddress: walletAddress),
  //             ),
  //           );
  //         });

  //         return true;
  //       } else {
  //         print("❌ No wallet address found for email");
  //         throw "No wallet address found for this account";
  //       }
  //     } else {
  //       print("❌ Fallback authentication failed");
  //       throw "Invalid credentials";
  //     }
  //   } catch (e) {
  //     print("❌ Error in fallback authentication: $e");
  //     throw "Authentication failed: $e";
  //   }
  // }

  Future<void> _createFirebaseUserIfNeeded(
      String email, String password) async {
    try {
      // Check if user exists by trying to sign in
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      print("✅ User exists in Firebase");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        try {
          // Create user if not found
          await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password);
          print("✅ Created new Firebase user");
        } catch (createError) {
          print("❌ Failed to create Firebase user: $createError");
        }
      }
    }
  }

  Future<String> _getWalletAddressByEmail(String email) async {
    try {
      final contract = DeployedContract(
        _authContractAbi,
        _contractAddress,
      );

      final lookupFunction = contract.function('getCharityAddressByEmail');

      final result = await _web3Client.call(
        contract: contract,
        function: lookupFunction,
        params: [email],
      );

      if (result.isNotEmpty &&
          result[0] !=
              EthereumAddress.fromHex(
                  "0x0000000000000000000000000000000000000000")) {
        print("✅ Wallet address found: ${result[0].hex}");
        return result[0].hex;
      } else {
        print("❌ No wallet address found");
        return "";
      }
    } catch (e) {
      print("❌ Error getting wallet address: $e");
      return "";
    }
  }

  Future<void> _saveWalletDetails(
      String walletAddress, String privateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('walletAddress', walletAddress);
      await prefs.setString('privateKey', privateKey);
    } catch (e) {
      print("❌ Error saving wallet details: $e");
    }
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isResettingPassword = true;
      _resetPasswordError = null;
    });

    String email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      setState(() {
        _resetPasswordError = 'Please enter your email address';
        _isResettingPassword = false;
      });
      return;
    }

    try {
      print("🔄 Sending password reset email to: $email");

      // First check if the user exists in blockchain
      String walletAddress = await _getWalletAddressByEmail(email);

      if (walletAddress.isEmpty) {
        setState(() {
          _resetPasswordError = 'No account found with this email address';
          _isResettingPassword = false;
        });
        return;
      }

      // Then send the reset email through Firebase
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      print("✅ Password reset email sent successfully");

      setState(() {
        _resetEmailSent = true;
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase error: ${e.code} - ${e.message}");

      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      setState(() {
        _resetPasswordError = errorMessage;
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_resetPasswordError!)),
      );
    } catch (e) {
      print("❌ General error: $e");

      setState(() {
        _resetPasswordError = 'An unexpected error occurred';
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
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
                    labelText: 'Email Address', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email address';
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResettingPassword ? null : _resetPassword,
                  child: _isResettingPassword
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color.fromRGBO(24, 71, 137, 1),
                          ),
                        ),
                ),
              ),
              if (_resetPasswordError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _resetPasswordError!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (_resetEmailSent)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Password reset email sent to ${_emailController.text}',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              if (_loginError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _loginError!,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoggingIn
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _authenticateCharity();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      minimumSize: Size(300, 50),
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1)),
                  child: _isLoggingIn
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Log In',
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
