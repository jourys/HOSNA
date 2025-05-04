import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/Terms&cond.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/ViewComplaintsPage.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:http/http.dart';

class AdminSidebar extends StatelessWidget {
  final bool isSidebarVisible;

  const AdminSidebar({Key? key, this.isSidebarVisible = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isSidebarVisible) return SizedBox(); // Hide sidebar if not visible

    return Container(
      width: 350, // Can reduce this if needed for responsive design
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: 16.0, bottom: 8.0), // Reduced padding
            child: Image.asset(
              'assets/HOSNA.jpg',
              height: 150, // Adjusted height to fit better
              width: 350,
            ),
          ),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(
              context, "Home", () => _navigateTo(context, AdminHomePage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Organizations",
              () => _navigateTo(context, AdminBrowseOrganizations())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Projects",
              () => _navigateTo(context, BrowseProjects(walletAddress: ''))),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Complaints",
              () => _navigateTo(context, ViewComplaintsPage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Terms & Conditions",
              () => _navigateTo(context, AdminTermsAndConditionsPage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          SizedBox(height: 50),
          _buildSidebarButton(
            title: "Sign Out",
            onTap: () => _navigateTo(context, AdminLoginPage(), replace: true),
            backgroundColor: Colors.white,
            borderColor: Color.fromRGBO(24, 71, 137, 1),
            textColor: Color.fromRGBO(24, 71, 137, 1),
          ),
          SizedBox(height: 14),
          _buildSidebarButton(
            title: "Delete Account",
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Confirm Deletion"),
                  content: const Text(
                      "Are you sure you want to permanently delete your admin account?"),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel")),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text("Delete")),
                  ],
                ),
              );

              if (confirm == true) {
                await _deleteAdminAccount(context);
              }
            },
            backgroundColor: Colors.red,
            borderColor: Colors.red,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdminAccount(BuildContext context) async {
    try {
      final privateKey =
          'eb0d1b04998eefc4f3b3f0ebad479607f6e2dc5f8cd76ade6ac2dc616861fa90'; // used joury wallet
      final walletAddress =
          '0x6AaebB1a5653fF9bF938E1365922362b6d8C2E0b'; //used joury wallet

      final client = Web3Client(
        "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1",
        Client(),
      );

      final credentials = await client.credentialsFromPrivateKey(privateKey);

      final contract = DeployedContract(
        ContractAbi.fromJson(
          '''
      [
  {
    "constant": false,
    "inputs": [],
    "name": "deleteAccount",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]

        ''',
          'AdminAccount',
        ),
        EthereumAddress.fromHex("0xC0707D3cdd5238908d86712A09098c57675796C0"),
      );

      final deleteFunction = contract.function('deleteAccount');

      final txHash = await client.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: deleteFunction,
          parameters: [], // ✅ empty list – no arguments
        ),
        chainId: 11155111,
      );

      print('✅ Admin account deleted. Tx: $txHash');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully.')),
      );

      // Navigate back to login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AdminLoginPage()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Error deleting admin account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete account: $e')),
      );
    }
  }

  Widget _buildSidebarItem(
      BuildContext context, String title, VoidCallback onTap,
      {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
    return ListTile(
      title: Center(
        // Center the text
        child: Text(
          title,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSidebarButton({
    required String title,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            side: BorderSide(color: borderColor, width: 2),
            padding: EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(
            title,
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page, {bool replace = false}) {
    if (replace) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => page));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }
}
