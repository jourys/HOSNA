import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectDetails extends StatefulWidget {
  final String projectName;
  final String description;
  final String startDate;
  final String deadline;
  final String totalAmount;
  final String projectType;

  const ProjectDetails({
    required this.projectName,
    required this.description,
    required this.startDate,
    required this.deadline,
    required this.totalAmount,
    required this.projectType,
    Key? key,
  }) : super(key: key);

  @override
  _ProjectDetailsState createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  int? userType; // 0 = Donor, 1 = Charity Employee

  @override
  void initState() {
    super.initState();
    _getUserType();
  }

  Future<void> _getUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getInt('userType'); // Retrieve stored user type
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Details'),
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.projectName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.description,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 20),
              _buildDetailItem('Start Date:', widget.startDate),
              _buildDetailItem('Deadline:', widget.deadline),
              _buildDetailItem('Total Amount:', '${widget.totalAmount} SR'),
              _buildDetailItem('Project Type:', widget.projectType),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text(
                '30% of donors contributed',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: 0.3, // Replace with actual progress
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 20),

              // ✅ Show Donate Button ONLY IF userType == 0 (Donor)
              if (userType == 0)
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      _showDonationPopup(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Donate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          text: '$title ',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  void _showDonationPopup(BuildContext context) {
    TextEditingController amountController = TextEditingController();
    bool isAnonymous = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter Donation Amount ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ], // Prevents "." and non-numeric input

                    decoration: InputDecoration(
                      hintText: 'Amount in S.R',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isAnonymous,
                        onChanged: (value) {
                          setState(() {
                            isAnonymous = value!;
                          });
                        },
                      ),
                      const Text('Donate anonymously'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _validateAmount(amountController.text)
                        ? () {
                            Navigator.pop(context);
                            _processDonation(
                                amountController.text, isAnonymous);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Send',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  bool _validateAmount(String amount) {
    if (amount.isEmpty) return false;
    final int? parsedAmount = int.tryParse(amount);
    return parsedAmount != null && parsedAmount > 0;
  }

  void _processDonation(String amount, bool isAnonymous) {
    print('Donated $amount SR');
    print('Anonymous: $isAnonymous');
    // TODO: Implement donation logic (e.g., send data to backend)
  }
}
