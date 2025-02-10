import 'package:flutter/material.dart';
import 'package:hosna/screens/HomePage.dart';
import 'package:hosna/screens/notificationsCenter.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/projects.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(),
    ProjectsPage(),
    NotificationsPage(),
    OrganizationsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
