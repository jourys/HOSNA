import 'package:flutter/material.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminBrowseOrganizations.dart';
import 'package:hosna/AdminScreens/AdminBrowseProjects.dart';
import 'package:hosna/AdminScreens/Terms&cond.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'AdminSidebar.dart'; 
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hosna Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AdminTermsAndConditionsPage(), // Set the Terms and Conditions page as the home screen
    );
  }
}

class AdminTermsAndConditionsPage extends StatefulWidget {
  @override
  _AdminTermsAndConditionsPageState createState() => _AdminTermsAndConditionsPageState();
}

class _AdminTermsAndConditionsPageState extends State<AdminTermsAndConditionsPage> {
  bool isSidebarVisible = true;
final TextEditingController _termsController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

 
@override
void initState() {
  super.initState();
  _termsController.addListener(() {
    setState(() {}); // Update the UI when the text changes
  });
   _fetchTermsAndConditions(); // Load existing terms from Firestore
}

  void _fetchTermsAndConditions() async {
    DocumentSnapshot snapshot = await _firestore.collection('admin').doc('terms').get();
   
  }
/// Function to add a new term
 Future<void> _addTerm(String newText) async {
  bool confirmAdd = await _showAddConfirmationDialog(context);
  if (confirmAdd) {
    await _firestore.collection('terms_conditions').add({
      'text': newText,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // After successful addition of a term


     _termsController.clear();
      showAddSuccessPopup(context);
    print("✅ Term successfully added!");
  } else {
    print("❌ Term addition canceled.");
  }
   
  }

  /// Function to update a term
Future<bool> _updateTerm(String docId, String newText) async {
  // Show the confirmation dialog
  bool confirmSave = await _showSaveEditConfirmationDialog(context);
  
  // If the user confirms, update the term
  if (confirmSave) {
    // Perform the actual update here
    await _firestore.collection('terms_conditions').doc(docId).update({
      'text': newText,
    });

    return true; 

// Indicating the update was successful
  } else {
    return false; // Indicating the update was canceled
  }
}




  /// Function to delete a term
Future<bool> _deleteTerm(String docId) async {
  bool confirmDelete = await _showDeleteConfirmationDialog(context);
  if (confirmDelete) {
    await _firestore.collection('terms_conditions').doc(docId).delete();
    return true; 
    // Indicating the deletion was successful
  } else {
    return false; // Indicating the deletion was canceled
  }
}

void showAddSuccessPopup(BuildContext context) {
  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Term/Condition added successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  );
}
void showDeleteSuccessPopup(BuildContext context) {
  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Term/Condition deleted successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  );
}
void showUpdateSuccessPopup(BuildContext context) {
  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Term/Condition  updated successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  );
}

 /// Show edit dialog
  void _showEditDialog(String docId, String currentText) {
  TextEditingController editController = TextEditingController(text: currentText);
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // Increased border radius
      ),
      child: Container(
        width: 400, // Fixed width
        height: 300, // Fixed height
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Edit Terms or Conditions",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(24, 71, 137, 1), // Title color
              ),
            ),
            SizedBox(height: 60),
            TextField(
              controller: editController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Edit Term or Condition",
                labelStyle: TextStyle(color: Color.fromRGBO(24, 71, 137, 1)), // Label color
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // Increased border radius
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // Increased border radius for focus
                  borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2), // Color when focused
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), // Increased border radius for non-focus
                  borderSide: BorderSide(color: Colors.grey, width: 1), // Color when not focused
                ),
              ),
            ),
            SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15), // Bigger button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
                SizedBox(width: 20),
               ValueListenableBuilder<TextEditingValue>(
  valueListenable: editController,
  builder: (context, value, child) {
    return ElevatedButton(
      onPressed: value.text.trim().isEmpty
          ? null // Disable button if the text is empty
          : () async {
              bool success = await _updateTerm(docId, value.text.trim());
              if (success) {
                Navigator.pop(context);
                showUpdateSuccessPopup(context);
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text("Save", style: TextStyle(color: Colors.white, fontSize: 16)),
    );
  },
),

              ],
            ),
          ],
        ),
      ),
    ),
  );
}
Future<bool> _showSaveEditConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white, // Set background to white
        title: const Text(
          'Confirm Changes',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make title bold
            fontSize: 22, // Increase title font size
          ),
          textAlign: TextAlign.center, // Center the title text
        ),
        content: const Text(
          'Are you sure you want to save these changes?',
          style: TextStyle(
            fontSize: 18, // Make content text bigger
          ),
          textAlign: TextAlign.center, // Center the content text
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, false); // Return false on cancel
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.grey, // Border color for Cancel button
                    width: 3,
                  ),
                  backgroundColor: Colors.grey, // Background color
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color
                  ),
                ),
              ),
              const SizedBox(width: 20), // Add space between buttons
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Return true after confirming save
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(24, 71, 137, 1), // Border color for Save button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background color
                ),
                child: const Text(
                  '   Save   ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size
                    color: Colors.white, // White text color
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(vertical: 10), // Add padding for the actions
      );
    },
  ) ?? false; // If null, default to false
}


Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white, // Set background to white
        title: const Text(
          'Confirm Deletion',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make title bold
            fontSize: 22, // Increase title font size
          ),
          textAlign: TextAlign.center, // Center the title text
        ),
        content: const Text(
          'Are you sure you want to delete this Term/Condition ?',
          style: TextStyle(
            fontSize: 18, // Make content text bigger
          ),
          textAlign: TextAlign.center, // Center the content text
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, false); // Return false on cancel
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(24, 71, 137, 1), // Border color for Cancel button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background color
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color
                  ),
                ),
              ),
              const SizedBox(width: 20), // Add space between buttons
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                  // After successful deletion of a term
showDeleteSuccessPopup(context);
 // Return true after confirming deletion
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(212, 63, 63, 1), // Border color for Yes button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(212, 63, 63, 1), // Background color
                ),
                child: const Text(
                  '   Yes   ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size
                    color: Colors.white, // White text color
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(vertical: 10), // Add padding for the actions
      );
    },
  ) ?? false; // If null, default to false
}
Future<bool> _showAddConfirmationDialog(BuildContext context) async {
  print("🚀 Showing add confirmation dialog...");

  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
    builder: (BuildContext context) {
      print("🔧 Building the add confirmation dialog...");

      return AlertDialog(
        backgroundColor: Colors.white, // Set background to white
        title: const Text(
          'Confirm Addition',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make title bold
            fontSize: 22, // Increase title font size
          ),
          textAlign: TextAlign.center, // Center the title text
        ),
        content: const Text(
          'Are you sure you want to add this Term/Condition ?',
          style: TextStyle(
            fontSize: 18, // Make content text bigger
          ),
          textAlign: TextAlign.center, // Center the content text
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              OutlinedButton(
                onPressed: () {
                  print("❌ Cancel clicked - Addition not confirmed.");
                  Navigator.pop(context, false); // Return false on cancel
                },
               style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 10), // Bigger button
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                   color: Colors.white,// White text color for Cancel button
                  ),
                ),
              ),
              const SizedBox(width: 20), // Add space between the buttons
              OutlinedButton(
                onPressed: () {
                  print("✅ Yes clicked - Addition confirmed.");
                  Navigator.pop(context, true); // Return true after confirming addition
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(24, 71, 137, 1), // Border color for Cancel button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background color for Cancel button
                ),
                child: const Text(
                  '   Add   ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(vertical: 10), // Add padding for actions
      );
    },
  ) ?? false; // If null, default to false
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
                    'Terms & Conditions', // Page title
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
                  child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Input Field
          TextField(
  controller: _termsController,
  maxLines: 2,
  decoration: InputDecoration(
    labelText: "Add Term or Condition", // Label for the field
    labelStyle: TextStyle(
      color: Color.fromRGBO(24, 71, 137, 1), // Label color
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), // Increased border radius
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), // Increased border radius for focus
      borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2), // Color when focused
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), // Increased border radius for non-focus
      borderSide: BorderSide(color: Colors.grey, width: 1), // Color when not focused
    ),
    hintText: "Enter a term or condition...",
  ),
  onChanged: (text) {
    // Disable whitespace-only input
    if (text.trim().isEmpty) {
      _termsController.clear(); // Clear the text if it's only whitespace
    }
  },
),



            SizedBox(height: 10),

            // Add Button
          ElevatedButton(
  onPressed: _termsController.text.trim().isEmpty
      ? null
      : () async {
          await _addTerm(_termsController.text.trim());
        },
  child: Text(
    "Add",
    style: TextStyle(
      color: Colors.white, // White text color
      fontSize: 16,
    ),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
    padding: EdgeInsets.symmetric(horizontal: 55, vertical: 20), // Bigger button
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6), // Decreased border radius
    ),
  ),
),
            SizedBox(height: 20),

            // Terms List
            Expanded(
  child: Column(
    children: [
      // Label for All Terms and Conditions
      Padding(
  padding: EdgeInsets.all(16.0),
  child: Align(
    alignment: Alignment.centerLeft, // Align the text to the right
    child: Text(
      "All Terms and Conditions",
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Color.fromRGBO(24, 71, 137, 1), // Label color
      ),
    ),
  ),
),


      // StreamBuilder for displaying terms and conditions
      Expanded( // Ensuring ListView gets proper constraints
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('terms_conditions').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text("Error loading terms."));
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

            final terms = snapshot.data!.docs;

            return ListView.builder(
              itemCount: terms.length,
              itemBuilder: (context, index) {
                var termData = terms[index].data() as Map<String, dynamic>;
                String termText = termData['text'] ?? "";
                String docId = terms[index].id;

                return Card(
                  color: Colors.grey[200], // White background for the card
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2), // Border color and width
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                  ),
                  margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16), // Card margin
                  child: ListTile(
                    contentPadding: EdgeInsets.all(16.0), // Padding inside the card
                    title: Text(
                      termText,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color.fromRGBO(24, 71, 137, 1),
                        fontWeight: FontWeight.bold, // Text color
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button with updated color
                        IconButton(
                          icon: Icon(Icons.edit, color: Color.fromRGBO(24, 71, 137, 1)),
                          onPressed: () => _showEditDialog(docId, termText),
                        ),
                        // Delete button
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteTerm(docId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  ),
),
          ],
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

  Widget _buildSidebarItem(BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      title: Center(child: Text(title, style: TextStyle(color: Color.fromRGBO(24, 71, 137, 1), fontSize: 18, fontWeight: FontWeight.bold))),
      onTap: onTap,
    );
  }
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

