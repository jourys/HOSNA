import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:hosna/screens/BrowseProjects.dart';

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
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
            labelText: 'Project Total Amount',
            hintText: 'Enter total amount',
            suffixText: 'SR',
            border: OutlineInputBorder()),
        validator: (value) =>
            value!.isEmpty ? 'Please enter the total amount' : null,
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
      final blockchainService = BlockchainService();

      try {
        await blockchainService.addProject(
          _projectNameController.text,
          _descriptionController.text,
          DateTime.parse(_startDateController.text).millisecondsSinceEpoch ~/
              1000,
          DateTime.parse(_deadlineController.text).millisecondsSinceEpoch ~/
              1000,
          int.parse(_totalAmountController.text),
          _selectedProjectType ?? 'Other',
        );

        // Navigate to the project details page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => projectDetails(
              projectName: _projectNameController.text,
              description: _descriptionController.text,
              startDate: _startDateController.text,
              deadline: _deadlineController.text,
              totalAmount: _totalAmountController.text,
              projectType: _selectedProjectType ?? 'Other',
            ),
          ),
        );
      } catch (e) {
        print("❌ Error posting project: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post project: $e')),
        );
      }
    }
  }
}
