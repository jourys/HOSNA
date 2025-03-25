import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:hosna/screens/CharityScreens/CharityNotificationsCenter.dart';
import 'package:hosna/screens/CharityScreens/PostProject.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CharityMainScreen extends StatefulWidget {
  final String? walletAddress;

  const CharityMainScreen({super.key, this.walletAddress});

  @override
  _CharityMainScreenState createState() => _CharityMainScreenState();
}

class _CharityMainScreenState extends State<CharityMainScreen> {
  int _selectedIndex = 0;
  String? walletAddress;
  String? firstName;
  bool isSuspended = false; 

  List<Widget> get _pages {
    return [
      CharityEmployeeHomePage(),
      BrowseProjects(walletAddress: walletAddress ?? ''),
      CharityNotificationsPage(),
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
    String? storedWallet = prefs.getString('walletAddress') ?? widget.walletAddress;

    setState(() {
      walletAddress = storedWallet;
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
        if (suspendStatus != isSuspended) { 
          setState(() {
            isSuspended = suspendStatus;
          });
        }
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

  void _navigateToPostProject() {
    if (!isSuspended) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostProject(walletAddress: walletAddress),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

  return Scaffold(
  resizeToAvoidBottomInset: false, // Prevent resizing when the keyboard is visible
  body: Column(
    children: [
      Expanded(child: _pages[_selectedIndex]),

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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
             
              TextButton(
                onPressed: () {
                  _onItemTapped(2); // Navigate to NotificationsPage
                },
                child: const Text(
                  "More",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
            icon: Icon(Icons.notifications, size: 38),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.apartment, size: 38),
            label: 'Organizations',
          ),
        ],
      ),
    ],
  ),
  
  floatingActionButton: isSuspended
    ? null
    : Padding(
        padding: const EdgeInsets.only(bottom: 22), // Adjust this value as needed
        child: FloatingActionButton(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          shape: const CircleBorder(),
          onPressed: _navigateToPostProject,
          child: const Icon(Icons.add, color: Colors.white, size: 40),
        ),
      ),
  floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
);

  }
}
