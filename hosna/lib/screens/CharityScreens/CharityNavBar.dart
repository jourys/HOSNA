import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:hosna/screens/CharityScreens/CharityNotificationsCenter.dart';
import 'package:hosna/screens/CharityScreens/PostProject.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    setState(() {
      walletAddress = prefs.getString('walletAddress') ?? widget.walletAddress;
      firstName = prefs.getString('firstName') ?? "User";
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToPostProject() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              PostProject()), // Navigate to PostProjectPage
    );
  }

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    print(
        "Wallet Address: $walletAddress"); // This will print the wallet address

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color.fromRGBO(24, 71, 137, 1),
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
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
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications, size: 38),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apartment, size: 38),
            label: 'Organizations',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        shape: CircleBorder(),
        onPressed: _navigateToPostProject, // Navigate to Post Project Page
        child:
            Icon(Icons.add, color: Color.fromRGBO(255, 255, 255, 1), size: 40),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
