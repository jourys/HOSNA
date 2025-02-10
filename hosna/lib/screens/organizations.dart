import 'package:flutter/material.dart';

class OrganizationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80), // Increases app bar height
        child: AppBar(
          backgroundColor: Color.fromRGBO(24, 71, 137, 1),
          elevation: 0, // Remove shadow
          automaticallyImplyLeading: false, // Remove back arrow
          flexibleSpace: Padding(
            padding: EdgeInsets.only(bottom: 20), // Move text down
            child: Align(
              alignment: Alignment.bottomCenter, // Center and move down
              child: Text(
                "Browse Organizations",
                style: TextStyle(
                  color: Colors.white, // Make text white
                  fontSize: 24, // Increase font size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Text(
                  '🏢 Organizations Page',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
