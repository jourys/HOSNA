import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/DraftsPage.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostProject extends StatefulWidget {
  final String? walletAddress;
  final Map<String, dynamic>? draft;
  const PostProject({super.key, this.walletAddress, this.draft});
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
      _startDateController.text = widget.draft!['startDate'];
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
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red, size: 40),
                      onPressed: () {
                        _showDeleteConfirmationDialog(context);
                      },
                    ),
                  ),
                  FocusableTextField(
                    label: 'Project Name:',
                    controller: _projectNameController,
                    hintText: 'Enter project name',
                  ),
                  FocusableTextField(
                    label: 'Project Description:',
                    controller: _descriptionController,
                    hintText: 'Enter project description',
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
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                _postProject();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity,
                                  50), // Make button bigger (height)
                            ),
                            child: Text(
                              'Post',
                              style: TextStyle(
                                fontSize: 20, // Increase text size
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                          height:
                              100), // Increased white space below the buttons
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
    DateTime firstSelectableDate = DateTime(today.year, today.month,
        today.day); // Ensures past dates aren't selectable

    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: firstSelectableDate,
      firstDate: firstSelectableDate, // Prevent selecting past dates
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color.fromRGBO(
                  24, 71, 137, 1), // Header background & selected date
              onPrimary: Colors.white, // Text color on primary color
              onSurface: Color.fromRGBO(24, 71, 137, 1), // Default text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor:
                    Color.fromRGBO(24, 71, 137, 1), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Set the date value in the appropriate controller
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
    final walletAddress =
        widget.walletAddress; // Use the wallet address from the widget

    if (walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in. Cannot save draft.')),
      );
      return;
    }

    // Save project details as a draft
    final draft = {
      'name': _projectNameController.text,
      'description': _descriptionController.text,
      'startDate': _startDateController.text,
      'deadline': _deadlineController.text,
      'totalAmount': _totalAmountController.text,
      'projectType': _selectedProjectType ?? 'Other',
    };

    // Retrieve existing drafts for this user
    final userDraftsKey = 'drafts_$walletAddress'; // Unique key per user
    final drafts = prefs.getStringList(userDraftsKey) ?? [];
    drafts.add(jsonEncode(draft)); // Convert draft to JSON and save

    // Save updated drafts list for this user
    await prefs.setStringList(userDraftsKey, drafts);

    print("✅ Draft saved: ${_projectNameController.text}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft saved successfully!')),
    );
  }

  void _postProject() async {
    if (_formKey.currentState!.validate()) {
      print("✅ Form validation passed, proceeding to post project...");
      final blockchainService = BlockchainService();

      // Parsing start date and deadline
      int startDate, deadline;
      try {
        startDate =
            DateTime.parse(_startDateController.text).millisecondsSinceEpoch ~/
                1000;
        deadline =
            DateTime.parse(_deadlineController.text).millisecondsSinceEpoch ~/
                1000;
      } catch (e) {
        print("❌ Error parsing dates: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid date format. Please check your input.')),
        );
        return;
      }

      // Parsing total amount
      double? totalAmount = double.tryParse(_totalAmountController.text);
      if (totalAmount == null) {
        print("❌ Invalid total amount entered: ${_totalAmountController.text}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid total amount.')),
        );
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

      // Send project to blockchain
      await blockchainService.addProject(
        _projectNameController.text,
        _descriptionController.text,
        startDate,
        deadline,
        totalAmount,
        _selectedProjectType ?? 'Other',
      );

      // Sync to Firestore
      final projectCount = await blockchainService.getProjectCount();
      final projectId = projectCount - 1; // Get the ID of the newly added project
      
      // Get project details from blockchain
      final projectDetails = await blockchainService.getProjectDetails(projectId);
      
      await FirebaseFirestore.instance.collection('projects').doc(projectId.toString()).set({
        'name': projectDetails['name'] ?? _projectNameController.text,
        'description': projectDetails['description'] ?? _descriptionController.text,
        'startDate': projectDetails['startDate'] ?? startDate,
        'endDate': projectDetails['endDate'] ?? deadline,
        'totalAmount': projectDetails['totalAmount'] ?? totalAmount,
        'projectType': projectDetails['projectType'] ?? (_selectedProjectType ?? 'Other'),
        'organization': projectDetails['organization'] ?? walletAddress,
        'status': projectDetails['status'] ?? 'active',
      });

      print("✅ Project successfully posted and synced to Firestore!");

      // Navigate to project details page only after successful posting
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BrowseProjects(
            walletAddress: walletAddress ?? '',
          ), // Replace with your Browse Project page
        ),
      );
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

  FocusableTextField({
    required this.label,
    required this.controller,
    this.hintText,
    this.isNumber = false,
    this.isStartDate = false, // Default to false
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