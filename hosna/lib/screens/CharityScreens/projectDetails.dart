import 'package:flutter/material.dart';

class projectDetails extends StatelessWidget {
  final String projectName;
  final String description;
  final String startDate;
  final String deadline;
  final String totalAmount;
  final String projectType;

  projectDetails({
    required this.projectName,
    required this.description,
    required this.startDate,
    required this.deadline,
    required this.totalAmount,
    required this.projectType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Details'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                projectName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
              ),
              SizedBox(height: 20),
              Text(
                description,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              _buildDetailItem('Start Date:', startDate),
              _buildDetailItem('Deadline:', deadline),
              _buildDetailItem('Total Amount:', '$totalAmount SR'),
              _buildDetailItem('Project Type:', projectType),
              SizedBox(height: 20),
              Divider(color: Colors.grey[300]),
              SizedBox(height: 10),
              Text(
                '30% of donors contributed',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              SizedBox(height: 10),
              LinearProgressIndicator(
                value: 0.3, // Replace with actual progress
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              SizedBox(height: 20),
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
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          children: [
            TextSpan(
                text: value, style: TextStyle(fontWeight: FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}
