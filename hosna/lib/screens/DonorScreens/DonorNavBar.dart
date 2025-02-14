import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:hosna/screens/DonorScreens/DonorNotificationsCenter.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/projects.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  final String? walletAddress; // Wallet address is now nullable

  // Constructor to receive the wallet address
  const MainScreen({super.key, this.walletAddress});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? walletAddress; // Initialize the wallet address
  String? firstName; // Add firstName variable
  // Pass the wallet address to all pages
  List<Widget> get _pages {
    return [
      HomePage(), // Pass firstName
      ProjectsPage(walletAddress: walletAddress ?? ''),
      NotificationsPage(walletAddress: walletAddress ?? ''),
      OrganizationsPage(walletAddress: walletAddress ?? ''),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadWalletAddress(); // Load the wallet address from SharedPreferences
  }

  // Load wallet address from SharedPreferences
  Future<void> _loadWalletAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedWalletAddress =
        prefs.getString('walletAddress'); // Retrieve saved wallet address
    setState(() {
      walletAddress = savedWalletAddress ??
          widget.walletAddress; // Use saved address if available
      firstName = prefs.getString('firstName') ??
          "User"; // Default to "User" if not found
    });
    print(
        "Loaded Wallet Address: $walletAddress"); // Debugging the wallet address
    print("Loaded First Name: $firstName");
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      // If walletAddress is null, show a loading screen
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    print(
        "Wallet Address: $walletAddress"); // This will print the wallet address

    return Scaffold(
      body: _pages[_selectedIndex], // Display the selected page
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color.fromRGBO(24, 71, 137, 1),
        unselectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 38, weight: 38),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications, size: 35, weight: 35),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment, size: 35, weight: 35),
            label: 'Organizations',
          ),
        ],
      ),
    );
  }
}
