import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/charityRequests.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'AdminSidebar.dart'; //
import 'package:hosna/screens/BrowseProjects.dart';

class AdminHomePage extends StatefulWidget {
  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool isSidebarVisible = true;
    final BlockchainService _blockchainService = BlockchainService();

int _projectCount = 0;

 Future<void> fetchProjectCount() async {
  final projectCount = await _blockchainService.getProjectCount();

  // Use projectCount here (e.g., update state or log)
  print('Project count: $projectCount');

  // If you need to store it in a variable, declare it outside this method
  setState(() {
    _projectCount = projectCount;
  });
}
Future<int> countUnresolvedReports() async {
  try {
    // Query for reports where 'resolved' is false
    final querySnapshotFalse = await FirebaseFirestore.instance
        .collection('reports')
        .where('resolved', isEqualTo: false)
        .get();

    // Query for reports where 'resolved' is null
    final querySnapshotNull = await FirebaseFirestore.instance
        .collection('reports')
        .where('resolved', isNull: true)
        .get();

    // Query for reports where 'resolved' field does not exist
    // Firestore doesn't support querying missing fields directly, 
    // but we can filter them in client-side code after fetching all reports
    final querySnapshotAllReports = await FirebaseFirestore.instance
        .collection('reports')
        .get();

    // Count reports with 'resolved' missing
    int missingResolvedCount = querySnapshotAllReports.docs.where((doc) =>
        !doc.data().containsKey('resolved')).length;

    // Combine the counts from all three queries
    return querySnapshotFalse.docs.length + 
           querySnapshotNull.docs.length + 
           missingResolvedCount;
  } catch (e) {
    print('Error counting unresolved reports: $e');
    return 0;
  }
}

Future<int> countPendingUsers() async {
  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus', isEqualTo: 'pending')
        .get();
    return querySnapshot.docs.length;
  } catch (e) {
    print('Error counting pending users: $e');
    return 0;
  }
}


@override
void initState() {
  super.initState();
  fetchProjectCount();
  
}

Widget _buildreportsCard(
    BuildContext context, String title, int count) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: Container(
      width: 300,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        border: Border.all(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Text(
          "$title: $count",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(24, 71, 137, 1),
          ),
        ),
      ),
    ),
  );
}

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
                        color: Color.fromRGBO(
                            24, 71, 137, 1), // Customize the color
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon:
                          Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                      onPressed: () {
                        setState(() {
                          isSidebarVisible = !isSidebarVisible;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: Center(
                      // Ensures the grid is centered
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 120,
                            vertical:
                                20), // Added horizontal padding for white space
                        child:GridView(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(), // Prevents scrolling inside if used within a scrollable widget
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 1, // One card per row
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    mainAxisExtent: 150,
  ),
  children: [
    // Total Projects Card
    _buildDashboardCard(
      context, 
      "Total Projects $_projectCount", 
      Icons.business, 
      Color.fromRGBO(
                            24, 71, 137, 1), 
      () {},
    ),

    // Total Pending Users
    FutureBuilder<int>(
      future: countPendingUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDashboardCard(
            context, 
            "Total New Charity Requests", 
            Icons.assignment_turned_in,
            Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        } else if (snapshot.hasError) {
          return _buildDashboardCard(
            context, 
            "Error Loading Requests", 
            Icons.error_outline, 
            Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        } else {
          final count = snapshot.data ?? 0;
          return _buildDashboardCard(
            context,
            "Total New Charity Requests ($count)",
            Icons.assignment_turned_in,
            Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        }
      },
    ),

    // Total Unresolved Reports
    FutureBuilder<int>(
      future: countUnresolvedReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDashboardCard(
            context, 
            "Total Unresolved Complaints", 
            Icons.report_problem, 
             Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        } else if (snapshot.hasError) {
          return _buildDashboardCard(
            context, 
            "Error Loading Complaints", 
            Icons.error, 
            Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        } else {
          final count = snapshot.data ?? 0;
          return _buildDashboardCard(
            context,
            "Total Unresolved Complaints ($count)",
            Icons.report_problem,
            Color.fromRGBO(
                            24, 71, 137, 1), 
            () {},
          );
        }
      },
    ),
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
Widget _buildDashboardCard(
  BuildContext context,
  String title,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150, // Adjust width to fit content better
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1), // Light background color
          border: Border.all(
            color: color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10), // Rounded corners for a modern look
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40, // Icon size
              color: color, // Icon color
            ),
            SizedBox(height: 10), // Space between icon and title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color, // Text color matches card's theme
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSidebarItem(
      BuildContext context, String title, VoidCallback onTap,
      {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
    return ListTile(
      title: Center(
        // Center the text
        child: Text(
          title,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }
// admin@gmail.com

 
  Widget _buildrequestsCard(
  BuildContext context,
  String title,
  Future<int> countFuture,
  VoidCallback onTap,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10.0),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          border: Border.all(
            color: Color.fromRGBO(24, 71, 137, 1),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: FutureBuilder<int>(
          future: countFuture,
          builder: (context, snapshot) {
            String subtitle = '';

            // Check the connection state and display accordingly
            if (snapshot.connectionState == ConnectionState.waiting) {
              subtitle = 'Loading...';
            } else if (snapshot.hasError) {
              subtitle = 'Error';
            } else if (snapshot.hasData) {
              subtitle = snapshot.data != null ? '${snapshot.data}' : '0';
            } else {
              subtitle = 'No Data';
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color:  Color.fromRGBO(24, 71, 137, 1),
                  ),
                ),
              ],
            );
          },
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
            side: BorderSide(
                color: borderColor, width: 2), // Set border thickness here
            padding: EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(
            title,
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
