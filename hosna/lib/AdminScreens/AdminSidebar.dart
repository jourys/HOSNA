import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/Terms&cond.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/ViewComplaintsPage.dart';
import 'package:web3dart/web3dart.dart';

class AdminSidebar extends StatelessWidget {
  final bool isSidebarVisible; // Pass visibility condition

  const AdminSidebar({Key? key, this.isSidebarVisible = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isSidebarVisible) return SizedBox(); // Hide sidebar if not visible

    return Container(
      width: 350,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Image.asset(
              'assets/HOSNA.jpg',
              height: 200,
              width: 350,
            ),
          ),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Home", () => _navigateTo(context, AdminHomePage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Organizations", () => _navigateTo(context, AdminBrowseOrganizations())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Projects", () => _navigateTo(context, AdminBrowseProjects())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Complaints", ()=> _navigateTo(context, ViewComplaintsPage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          _buildSidebarItem(context, "Terms & Conditions", () => _navigateTo(context, AdminTermsAndConditionsPage())),
          Divider(color: Color.fromRGBO(24, 71, 137, 1)),
          SizedBox(height: 50),
          _buildSidebarButton(
            title: "Sign Out",
            onTap: () => _navigateTo(context, AdminLoginPage(), replace: true),
            backgroundColor: Colors.white,
            borderColor: Color.fromRGBO(24, 71, 137, 1),
            textColor: Color.fromRGBO(24, 71, 137, 1),
          ),
          SizedBox(height: 14),
          _buildSidebarButton(
            title: "Delete Account",
            onTap: () {
              // Handle delete account logic
            },
            backgroundColor: Colors.red,
            borderColor: Colors.red,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

   Widget _buildSidebarItem(BuildContext context, String title, VoidCallback onTap, {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
  return ListTile(
    title: Center( // Center the text
      child: Text(
        title,
        style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
    onTap: onTap,
  );
}

  // Sidebar button widget
   Widget _buildSidebarButton({
  required String title,
  required VoidCallback onTap,
  required Color backgroundColor,
  required Color borderColor,
  required Color textColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 2), // Set border thickness here
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(
          title,
          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
}


  void _navigateTo(BuildContext context, Widget page, {bool replace = false}) {
    if (replace) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => page));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => page));
    }
  }
}
