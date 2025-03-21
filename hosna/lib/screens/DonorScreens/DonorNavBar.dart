import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:hosna/screens/DonorScreens/DonorNotificationsCenter.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final String? walletAddress;

  const MainScreen({super.key, this.walletAddress});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? walletAddress;
  String? firstName;
  bool isSuspended = false; // Track suspension status

  List<Widget> get _pages {
    return [
      HomePage(),
      BrowseProjects(walletAddress: walletAddress ?? ''),
      NotificationsPage(walletAddress: walletAddress ?? ''),
      OrganizationsPage(walletAddress: walletAddress ?? ''),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadWalletAddress();
  }

  Future<void> _loadWalletAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedWalletAddress = prefs.getString('walletAddress');
    
    setState(() {
      walletAddress = savedWalletAddress ?? widget.walletAddress;
      firstName = prefs.getString('firstName') ?? "User";
    });

    if (walletAddress != null) {
      _listenForSuspension(walletAddress!);
    }
  }

  void _listenForSuspension(String wallet) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(wallet)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        bool suspendStatus = snapshot['isSuspend'] ?? false;
        setState(() {
          isSuspended = suspendStatus;
        });
      }
    }, onError: (error) {
      print("❌ Error checking suspension: $error");
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
@override
Widget build(BuildContext context) {
  if (walletAddress == null) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    body: Column(
      children: [
        Expanded(child: _pages[_selectedIndex]), // Main page content
        if (isSuspended)
          Container(
            color: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    "Your account has been suspended. You cannot make any operation.",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 2; // Navigate to NotificationsPage
                    });
                  },
                  child: const Text(
                    "More",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color.fromRGBO(24, 71, 137, 1),
          unselectedItemColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 38),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                _selectedIndex == 1
                    ? 'assets/BlueProjects.png'
                    : 'assets/Projects.png',
                width: 30,
                height: 30,
              ),
              label: 'Projects',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.notifications, size: 35),
              label: 'Notifications',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.apartment, size: 35),
              label: 'Organizations',
            ),
          ],
        ),
      ],
    ),
  );
}

}
