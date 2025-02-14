import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityEmployeeRegistration.dart';
import 'package:hosna/screens/DonorScreens/DonorFirstPage.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

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
              width: 250, // Set the width as per your requirement
              height: 250,
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 40),
            // Donor Button
            // Donor Button
            ElevatedButton(
              onPressed: () {
                // Navigate to DonorFirstPage
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DonorFirstPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Color.fromRGBO(24, 71, 137, 1),
                minimumSize: const Size(308, 66),
                backgroundColor:
                    const Color.fromARGB(255, 239, 236, 236), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 2), // Border color and width
                ), // Button text color
              ),
              child: const Text(
                'Donor',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Charity Organization Button
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          const Charityemployeeregistration()),
                );
                // Navigate to Charity Organization-related page (you can replace this with actual navigation)
                // print('Charity Organization Button Pressed');
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Color.fromRGBO(24, 71, 137, 1),
                minimumSize: const Size(308, 66),
                backgroundColor:
                    const Color.fromARGB(255, 239, 236, 236), // Button size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 2), // Border color and width
                ), // Button text color
              ),
              child: const Text(
                'Charity Employee',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
