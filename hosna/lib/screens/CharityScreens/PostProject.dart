import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/NotificationListener.dart';
import 'package:hosna/screens/NotificationManager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/DraftsPage.dart';
import 'dart:convert';

import 'package:web3dart/web3dart.dart';

class PostProject extends StatefulWidget {
  final String? walletAddress;
  final Map<String, dynamic>? draft;
  final bool showDeleteIcon; // New parameter

  const PostProject({
    super.key,
    this.walletAddress,
    this.draft,
    this.showDeleteIcon = true, // Default to true
  });

  // const PostProject({super.key, this.walletAddress, this.draft});
  @override
  _PostProjectScreenState createState() => _PostProjectScreenState();
}

class _PostProjectScreenState extends State<PostProject> {
  String? walletAddress;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();
  FocusNode _focusNode = FocusNode(); // Define a FocusNode

  String? _selectedProjectType;
  List<String> projectTypes = [
    'Education',
    'Health',
    'Environment',
    'Food',
    'Religious',
    'Disaster Relief',
    'Other'
  ];
  @override
  void initState() {
    super.initState();
    // Set the current date as the start date
    _startDateController.text =
        DateTime.now().toLocal().toString().split(' ')[0];
    _focusNode.addListener(() {
      setState(() {}); // Rebuild when the focus state changes
    });

    // Pre-fill form fields if a draft is provided
    if (widget.draft != null) {
      _projectNameController.text = widget.draft!['name'];
      _descriptionController.text = widget.draft!['description'];
     _startDateController.text =
          DateTime.now().toLocal().toString().split(' ')[0];
      _deadlineController.text = widget.draft!['deadline'];
      _totalAmountController.text = widget.draft!['totalAmount'];
      _selectedProjectType = widget.draft!['projectType'];
    }
  }

  @override
  void dispose() {
    _focusNode.dispose(); // Don't forget to dispose of the FocusNode
    super.dispose();
  }

  Future<Map<String, String?>> getCharityCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'walletAddress': prefs.getString('walletAddress'),
      'privateKey': prefs.getString('privateKey'),
    };
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1), // AppBar color
      appBar: AppBar(
        toolbarHeight:
            70, // Increase the height of the AppBar to move elements down
        title: Padding(
          padding: EdgeInsets.only(bottom: 1), // Move the title slightly down
          child: Text(
            "Post Project", // Display the organization name
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold, // Make text bold
              fontSize: 25, // Increase font size
            ),
          ),
        ),
        centerTitle: true, // Center the title
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        elevation: 0, // Remove shadow for a smooth transition
        iconTheme: IconThemeData(
          color: Colors.white, // Set back arrow color to white
          size: 30, // Increase icon size
        ),
        leading: Padding(
          padding: EdgeInsets.only(
              left: 10, bottom: 1), // Move the arrow slightly down
          child: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.drafts),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DraftsPage(
                    walletAddress:
                        widget.walletAddress, // Pass the wallet address
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        child: Container(
          color: Colors.white, // Background color of the body
          padding: EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // widget.showDeleteIcon
                  //     ? Align(
                  //         alignment: Alignment.topRight,
                  //         child: IconButton(
                  //           icon:
                  //               Icon(Icons.delete, color: Colors.red, size: 40),
                  //           onPressed: () {
                  //             _showDeleteConfirmationDialog(context);
                  //           },
                  //         ),
                  //       )
                  //     : SizedBox.shrink(),
                                    SizedBox(height: 45),

                  FocusableTextField(
                    label: 'Project Name:',
                    controller: _projectNameController,
                    hintText: 'Enter project name',
                  ),
                  FocusableTextField(
                    label: 'Project Description:',
                    controller: _descriptionController,
                    hintText: 'Enter project description',
                     isDescription: true,
                  ),
                  _buildDatePickerField(
                    label: 'Project Start Date:',
                    controller: _startDateController,
                    onTap: () => _selectDate(context, true),
                    enabled:
                        false, // Disables editing the field, since you are selecting a date from the date picker
                    isStartDate:
                        true, // Indicate that this is the start date field to apply the specific border color
                  ),
                  _buildDatePickerField(
                    label: 'Project Funding Deadline:',
                    controller: _deadlineController,
                    onTap: () => _selectDate(context, false),
                    enabled: true,
                    isStartDate:
                        false, // This is not the start date, so no special border color
                  ),
                  _buildTotalAmountField(),
                  SizedBox(height: 10),
                  Container(
                    height: 80, // Set an explicit height
                    child: SizedBox(
                      width: 390, // Set a fixed width
                      child: DropdownButtonFormField<String>(
                        focusNode: _focusNode, // Attach the FocusNode
                        value: _selectedProjectType,
                        hint: const Text(
                          'Select project type',
                          style: TextStyle(
                              color: Colors.grey), // Apply gray color correctly
                        ),
                        items: projectTypes
                            .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 12), // Increase padding
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      type,
                                      style: TextStyle(
                                        fontSize:
                                            18, // Increase font size for the option
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (newValue) =>
                            setState(() => _selectedProjectType = newValue),
                        validator: (value) => value == null
                            ? 'Please select a project type'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Project Type',
                          labelStyle: TextStyle(
                            color: _selectedProjectType != null
                                ? Color.fromRGBO(24, 71, 137,
                                    1) // Keep label color when selected
                                : (_focusNode.hasFocus
                                    ? Color.fromRGBO(
                                        24, 71, 137, 1) // Focused color
                                    : Colors.grey), // Unfocused color
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _selectedProjectType != null
                                  ? Color.fromRGBO(24, 71, 137,
                                      1) // Keep border color when selected
                                  : Colors.grey, // Default border color
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _selectedProjectType != null
                                  ? Color.fromRGBO(24, 71, 137,
                                      1) // Keep border color when selected
                                  : Colors.grey, // Border color on focus
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _selectedProjectType != null
                                  ? Color.fromRGBO(24, 71, 137,
                                      1) // Keep border color when selected
                                  : Colors
                                      .grey, // Border color when not focused
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 30), // Padding inside the field
                        ),
                        iconEnabledColor: Color.fromRGBO(
                            24, 71, 137, 1), // Dropdown icon color
                        iconSize: 24, // Set a fixed icon size
                        dropdownColor: Color.fromRGBO(
                            220, 223, 226, 1), // Dropdown background color
                        style: TextStyle(
                          color: Color.fromRGBO(24, 71, 137,
                              1), // Set the selected item text color
                          fontSize:
                              16, // Set a fixed text size for the selected item
                        ),
                        isExpanded:
                            true, // Ensure the dropdown takes the full width of the container
                        selectedItemBuilder: (BuildContext context) {
                          return projectTypes
                              .map((type) => Text(
                                    type,
                                    style: TextStyle(
                                      fontSize:
                                          18, // Increase font size for selected item
                                      color: Color.fromRGBO(24, 71, 137,
                                          1), // Selected item text color
                                    ),
                                  ))
                              .toList();
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Column(
                    mainAxisAlignment: MainAxisAlignment
                        .center, // Center the buttons vertically
                    children: [
                      Center(
                        // Center the entire Column horizontally
                        child: SizedBox(
                          width: 355, // Make button take the full width
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _saveProject();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[300],
                              foregroundColor: Color.fromRGBO(24, 71, 137, 1),
                              side: BorderSide(
                                color: Color.fromRGBO(
                                    24, 71, 137, 1), // Add border color
                                width: 2, // Border width
                              ),
                              minimumSize: Size(double.infinity,
                                  50), // Make button bigger (height)
                            ),
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 20, // Increase text size
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 25), // Add some space between buttons
                      Center(
                        // Center the button horizontally
                        child: SizedBox(
                          width: 355, // Make button take the full width
                          child: ElevatedButton(
  onPressed: _isLoading
      ? null // Disable button while loading
      : () {
          if (_formKey.currentState!.validate()) {
            _postProject();
          }
        },
  style: ElevatedButton.styleFrom(
    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 50),
  ),
  child: _isLoading
      ? SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
          ),
        )
      : Text(
          'Post',
          style: TextStyle(
            fontSize: 20,
          ),
        ),
),

                        ),
                      ),
                      SizedBox(
                          height:
                              120), // Increased white space below the buttons
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
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
                'Are you sure you want to clear all form fields?',
                style: TextStyle(
                  fontSize: 18, // Make content text bigger
                ),
                textAlign: TextAlign.center, // Center the content text
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the buttons
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        print("Cancel clicked - Form not cleared.");
                        Navigator.pop(context, false); // Return false on cancel
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              24, 71, 137, 1), // Border color for Cancel button
                          width: 3,
                        ),
                        backgroundColor: Color.fromRGBO(24, 71, 137,
                            1), // Background color for Cancel button
                        // Text color (white) for the Cancel button
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color: Colors
                              .white, // White text color for Cancel button
                        ),
                      ),
                    ),
                    const SizedBox(width: 20), // Add space between the buttons
                    OutlinedButton(
                      onPressed: () {
                        print("Yes clicked - Clearing form...");
                        _clearForm(); // Clear the form
                        print("Form cleared successfully.");
                        Navigator.pop(
                            context, true); // Return true after clearing
                        Navigator.pop(
                            context); // Navigate back to the previous page
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Color.fromRGBO(
                              212, 63, 63, 1), // Border color for Yes button
                          width: 3,
                        ),
                        backgroundColor: Color.fromRGBO(
                            212, 63, 63, 1), // Background color for Yes button
                        // Text color (white) for the Yes button
                      ),
                      child: const Text(
                        '   Yes   ',
                        style: TextStyle(
                          fontSize: 20, // Increase font size for buttons
                          color:
                              Colors.white, // White text color for Yes button
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              actionsPadding: const EdgeInsets.symmetric(
                  vertical: 10), // Add padding for the actions
            );
          },
        ) ??
        false; // If null, default to false
  }

  void _clearForm() {
    print("Clearing form fields...");

    // Ensure the state updates properly
    setState(() {
      _projectNameController.clear();
      _descriptionController.clear();
      _totalAmountController.clear();
      _deadlineController.clear();

      _selectedProjectType = null; // Reset dropdown

      print("All fields cleared.");
    });

    // Reset form validation state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formKey.currentState?.reset();
      print("Form validation reset.");
    });

    print("Form cleared successfully.");
  }

  Widget _buildTotalAmountField() {
    FocusNode focusNode = FocusNode();
    bool hasInput = _totalAmountController.text.isNotEmpty;

    return StatefulBuilder(
      builder: (context, setState) {
        focusNode.addListener(() {
          setState(() {});
        });

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: TextFormField(
            controller: _totalAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d*')), // Allows decimals
            ],
            focusNode: focusNode,
            style: TextStyle(
              color:
                  focusNode.hasFocus || _totalAmountController.text.isNotEmpty
                      ? Color.fromRGBO(24, 71, 137,
                          1) // Input text color when focused or has input
                      : Colors.black, // Default input text color
            ),
            decoration: InputDecoration(
              labelText: 'Project Total Amount',
              labelStyle: TextStyle(
                color:
                    _totalAmountController.text.isNotEmpty || focusNode.hasFocus
                        ? Color.fromRGBO(24, 71, 137, 1) // Suffix text color
                        : Colors.grey, // Default suffix text color
              ),
              hintText: 'Enter total amount',

              suffixText: 'ETH', // Optional: Indicate currency
              suffixStyle: TextStyle(
                color:
                    _totalAmountController.text.isNotEmpty || focusNode.hasFocus
                        ? Color.fromRGBO(24, 71, 137, 1) // Suffix text color
                        : Colors.grey, // Default suffix text color
              ),
              // labelStyle: TextStyle(
              //   color: focusNode.hasFocus || hasInput
              //       ? Color.fromRGBO(
              //           24, 71, 137, 1) // Label color on focus or with input
              //       : Colors
              //           .grey, // Default label color when not focused and no input
              // ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: focusNode.hasFocus || hasInput
                      ? Color.fromRGBO(24, 71, 137,
                          1) // Border color when focused or has input
                      : Colors.grey, // Default border color
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: focusNode.hasFocus || hasInput
                      ? Color.fromRGBO(24, 71, 137,
                          1) // Border color when focused or has input
                      : Colors.grey,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: focusNode.hasFocus ||
                          _totalAmountController.text.isNotEmpty
                      ? Color.fromRGBO(24, 71, 137, 1) // Special border color
                      : Colors.grey, // Default border color
                  width: 2,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter the total amount';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
          ),
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    bool enabled = false,
    bool isStartDate = false,
  }) {
    FocusNode focusNode = FocusNode();

    return StatefulBuilder(
      builder: (context, setState) {
        focusNode.addListener(() {
          setState(() {});
        });

        bool hasInput = controller.text.isNotEmpty;
        bool isProjectStartDate = label == 'Project Start Date';

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            focusNode: focusNode,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: Icon(
                Icons.calendar_today,
                color: enabled == true
                    ? (hasInput ? Color.fromRGBO(24, 71, 137, 1) : Colors.grey)
                    : Colors.grey,
              ),
              labelStyle: TextStyle(
                color: enabled == true
                    ? (hasInput
                        ? Color.fromRGBO(24, 71, 137, 1)
                        : (focusNode.hasFocus
                            ? Color.fromRGBO(24, 71, 137, 1)
                            : Colors.grey))
                    : Color.fromRGBO(24, 71, 137, 1),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Color.fromRGBO(
                      24, 71, 137, 1), // Change color when enabled is false
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: enabled == true
                      ? (hasInput
                          ? Color.fromRGBO(24, 71, 137, 1)
                          : (focusNode.hasFocus
                              ? Color.fromRGBO(24, 71, 137, 1)
                              : Colors.grey))
                      : Color.fromRGBO(
                          24, 71, 137, 1), // Change color when enabled is false
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: enabled == true
                      ? (hasInput
                          ? Color.fromRGBO(24, 71, 137, 1)
                          : (isProjectStartDate
                              ? Color.fromRGBO(24, 71, 137, 1)
                              : Colors.grey))
                      : Color.fromRGBO(
                          24, 71, 137, 1), // Change color when enabled is false
                  width: 2,
                ),
              ),
            ),
            onTap: () {
              onTap();
            },
            validator: (value) {
              return value == null || value.isEmpty
                  ? 'Please select a date'
                  : null;
            },
            style: TextStyle(
              color: enabled
                  ? (hasInput ? Color.fromRGBO(24, 71, 137, 1) : Colors.black)
                  : Color.fromRGBO(
                      24, 71, 137, 1), // Change color when enabled is false
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime today = DateTime.now();
    DateTime firstSelectableDate =
        today.add(Duration(days: 1)); // Disable today

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstSelectableDate,
      firstDate: firstSelectableDate, // Prevent selecting today and past dates
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color.fromRGBO(24, 71, 137, 1),
              onPrimary: Colors.white,
              onSurface: Color.fromRGBO(24, 71, 137, 1),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color.fromRGBO(24, 71, 137, 1),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDateController.text = picked.toString().split(' ')[0];
        } else {
          _deadlineController.text = picked.toString().split(' ')[0];
        }
      });
    }
  }

  Future<void> _saveProject() async {
    if (_projectNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please enter a project name to save the draft.')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final walletAddress = widget.walletAddress;

    if (walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in. Cannot save draft.')),
      );
      return;
    }

    // Reuse existing ID if editing, or create a new one
    final draftId = widget.draft != null
        ? widget.draft!['id']
        : DateTime.now().millisecondsSinceEpoch.toString();

    final draft = {
      'id': draftId,
      'name': _projectNameController.text,
      'description': _descriptionController.text,
      'startDate': _startDateController.text,
      'deadline': _deadlineController.text,
      'totalAmount': _totalAmountController.text,
      'projectType': _selectedProjectType ?? 'Other',
    };

    final userDraftsKey = 'drafts_$walletAddress';
    final drafts = prefs.getStringList(userDraftsKey) ?? [];
    List<Map<String, dynamic>> parsedDrafts =
        drafts.map((d) => jsonDecode(d) as Map<String, dynamic>).toList();

    final existingIndex = parsedDrafts.indexWhere((d) => d['id'] == draftId);
    if (existingIndex != -1) {
      parsedDrafts[existingIndex] = draft;
    } else {
      parsedDrafts.add(draft);
    }

    final updatedDrafts = parsedDrafts.map((d) => jsonEncode(d)).toList();
    await prefs.setStringList(userDraftsKey, updatedDrafts);

    print("Draft saved: ${_projectNameController.text}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft saved successfully!')),
    );
  }

 void showSuccessPopup(BuildContext context) {
    // Show dialog
    showDialog(
      context: context,
      barrierDismissible: true, // Allow closing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding:
              EdgeInsets.all(20), // Add padding around the dialog content
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15), // Rounded corners for a better look
          ),
          content: SizedBox(
            width: 250, // Set a custom width for the dialog
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Ensure the column only takes the required space
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color.fromARGB(255, 54, 142, 57),
                  size: 50, // Bigger icon
                ),
                SizedBox(height: 20), // Add spacing between the icon and text
                Text(
                  'Project posted successfully!',
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

    // Automatically dismiss the dialog after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      // Check if the widget is still mounted before performing Navigator.pop
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
      }
      Navigator.pop(context, true);
    });
  }


 bool _isLoading = false; // Add a loading flag

void _postProject() async {
  if (_formKey.currentState!.validate()) {
    print("✅ Form validation passed, proceeding to post project...");
    
    setState(() {
      _isLoading = true; // Start loading when posting project
    });

    final blockchainService = BlockchainService();

    // Parsing start date and deadline
    int startDate, deadline;
    try {
      startDate = DateTime.parse(_startDateController.text).millisecondsSinceEpoch ~/ 1000;
      deadline = DateTime.parse(_deadlineController.text).millisecondsSinceEpoch ~/ 1000;
    } catch (e) {
      print("❌ Error parsing dates: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format. Please check your input.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Parsing total amount
    double? totalAmount = double.tryParse(_totalAmountController.text);
    if (totalAmount == null) {
      print("❌ Invalid total amount entered: ${_totalAmountController.text}");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total amount.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Print values before sending
    print("📌 Project Details:");
    print("   - Name: ${_projectNameController.text}");
    print("   - Description: ${_descriptionController.text}");
    print("   - Start Date: $startDate (Unix timestamp)");
    print("   - Deadline: $deadline (Unix timestamp)");
    print("   - Total Amount: $totalAmount");
    print("   - Type: ${_selectedProjectType ?? 'Other'}");
    print("   - Wallet Address: $walletAddress");

    try {
      // Send project to blockchain
      final txHash = await blockchainService.addProject(
        _projectNameController.text,
        _descriptionController.text,
        startDate,
        deadline,
        totalAmount,
        _selectedProjectType ?? 'Other',
      );

      // ✅ Wait for transaction receipt
final receipt = await blockchainService.waitForReceipt(txHash);

      if (receipt != null && receipt.status == true) {
        print("✅ Project successfully posted!");
        setState(() => _isLoading = false);
        Navigator.pop(context);
        showSuccessPopup(context);
      } else {
        print("❌ Transaction failed!");
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post project. Please try again.')),
        );
      }
    } catch (e) {
      print("❌ Error posting project: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post project. Error: $e')),
      );
    }
  } else {
    print("❌ Form validation failed!");
  }
}


}

class FocusableTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final bool isNumber;
  final bool isStartDate; // Add a parameter to check if it's the start date
 final bool isDescription;


  FocusableTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.isNumber = false,
    this.isStartDate = false, // Default to false
     this.isDescription = false, 
  });

  @override
  _FocusableTextFieldState createState() => _FocusableTextFieldState();
}

class _FocusableTextFieldState extends State<FocusableTextField> {
  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Adding listener to FocusNode to trigger setState when focus changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    // Clean up the FocusNode when the widget is disposed
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: widget.controller,
        keyboardType:
            widget.isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters:
            widget.isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        focusNode: _focusNode, // Attach focus node
maxLines: widget.isDescription ? 3 : 1,
 minLines: 1,
        style: TextStyle(
          color: widget.controller.text.isNotEmpty || _focusNode.hasFocus
              ? Color.fromRGBO(
                  24, 71, 137, 1) // Input text color when focused or has input
              : Colors.black, // Default input text color
        ),

        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          labelStyle: TextStyle(
            color: widget.controller.text.isNotEmpty || _focusNode.hasFocus
                ? Color.fromRGBO(24, 71, 137, 1) // Label color when focused
                : Colors.grey, // Default label color when not focused
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: widget.controller.text.isNotEmpty ||
                      widget.isStartDate ||
                      _focusNode.hasFocus
                  ? Color.fromRGBO(
                      24, 71, 137, 1) // Border color when focused or start date
                  : Colors.grey, // Default border color when not focused
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Color.fromRGBO(24, 71, 137, 1), // Border color on focus
              width: 2,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: widget.controller.text.isNotEmpty || widget.isStartDate
                  ? Color.fromRGBO(
                      24, 71, 137, 1) // Special border color for start date
                  : Colors.grey, // Default border color when not focused
              width: 2,
            ),
          ),
        ),
        validator: (value) => value!.isEmpty ? 'This field is required' : null,
      ),
    );
  }
}

