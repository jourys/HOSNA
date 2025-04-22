import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';
import 'package:intl/intl.dart';

class DeletedComplaintsPage extends StatefulWidget {
  @override
  _DeletedComplaintsPageState createState() => _DeletedComplaintsPageState();
}

class _DeletedComplaintsPageState extends State<DeletedComplaintsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _deletedComplaints = [];
  List<Map<String, dynamic>> _filteredComplaints = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  @override
  void initState() {
    super.initState();
    _fetchDeletedComplaints();
  }

  Future<void> _fetchDeletedComplaints() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final querySnapshot = await _firestore
          .collection('deletedReports')
          .orderBy('deletedAt', descending: true)
          .get();
      
      final complaints = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'No Title',
          'description': data['description'] ?? 'No Description',
          'complainant': data['complainant'] ?? 'Unknown',
          'complaintType': data['complaintType'] ?? 'Unknown',
          'targetDonor': data['targetDonor'],
          'targetCharity': data['targetCharity'],
          'project_id': data['project_id'],
          'deletedAt': data['deletedAt'] is Timestamp 
              ? (data['deletedAt'] as Timestamp).toDate() 
              : DateTime.now(),
          'deletedBy': data['deletedBy'] ?? 'Unknown Admin',
          'deletionJustification': data['deletionJustification'] ?? 'No justification provided',
        };
      }).toList();
      
      setState(() {
        _deletedComplaints = complaints;
        _filteredComplaints = complaints;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch deleted complaints: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterComplaints(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      if (_searchQuery.isEmpty && _selectedFilter == 'All') {
        _filteredComplaints = _deletedComplaints;
      } else {
        _filteredComplaints = _deletedComplaints.where((complaint) {
          // First apply search query filter
          bool matchesSearch = true;
          if (_searchQuery.isNotEmpty) {
            final title = complaint['title'].toString().toLowerCase();
            final description = complaint['description'].toString().toLowerCase();
            final searchLower = _searchQuery.toLowerCase();
            
            matchesSearch = title.contains(searchLower) || 
                      description.contains(searchLower);
          }
          
          // Then apply type filter
          bool matchesType = true;
          if (_selectedFilter != 'All') {
            matchesType = complaint['complaintType'] == _selectedFilter.toLowerCase();
          }
          
          return matchesSearch && matchesType;
        }).toList();
      }
    });
  }

  Future<void> _restoreComplaint(String complaintId) async {
    try {
      // Get the deleted complaint data
      final complaintDoc = await _firestore
          .collection('deletedReports')
          .doc(complaintId)
          .get();
      
      if (!complaintDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complaint not found')),
        );
        return;
      }
      
      // Get the data without deletion-specific fields
      final data = complaintDoc.data()!;
      final restoreData = Map<String, dynamic>.from(data);
      
      // Remove deletion-specific fields
      restoreData.remove('deletedAt');
      restoreData.remove('deletedBy');
      restoreData.remove('deletionJustification');
      
      // Add restoration info
      restoreData['restoredAt'] = FieldValue.serverTimestamp();
      restoreData['restoredBy'] = FirebaseAuth.instance.currentUser?.email ?? 'Admin';
      
      // Restore the complaint to the original collection
      await _firestore
          .collection('reports')
          .doc(complaintId)
          .set(restoreData);
      
      // Send notification to the complainant
      if (restoreData.containsKey('complainant')) {
        final complainantAddress = restoreData['complainant'];
        
        await _firestore.collection('notifications').add({
          'userId': complainantAddress,
          'title': 'Complaint Restored',
          'message': 'Your complaint "${restoreData['title'] ?? 'Untitled'}" has been restored by an admin and is now active again.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'complaint_restored',
          'complaintId': complaintId,
        });
      }
      
      // Delete from the deleted complaints collection
      await _firestore
          .collection('deletedReports')
          .doc(complaintId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complaint restored successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the list
      await _fetchDeletedComplaints();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore complaint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _viewComplaintDetails(Map<String, dynamic> complaint) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SizedBox(
              width: 600,
              height: 600,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        complaint['title'],
                        style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(24, 71, 137, 1)),
                      ),
                    ),
                    SizedBox(height: 30),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Complaint Details: ${complaint['description']}',
                                style: TextStyle(
                                    fontSize: 20,
                                    color: Color.fromRGBO(24, 71, 137, 1))),
                            SizedBox(height: 30),
                            Text(
                                'Complaint Type: ${complaint['complaintType']}',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Color.fromRGBO(24, 71, 137, 1))),
                            SizedBox(height: 20),
                            Text(
                                'Complainant: ${complaint['complainant']}',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Color.fromRGBO(24, 71, 137, 1))),
                            SizedBox(height: 20),
                            Text(
                                'Target: ${complaint['targetDonor'] ?? complaint['targetCharity'] ?? 'N/A'}',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Color.fromRGBO(24, 71, 137, 1))),
                            SizedBox(height: 30),
                            Divider(color: Colors.grey),
                            SizedBox(height: 20),
                            Text(
                                'Deletion Information',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red)),
                            SizedBox(height: 10),
                            Text(
                                'Deleted At: ${DateFormat('MMM d, yyyy HH:mm').format(complaint['deletedAt'])}',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.red[700])),
                            SizedBox(height: 10),
                            Text(
                                'Deleted By: ${complaint['deletedBy']}',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.red[700])),
                            SizedBox(height: 10),
                            Text(
                                'Justification:',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red[700])),
                            SizedBox(height: 5),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                complaint['deletionJustification'],
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                            minimumSize: Size(120, 50),
                            padding: EdgeInsets.symmetric(
                                vertical: 18, horizontal: 22),
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Close',
                              style: TextStyle(color: Colors.white)),
                        ),
                        SizedBox(width: 30),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize: Size(120, 50),
                            padding: EdgeInsets.symmetric(
                                vertical: 18, horizontal: 22),
                            textStyle: TextStyle(fontSize: 18),
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _restoreComplaint(complaint['id']);
                          },
                          child: Text('Restore Complaint',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          AdminSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deleted Complaints',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(24, 71, 137, 1),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by title or description',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onChanged: _filterComplaints,
                        ),
                      ),
                      SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedFilter,
                        items: ['All', 'Donor', 'Charity', 'Project']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFilter = newValue;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _filteredComplaints.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty && _selectedFilter == 'All'
                                ? 'No deleted complaints found'
                                : 'No complaints match your search criteria',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredComplaints.length,
                            itemBuilder: (context, index) {
                              final complaint = _filteredComplaints[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _viewComplaintDetails(complaint),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                complaint['title'],
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.red[100],
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                'Deleted',
                                                style: TextStyle(
                                                  color: Colors.red[800],
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          complaint['description'].length > 150
                                              ? '${complaint['description'].substring(0, 150)}...'
                                              : complaint['description'],
                                          style: TextStyle(color: Colors.grey[800]),
                                        ),
                                        SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Type: ${complaint['complaintType'].toString().toUpperCase()}',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              'Deleted: ${DateFormat('MMM d, yyyy').format(complaint['deletedAt'])}',
                                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => _viewComplaintDetails(complaint),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(color: Colors.grey),
                                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              child: Text('View Details'),
                                            ),
                                            SizedBox(width: 12),
                                            ElevatedButton(
                                              onPressed: () => _restoreComplaint(complaint['id']),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              ),
                                              child: Text('Restore', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 