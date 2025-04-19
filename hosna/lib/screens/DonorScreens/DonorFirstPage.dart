import 'package:flutter/material.dart';
import 'package:hosna/screens/DonorScreens/DonorLogin.dart';
import 'package:hosna/screens/DonorScreens/DonorSignup.dart';

class DonorFirstPage extends StatelessWidget {
  const DonorFirstPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/HOSNA.jpg', // Replace with the path to your logo
              width: 250,
              height: 250,
            ),

            // Description text
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Empowering Charity by Connecting Donors and Charity Organizations for Transparency and Improvement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
            ),
            const SizedBox(height: 200),
            // Sign Up Button
            ElevatedButton(
              onPressed: () {
                // Navigate to the Sign Up page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          DonorSignUpPage()), // Replace with your actual sign-up page
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Color.fromRGBO(24, 71, 137, 1),
                minimumSize: const Size(300, 50),
                backgroundColor:
                    const Color.fromARGB(255, 239, 236, 236), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 2), // Border color and width
                ), // Button text color
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Login Button
            ElevatedButton(
              onPressed: () {
                // Navigate to the Login page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DonorLogInPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Color.fromRGBO(24, 71, 137, 1),
                minimumSize: const Size(300, 50),
                backgroundColor:
                    const Color.fromRGBO(24, 71, 137, 1), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 2), // Border color and width
                ), // Button text color
              ),
              child: const Text(
                'Login',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white, // Add white color to the text
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
