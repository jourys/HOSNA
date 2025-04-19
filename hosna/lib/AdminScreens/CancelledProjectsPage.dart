import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';

class CancelledProjectsPage extends StatefulWidget {
  const CancelledProjectsPage({Key? key}) : super(key: key);

  @override
  _CancelledProjectsPageState createState() => _CancelledProjectsPageState();
}

class _CancelledProjectsPageState extends State<CancelledProjectsPage> {
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _cancelledProjects = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCancelledProjects();
  }

  Future<void> _fetchCancelledProjects() async {
    setState(() => _isLoading = true);
    
    try {
      // First, get all projects from blockchain
      final projectCount = await _blockchainService.getProjectCount();
      List<Map<String, dynamic>> allProjects = [];

      // Get all projects from blockchain
      for (int i = 0; i < projectCount; i++) {
        final project = await _blockchainService.getProjectDetails(i);
        if (!project.containsKey("error")) {
          allProjects.add(project);
        }
      }

      // Now, get all cancelled projects from Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('isCanceled', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> cancelledProjects = [];

      // For each cancelled project in Firestore, find its details in the blockchain data
      for (var doc in querySnapshot.docs) {
        final projectId = int.tryParse(doc.id);
        if (projectId != null) {
          // Find matching project from blockchain data
          final matchingProject = allProjects.firstWhere(
            (p) => p['id'] == projectId,
            orElse: () => <String, dynamic>{},
          );

          if (matchingProject.isNotEmpty) {
            // Add Firestore data (including justification) to the blockchain data
            final firestoreData = doc.data();
            final combinedData = {
              ...matchingProject,
              'cancellationReason': firestoreData['cancellationReason'] ?? 'No reason provided',
              'cancelledAt': firestoreData['cancelledAt'] ?? Timestamp.now(),
            };
            
            cancelledProjects.add(combinedData);
          }
        }
      }

      // Sort by cancellation date (most recent first)
      cancelledProjects.sort((a, b) {
        final aTimestamp = a['cancelledAt'] as Timestamp;
        final bTimestamp = b['cancelledAt'] as Timestamp;
        return bTimestamp.compareTo(aTimestamp);
      });

      setState(() {
        _cancelledProjects = cancelledProjects;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching cancelled projects: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredProjects() {
    if (_searchQuery.isEmpty) {
      return _cancelledProjects;
    }
    
    return _cancelledProjects.where((project) {
      return project['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
             project['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
             project['cancellationReason'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('MMM d, y HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Row(
          children: [
            AdminSidebar(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Cancelled Projects',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(24, 71, 137, 1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search projects or justifications',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                            color: Color.fromRGBO(24, 71, 137, 1),
                            width: 2.0,
                          ),
                        ),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _getFilteredProjects().isEmpty
                            ? const Center(child: Text('No cancelled projects found.'))
                            : ListView.builder(
                                itemCount: _getFilteredProjects().length,
                                itemBuilder: (context, index) {
                                  final project = _getFilteredProjects()[index];
                                  return Card(
                                    margin: const EdgeInsets.all(8.0),
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      side: BorderSide(
                                        color: Colors.red[400]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        project['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromRGBO(24, 71, 137, 1),
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(height: 5),
                                          Text(
                                            'Posted by: ${project['organization'] ?? "Unknown"}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(
                                            'Cancelled on: ${_formatDate(project['cancelledAt'])}',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Project Description:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(project['description']),
                                              SizedBox(height: 16),
                                              Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.red[50],
                                                  border: Border.all(color: Colors.red[200]!),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Cancellation Justification:',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                        color: Colors.red[800],
                                                      ),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      project['cancellationReason'] ?? 'No reason provided',
                                                      style: TextStyle(
                                                        fontStyle: FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Total Amount: ${project['totalAmount']} ETH',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Donated: ${project['donatedAmount']} ETH',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
    );
  }
} 