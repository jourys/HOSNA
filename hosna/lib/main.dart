import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // هنا تعديلي: استيراد Firebase Core
import 'firebase_options.dart'; // هنا تعديلي: استيراد إعدادات Firebase

import 'screens/CharityScreens/CharitySignUpPage.dart'; // Import the missing CharityHome screen
import 'screens/CharityScreens/charityHome.dart'; // Import the Charity Sign-Up screen
import 'screens/splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // هنا تعديلي: التأكد من تهيئة الـ Widgets قبل Firebase
  await Firebase.initializeApp( // هنا تعديلي: تهيئة Firebase عند بدء التطبيق
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
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
          0xFF184787,
          <int, Color>{
            50: Color(0xFFE1E8F3),
            100: Color(0xFFB3C9E1),
            200: Color(0xFF80A8D0),
            300: Color(0xFF4D87BF),
            400: Color(0xFF2668A9),
            500: Color(0xFF184787),
            600: Color(0xFF165F75),
            700: Color(0xFF134D63),
            800: Color(0xFF104A52),
            900: Color(0xFF0D3841),
          },
        ),
      ),
      initialRoute: '/', // Define the initial route
      routes: {
        '/': (context) => const SplashScreen(),
        '/charityHome': (context) =>
            const CharityEmployeeHomePage(), // Ensure this class exists
        '/charitySignUp': (context) => const CharitySignUpPage(),
      },
    );
  }
}