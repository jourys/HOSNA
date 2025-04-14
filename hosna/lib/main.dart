import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // هنا تعديلي: استيراد Firebase Core
import 'firebase_options.dart'; // هنا تعديلي: استيراد إعدادات Firebase

import 'screens/CharityScreens/CharitySignUpPage.dart'; // Import the missing CharityHome screen
import 'screens/CharityScreens/charityHome.dart'; // Import the Charity Sign-Up screen
import 'screens/splash.dart';

void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // ✅ التأكد من تهيئة الـ Widgets قبل Firebase
  try {
    await Firebase.initializeApp(
      // 🚀 تهيئة Firebase عند بدء التطبيق
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized successfully 🎉");
  } catch (e) {
    print("❌ Error initializing Firebase: $e ");
  }

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
  primaryColor: const Color.fromRGBO(24, 71, 137, 1), // Set primary color
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: const MaterialColor(
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
  ).copyWith(
    primary: const Color.fromRGBO(24, 71, 137, 1),
    secondary: const Color.fromRGBO(24, 71, 137, 1),
  ),
  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: Color.fromRGBO(24, 71, 137, 1),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      foregroundColor: Colors.white,
    ),
  ),
   inputDecorationTheme: const InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.red),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    hintStyle: TextStyle(color: Colors.grey),
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
