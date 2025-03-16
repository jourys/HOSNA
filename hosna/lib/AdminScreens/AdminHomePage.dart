import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool isSidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          if (isSidebarVisible)
            Container(
              width: 350,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                 
                  // Logo
                  Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Image.asset(
                      'assets/HOSNA.jpg',
                      height: 200,
                      width: 350,
                    ),
                  ),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                 _buildSidebarItem(context, "Home", () { Navigator.push(
    context,
    MaterialPageRoute(
     builder: (context) => AdminHomePage(),

    ),
  );}),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Organizations", () {}),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Projects", () { Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>  AdminBrowseProjects(),
    ),
  );}),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Complaints", () {}),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                  _buildSidebarItem(context, "Terms & Conditions", () {}),
                  Divider(color:  Color.fromRGBO(24, 71, 137, 1)),
                  SizedBox(height: 50),
  _buildSidebarButton(
  title: "Sign Out",
  onTap: () {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AdminLoginPage()),
    );
  },
  backgroundColor: Colors.white,
  borderColor: Color.fromRGBO(24, 71, 137, 1),
  textColor: Color.fromRGBO(24, 71, 137, 1),

),



          SizedBox(height: 14),
          _buildSidebarButton(
            title: "Delete Account",
            onTap: () {
              // Handle delete account
            },
            backgroundColor: Colors.red,
            borderColor: Colors.red,
            textColor: Colors.white,
          ),
         
        ],
      ),
            ),
          Expanded(
            child: Column(
              children: [
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
      builder: (context) => const AdminBrowseProjects(),
    ),
  );
}),

          _buildDashboardCard(context, "Total new complains", () {}),
          _buildDashboardCard(context, "Total projects", () {}),
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
