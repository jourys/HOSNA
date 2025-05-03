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
final TextEditingController _titleController = TextEditingController();
String? _titleError;
String? _termError;
bool get isInputValid {
  final title = _titleController.text.trimLeft();
  final term = _termsController.text.trimLeft();

  // Title and term must be longer than 10 characters and not start with whitespace
  return title.isNotEmpty &&
        
         term.isNotEmpty &&
         term.length > 10 &&
         (_termError == null || _termError!.isEmpty); // Safe null check
}

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
Future<void> _addTerm(String title, String newText) async {
  bool confirmAdd = await _showAddConfirmationDialog(context);
  if (confirmAdd) {
    await _firestore.collection('terms_conditions').add({
      'title': title.trimLeft(),
      'text': newText.trimLeft(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Clear the controllers after successful addition
    _titleController.clear();
    _termsController.clear();

    showAddSuccessPopup(context);
    print("✅ Term successfully added!");
  } else {
    print("❌ Term addition canceled.");
  }
}

 /// Function to update a term
Future<bool> _updateTerm(String docId, String newTitle, String newText) async {
  // Show the confirmation dialog
  bool confirmSave = await _showSaveEditConfirmationDialog(context);
  
  // If the user confirms, update the term
  if (confirmSave) {
    // Perform the actual update here
    await _firestore.collection('terms_conditions').doc(docId).update({
      'title': newTitle,
      'text': newText,
    });

    return true; // Indicating the update was successful
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
void _showEditDialog(String docId, String currentTitle, String currentText) {
  TextEditingController titleController = TextEditingController(text: currentTitle);
  TextEditingController editController = TextEditingController(text: currentText);

  String? titleError;
  String? textError;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 400,
          height: 470,
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
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: titleController,
                maxLength: 22,
                decoration: InputDecoration(
                  labelText: "Edit Title",
                  labelStyle: TextStyle(color: Color.fromRGBO(24, 71, 137, 1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                  errorText: titleError,
                  counterText: "${titleController.text.trim().length}/22",
                ),
                onChanged: (text) {
                  setState(() {
                    final trimmed = text.trim();
                    titleError = trimmed.isEmpty
                        ? "Title cannot be empty or whitespace"
                        : (trimmed.length > 22
                            ? "Title must not exceed 22 characters"
                            : null);
                  });
                },
              ),
              SizedBox(height: 5),
              TextField(
                controller: editController,
                maxLines: 2,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: "Edit Term or Condition",
                  labelStyle: TextStyle(color: Color.fromRGBO(24, 71, 137, 1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey, width: 1),
                  ),
                  errorText: textError,
                  counterText: "${editController.text.trim().length}/300",
                ),
                onChanged: (text) {
                  setState(() {
                    final trimmed = text.trim();
                    textError = trimmed.isEmpty
                        ? "Text cannot be empty or whitespace"
                        : (trimmed.length < 10 || trimmed.length > 300
                            ? "Text must be between 10 and 300 characters"
                            : null);
                  });
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: (titleError == null &&
                            textError == null &&
                            titleController.text.trim().isNotEmpty &&
                            editController.text.trim().isNotEmpty)
                        ? () async {
                            bool success = await _updateTerm(
                              docId,
                              titleController.text.trim(),
                              editController.text.trim(),
                            );
                            if (success) {
                              Navigator.pop(context);
                              showUpdateSuccessPopup(context);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text("Save", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
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

            TextField(
  controller: _titleController,
  maxLength: 22,
  decoration: InputDecoration(
    labelText: "Title",
    labelStyle: TextStyle(color: Color.fromRGBO(24, 71, 137, 1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey, width: 1),
    ),
    errorText: _titleError,
    hintText: "Enter a short title (max 22 chars)",
  ),
  onChanged: (text) {
    setState(() {
      if (text.trimLeft().isEmpty) {
        _titleError = "Title cannot be empty or start with space";
      } else if (text.trimLeft().length > 22) {
        _titleError = "Max 22 characters allowed";
      } else {
        _titleError = null;
      }
    });
  },
),
SizedBox(height: 10),
TextField(
  controller: _termsController,
  maxLines: 2,
  maxLength: 300, // Limit to 300 characters
  decoration: InputDecoration(
    labelText: "Add Term or Condition",
    labelStyle: TextStyle(color: Color.fromRGBO(24, 71, 137, 1)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey, width: 1),
    ),
    errorText: _termError,
    hintText: "Enter a term or condition...",
    counterText:
        "${_termsController.text.trim().length}/300", // Live counter
  ),
  onChanged: (text) {
    setState(() {
      String trimmed = text.trimLeft();
      int length = text.trim().length;

      if (trimmed.isEmpty) {
        _termError = "Term cannot be empty or only whitespace";
      } else if (length < 10) {
        _termError = "Term must be at least 10 characters";
      } else if (length > 300) {
        _termError = "Term cannot exceed 300 characters";
      } else {
        _termError = null;
      }
    });
  },
),

            SizedBox(height: 10),

        SizedBox(height: 10),

ElevatedButton(
  onPressed: isInputValid
      ? () async {
          final title = _titleController.text.trimLeft();
          final term = _termsController.text.trimLeft();

          // Example call with both title and term
          await _addTerm(title, term);

          // Clear the text controllers after adding
          _titleController.clear();
          _termsController.clear();

          setState(() {}); // Refresh validation state
        }
      : null,
  child: Text(
    "Add",
    style: TextStyle(color: Colors.white, fontSize: 16),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
    padding: EdgeInsets.symmetric(horizontal: 55, vertical: 20),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
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
      Expanded( 
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
    String title = termData['title'] ?? "";
    String termText = termData['text'] ?? "";
    String docId = terms[index].id;

    return Card(
      color: Colors.grey[200],
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: ListTile(
        contentPadding: EdgeInsets.all(16.0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(24, 71, 137, 1),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              termText,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Color.fromRGBO(24, 71, 137, 1)),
              onPressed: () => _showEditDialog(docId, title, termText), // Pass both
            ),
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

