import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/PostProject.dart';
import 'dart:convert';

class DraftsPage extends StatefulWidget {
  final String? walletAddress; // Add walletAddress as a parameter
  const DraftsPage({super.key, this.walletAddress});

  @override
  _DraftsPageState createState() => _DraftsPageState();
}

class _DraftsPageState extends State<DraftsPage> {
  List<Map<String, dynamic>> _drafts = [];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress =
        widget.walletAddress; // Use the wallet address from the widget

    if (walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in. Cannot load drafts.')),
      );
      return;
    }

    final userDraftsKey = 'drafts_$walletAddress'; // Unique key per user
    final drafts = prefs.getStringList(userDraftsKey) ?? [];

    setState(() {
      _drafts = drafts
          .map((draft) => jsonDecode(draft) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _deleteDraft(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress =
        widget.walletAddress; // Use the wallet address from the widget

    if (walletAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not logged in. Cannot delete draft.')),
      );
      return;
    }

    final userDraftsKey = 'drafts_$walletAddress'; // Unique key per user
    final drafts = prefs.getStringList(userDraftsKey) ?? [];

    drafts.removeAt(index);
    await prefs.setStringList(userDraftsKey, drafts);

    setState(() {
      _drafts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Draft deleted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Drafts'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        foregroundColor: Colors.white,
      ),
      body: _drafts.isEmpty
          ? Center(child: Text('No drafts found.'))
          : ListView.builder(
              itemCount: _drafts.length,
              itemBuilder: (context, index) {
                final draft = _drafts[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(
                      draft['name'],
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft['description']),
                        SizedBox(height: 5),
                        Text(
                          'Start Date: ${draft['startDate']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Deadline: ${draft['deadline']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Total Amount: ${draft['totalAmount']} SR',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          'Project Type: ${draft['projectType']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteDraft(index),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostProject(
                            draft: draft, // Pass the draft to PostProject
                            walletAddress:
                                widget.walletAddress, // Pass the wallet address
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}