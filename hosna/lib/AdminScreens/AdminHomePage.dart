import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/charityRequests.dart';
import 'AdminSidebar.dart'; //
import 'package:hosna/screens/BrowseProjects.dart';


class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool isSidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
  color: Colors.white, // Change this to your desired color
  child: Row(
        children: [
          AdminSidebar(), 
          Expanded(
            child: Column(
              children: [ 
                 Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Dashboard ', // Page title
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(24, 71, 137, 1), // Customize the color
          ),
        ),
      ),
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                    onPressed: () {
                      setState(() {
                        isSidebarVisible = !isSidebarVisible;
                      });
                    },
                  ),
                ),
          Expanded(
  child: Center( // Ensures the grid is centered
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 120, vertical: 20), // Added horizontal padding for white space
      child: GridView(
        shrinkWrap: true, // Makes GridView take only the necessary space
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1, // 1 card per row
          crossAxisSpacing: 10, // Reduced horizontal spacing
          mainAxisSpacing: 10, // Reduced vertical spacing
          mainAxisExtent: 100, // Reduced height of each card
        ),
        children: [
         _buildDashboardCard(context, "Total projects", () {
  // The navigation happens here
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const BrowseProjects(walletAddress: ''),
    ),
  );
}),

          _buildDashboardCard(context, "Total new charity requests", () { // The navigation happens here
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>  CharityRequests(),
    ),
  );}),
          _buildDashboardCard(context, "Total new complaints", () {}),
        ],
      ),
    ),
  ),
),




              ],
            ),
          ),
        ],
      ),
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
// admin@gmail.com

 Widget _buildDashboardCard(BuildContext context, String title, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0), // Add spacing between cards
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300, // Adjust width as needed
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[300], // Gray background
          border: Border.all(color: Color.fromRGBO(24, 71, 137, 1), width: 2), // Border color
          borderRadius: BorderRadius.circular(5), // Slightly rounded corners
        ),
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold, // Make text bold
              color: Color.fromRGBO(24, 71, 137, 1), // Text color
            ),
          ),
        ),
      ),
    ),
  );
}

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

}
