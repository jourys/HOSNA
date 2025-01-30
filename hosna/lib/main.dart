import 'package:flutter/material.dart';

import "screens/splash.dart"; // Import Splash Screen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hosna App',
      theme: ThemeData(
        primarySwatch: MaterialColor(
          0xFF184787, // Color from RGBA(24, 71, 137, 1)
          <int, Color>{
            50: Color(0xFFE1E8F3),
            100: Color(0xFFB3C9E1),
            200: Color(0xFF80A8D0),
            300: Color(0xFF4D87BF),
            400: Color(0xFF2668A9),
            500: Color(0xFF184787), // This is the base color
            600: Color(0xFF165F75),
            700: Color(0xFF134D63),
            800: Color(0xFF104A52),
            900: Color(0xFF0D3841),
          },
        ),
      ),

      home: const SplashScreen(), // Start with the SplashScreen
    );
  }
}
