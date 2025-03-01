import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostProject extends StatefulWidget {
  final String? walletAddress;
  const PostProject({super.key, this.walletAddress});
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

  Future<Map<String, String?>> getCharityCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'walletAddress': prefs.getString('walletAddress'),
      'privateKey': prefs.getString('privateKey'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post Project'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                label: 'Project Name:',
                controller: _projectNameController,
                hintText: 'Enter project name',
              ),
              _buildTextField(
                label: 'Project Description:',
                controller: _descriptionController,
                hintText: 'Enter project description',
              ),
              _buildDatePickerField(
                label: 'Project Start Date:',
                controller: _startDateController,
                onTap: () => _selectDate(context, true),
              ),
              _buildDatePickerField(
                label: 'Project Funding Deadline:',
                controller: _deadlineController,
                onTap: () => _selectDate(context, false),
              ),
              _buildTotalAmountField(),
              Text('Project Type:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              DropdownButtonFormField<String>(
                value: _selectedProjectType,
                hint: Text('Select project type'),
                items: projectTypes
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (newValue) =>
                    setState(() => _selectedProjectType = newValue),
                validator: (value) =>
                    value == null ? 'Please select a project type' : null,
                decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 12, horizontal: 10)),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _saveProject();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Color.fromRGBO(24, 71, 137, 1)),
                      child: Text('Save'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _postProject();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                          foregroundColor: Colors.white),
                      child: Text('Post'),
                    ),
                  ),
                  SizedBox(width: 10),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required String label,
      required TextEditingController controller,
      String? hintText,
      bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        decoration: InputDecoration(
            labelText: label, hintText: hintText, border: OutlineInputBorder()),
        validator: (value) => value!.isEmpty ? 'This field is required' : null,
      ),
    );
  }

 Widget _buildTotalAmountField() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextFormField(
      controller: _totalAmountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Allows decimals
      ],
      decoration: const InputDecoration(
        labelText: 'Project Total Amount',
        hintText: 'Enter total amount',
        suffixText: 'ETH', // Optional: Indicate currency
        border: OutlineInputBorder(),
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
}

  Widget _buildDatePickerField(
      {required String label,
      required TextEditingController controller,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(Icons.calendar_today),
            border: OutlineInputBorder()),
        onTap: onTap,
        validator: (value) =>
            value == null || value.isEmpty ? 'Please select a date' : null,
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (picked != null) {
      setState(() {
        (isStartDate ? _startDateController : _deadlineController).text =
            picked.toString().split(' ')[0];
      });
    }
  }

  void _saveProject() {
    print("Project Saved: ${_projectNameController.text}");
  }

 void _postProject() async {
  if (_formKey.currentState!.validate()) {
    print("✅ Form validation passed, proceeding to post project...");
    final blockchainService = BlockchainService();

    try {
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

      print("✅ Project successfully posted!");

      // Navigate to project details page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProjectDetails(
            projectName: _projectNameController.text,
            description: _descriptionController.text,
            startDate: _startDateController.text,
            deadline: _deadlineController.text,
            totalAmount: _totalAmountController.text,
            projectType: _selectedProjectType ?? 'Other',
            projectCreatorWallet: walletAddress.toString(),
          ),
        ),
      );
    } catch (e) {
      print("❌ Error posting project: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post project. Error: $e')),
      );
    }
  } else {
    print("❌ Form validation failed!");
  }
}

}
