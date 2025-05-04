import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SuspensionListener {
  final String walletAddress;
  late Stream<DocumentSnapshot> _userStream;

  SuspensionListener(this.walletAddress) {
    _userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(walletAddress)
        .snapshots();

    _listenForSuspension();
  }

  void _listenForSuspension() {
    _userStream.listen((snapshot) async {
      if (snapshot.exists) {
        bool isSuspend = snapshot['isSuspend'] ?? false;
        print("🔍 isSuspend status: $isSuspend for $walletAddress");

        if (isSuspend) {
          await _removePrivateKey();
        }
      }
    }, onError: (error) {
      print("❌ Error listening for suspension: $error");
    });
  }

  Future<void> _removePrivateKey() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('privateKey_$walletAddress');

      print("🚫 Private key removed due to suspension.");
    } catch (e) {
      print("⚠️ Error removing private key: $e");
    }
  }

  Future<void> reloadPrivateKey(String walletAddress) async {
    String? privateKey = await _fetchPrivateKeyFromSecureStorage(walletAddress);

    if (privateKey != null && privateKey.isNotEmpty) {
      print("✅ Private key successfully loaded for wallet $walletAddress.");
    } else {
      print("❌ Failed to load private key for wallet $walletAddress.");
    }
  }

  Future<String?> _fetchPrivateKeyFromSecureStorage(
      String walletAddress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print("✅ Private key retrieved for wallet $walletAddress.");
        return privateKey;
      } else {
        print("❌ No private key found for wallet $walletAddress.");
      }
    } catch (e) {
      print("⚠️ Error retrieving private key: $e");
    }
    return null;
  }
}
