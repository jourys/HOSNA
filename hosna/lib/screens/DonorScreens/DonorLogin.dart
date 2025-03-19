import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorNavBar.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DonorLogInPage extends StatefulWidget {
  const DonorLogInPage({super.key});

  @override
  _DonorLogInPageState createState() => _DonorLogInPageState();
}

class _DonorLogInPageState extends State<DonorLogInPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isResettingPassword = false;
  bool _isLoggingIn = false;
  String? _resetPasswordError;
  String? _loginError;
  bool _resetEmailSent = false;
  bool _isPasswordVisible = false;

  late Web3Client _web3Client;
  final String _rpcUrl = 'https://bsc-testnet-rpc.publicnode.com';
  late EthereumAddress _contractAddress;
  late ContractAbi _contractAbi;
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
      _contractAbi = ContractAbi.fromJson(abiString, 'Hosna');
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
          final prefs = await SharedPreferences.getInstance();
          final lastLoginTime = prefs.getString('lastLoginTime');
          final currentTime = DateTime.now().toIso8601String();

          if (lastLoginTime == null ||
              DateTime.parse(lastLoginTime).isBefore(
                  DateTime.now().subtract(const Duration(seconds: 5)))) {
            print("🔄 New login detected, checking for password reset");

            await Future.delayed(const Duration(seconds: 3));
            if (!mounted) return;
            final shouldUpdate = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Password Reset'),
                  content: const Text('Did you recently reset your password?'),
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
              final newPassword = await _showNewPasswordDialog();
              if (newPassword != null && newPassword.isNotEmpty) {
                try {
                  await _updateBlockchainPassword(user.email!, newPassword);
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
              await prefs.setString('lastLoginTime', currentTime);
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
                    if (!RegExp(
                            r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$')
                        .hasMatch(value)) {
                      return 'Password must meet complexity requirements';
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
      String walletAddress = await _getWalletAddressByEmail(email);
      if (walletAddress.isEmpty) {
        if (mounted) Navigator.of(context).pop();
        throw Exception('No donor found with this email');
      }

      final contract = DeployedContract(_contractAbi, _contractAddress);
      final resetPasswordFunction = contract.function('resetPassword');

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
        chainId: 97,
      );

      for (int i = 0; i < 12; i++) {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          if (receipt.status!) {
            print("✅ Blockchain password updated successfully");
            if (mounted) Navigator.of(context).pop();
            return;
          } else {
            if (mounted) Navigator.of(context).pop();
            throw Exception("Transaction failed");
          }
        }
        if (i == 11) {
          if (mounted) Navigator.of(context).pop();
          throw Exception("Transaction timeout");
        }
        if (mounted) {
          Navigator.of(context).pop();
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

      final contract = DeployedContract(_contractAbi, _contractAddress);
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

  Future<void> _authenticateDonor() async {
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
      await _tryFirebaseAuth(email, password);
      bool blockchainAuthSuccess = await _tryBlockchainAuth(email, password);

      if (blockchainAuthSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
      } else {
        try {
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

        // setState(() {
        //   _isLoggingIn = false;
        //   _loginError =
        //       'Blockchain authentication failed. Please contact support.';
        // });

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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Firebase authentication successful");
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
      throw errorMessage;
    }
  }

  Future<bool> _tryBlockchainAuth(String email, String password) async {
    try {
      print("🔍 Attempting blockchain authentication");

      final contract = DeployedContract(_contractAbi, _contractAddress);
      final authenticateFunction = contract.function('login');

      final result = await _web3Client.call(
        contract: contract,
        function: authenticateFunction,
        params: [email, password, BigInt.from(2)], // 2 for donor type
      );

      if (result.isNotEmpty && result[0] == true) {
        String walletAddress = result[1].hex;
        String privateKey = result[2];

        print("✅ Blockchain authentication successful!");
        await _saveWalletDetails(walletAddress, privateKey);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(walletAddress: walletAddress),
          ),
        );

        return true;
      }
      return false;
    } catch (e) {
      print("❌ Error in blockchain authentication: $e");
      return false;
    }
  }

  Future<String> _getWalletAddressByEmail(String email) async {
    try {
      final contract = DeployedContract(_contractAbi, _contractAddress);
      final lookupFunction = contract.function('getDonorAddressByEmail');

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
      }
      print("❌ No wallet address found");
      return "";
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
      print('✅ Wallet details saved successfully');
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
      String walletAddress = await _getWalletAddressByEmail(email);
      if (walletAddress.isEmpty) {
        setState(() {
          _resetPasswordError = 'No account found with this email address';
          _isResettingPassword = false;
        });
        return;
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      setState(() {
        _resetEmailSent = true;
        _isResettingPassword = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      setState(() {
        _resetPasswordError = 'Failed to send reset email: ${e.toString()}';
        _isResettingPassword = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build method implementation remains largely the same as your original code
    // Just update the button handlers to use the new methods
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
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome Back',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              const SizedBox(height: 80),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
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
              const SizedBox(height: 30),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
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
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isResettingPassword ? null : _resetPassword,
                  child: _isResettingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
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
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_resetEmailSent)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Password reset email sent to ${_emailController.text}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _isLoggingIn ? null : _authenticateDonor,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(300, 50),
                    backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: _isLoggingIn
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Log In',
                          style: TextStyle(fontSize: 20, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
