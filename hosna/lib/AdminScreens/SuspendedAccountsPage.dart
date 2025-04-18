import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';

class SuspendedAccountsPage extends StatefulWidget {
  @override
  _SuspendedAccountsPageState createState() => _SuspendedAccountsPageState();
}

class _SuspendedAccountsPageState extends State<SuspendedAccountsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _suspendedAccounts = [];
  List<Map<String, dynamic>> _filteredAccounts = [];
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _fetchSuspendedAccounts();
  }

  Future<void> _fetchSuspendedAccounts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('isSuspended', isEqualTo: true)
          .get();
      
      final accounts = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? 'No email',
          'phoneNumber': data['phoneNumber'] ?? 'No phone',
          'city': data['city'] ?? 'Unknown',
          'suspendedAt': (data['suspendedAt'] as Timestamp).toDate(),
          'suspensionReason': data['suspensionReason'] ?? 'No reason provided',
        };
      }).toList();
      
      setState(() {
        _suspendedAccounts = accounts;
        _filteredAccounts = accounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to fetch suspended accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchSuspensionHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('suspensionHistory')
          .orderBy('suspendedAt', descending: true)
          .get();
          
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'suspendedAt': (data['suspendedAt'] as Timestamp).toDate(),
          'suspendedBy': data['suspendedBy'] ?? 'Unknown admin',
          'reason': data['reason'] ?? 'No reason provided',
          'reactivatedAt': data['reactivatedAt'] != null 
              ? (data['reactivatedAt'] as Timestamp).toDate() 
              : null,
          'reactivatedBy': data['reactivatedBy'],
        };
      }).toList();
    } catch (e) {
      print('Error fetching suspension history: $e');
      return [];
    }
  }

  void _filterAccounts(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredAccounts = _suspendedAccounts;
      } else {
        _filteredAccounts = _suspendedAccounts.where((account) {
          final name = account['name'].toString().toLowerCase();
          final email = account['email'].toString().toLowerCase();
          final city = account['city'].toString().toLowerCase();
          final searchLower = query.toLowerCase();
          
          return name.contains(searchLower) || 
                 email.contains(searchLower) || 
                 city.contains(searchLower);
        }).toList();
      }
    });
  }

  Future<void> _reactivateAccount(String userId, String userName) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isSuspended': false,
        'reactivatedAt': FieldValue.serverTimestamp(),
        'reactivatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
      });
      
      // Update the current suspension record in history
      final suspensionHistory = await _firestore
          .collection('users')
          .doc(userId)
          .collection('suspensionHistory')
          .where('reactivatedAt', isNull: true)
          .limit(1)
          .get();
          
      if (suspensionHistory.docs.isNotEmpty) {
        await suspensionHistory.docs.first.reference.update({
          'reactivatedAt': FieldValue.serverTimestamp(),
          'reactivatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Admin',
        });
      }
      
      // Send notification to user
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': 'Account Reactivated',
        'message': 'Your account has been reactivated. You can now use all features of the platform.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      // Remove from local lists
      setState(() {
        _suspendedAccounts.removeWhere((account) => account['id'] == userId);
        _filteredAccounts.removeWhere((account) => account['id'] == userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName\'s account has been reactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reactivate account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewUserDetails(Map<String, dynamic> account) async {
    // Start loading the suspension history
    List<Map<String, dynamic>> suspensionHistory = [];
    bool isHistoryLoading = true;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch suspension history when dialog opens
            if (isHistoryLoading) {
              _fetchSuspensionHistory(account['id']).then((history) {
                setDialogState(() {
                  suspensionHistory = history;
                  isHistoryLoading = false;
                });
              });
            }
            
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'User Details',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color.fromRGBO(24, 71, 137, 1),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Divider(),
                    SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Name', account['name']),
                            _buildDetailRow('Email', account['email']),
                            _buildDetailRow('Phone', account['phoneNumber']),
                            _buildDetailRow('City', account['city']),
                            _buildDetailRow('Suspended Since', 
                              DateFormat('MMMM d, yyyy').format(account['suspendedAt'])),
                            SizedBox(height: 16),
                            Text(
                              'Current Suspension Reason:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(account['suspensionReason']),
                            ),
                            SizedBox(height: 24),
                            Text(
                              'Suspension History:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(24, 71, 137, 1),
                              ),
                            ),
                            SizedBox(height: 12),
                            isHistoryLoading
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : suspensionHistory.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text('No previous suspension records found.'),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: suspensionHistory.length,
                                        itemBuilder: (context, index) {
                                          final history = suspensionHistory[index];
                                          final isActive = history['reactivatedAt'] == null;
                                          
                                          return Card(
                                            margin: EdgeInsets.only(bottom: 12),
                                            color: isActive ? Colors.red[50] : Colors.grey[50],
                                            child: Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Suspended on: ${DateFormat('MMM d, yyyy').format(history['suspendedAt'])}',
                                                        style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: isActive ? Colors.red : Colors.green,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          isActive ? 'ACTIVE' : 'RESOLVED',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text('Suspended by: ${history['suspendedBy']}'),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Reason:',
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  Text(history['reason']),
                                                  if (!isActive) ...[
                                                    SizedBox(height: 8),
                                                    Divider(),
                                                    SizedBox(height: 8),
                                                    Text(
                                                      'Reactivated on: ${DateFormat('MMM d, yyyy').format(history['reactivatedAt'])}',
                                                      style: TextStyle(color: Colors.green[700]),
                                                    ),
                                                    Text('Reactivated by: ${history['reactivatedBy'] ?? 'Unknown'}'),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _reactivateAccount(account['id'], account['name']);
                          },
                          icon: Icon(Icons.restore),
                          label: Text('Reactivate Account'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
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
                    'Suspended Accounts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromRGBO(24, 71, 137, 1),
                    ),
                  ),
                  SizedBox(height: 20),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, or city',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: _filterAccounts,
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                      ? Center(child: CircularProgressIndicator())
                      : _filteredAccounts.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isEmpty
                                ? 'No suspended accounts found'
                                : 'No accounts match your search',
                              style: TextStyle(fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredAccounts.length,
                            itemBuilder: (context, index) {
                              final account = _filteredAccounts[index];
                              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  onTap: () => _viewUserDetails(account),
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
                                                account['name'],
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () => _reactivateAccount(account['id'], account['name']),
                                              icon: Icon(Icons.restore),
                                              label: Text('Reactivate'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Text('Email: ${account['email']}'),
                                        Text('Phone: ${account['phoneNumber']}'),
                                        Text('City: ${account['city']}'),
                                        SizedBox(height: 10),
                                        Text(
                                          'Suspended since: ${DateFormat('MMM d, yyyy').format(account['suspendedAt'])}',
                                          style: TextStyle(fontStyle: FontStyle.italic),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Suspension Reason:',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(account['suspensionReason']),
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