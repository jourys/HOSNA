import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hosna/screens/users.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to Home Page after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const UsersPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/HOSNA.jpg',
          width: 250, // Set the width as per your requirement
          height:
              250, // Set the height to maintain aspect ratio or adjust as needed
        ),
      ),
    );
  }
}
