import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({Key? key}) : super(key: key);

  @override
  _DonationHistoryPageState createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> {
  List<Map<String, dynamic>> historyList = [];
  bool isLoading = true;
  String selectedFilter = 'All';
  String selectedSort = 'Date (Newest)';
  final List<String> filterOptions = [
    'All',
    'Active',
    'Completed',
    'Cancelled'
  ];
  final List<String> sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (Highest)',
    'Amount (Lowest)'
  ];

  @override
  void initState() {
    super.initState();
    _loadDonationHistory();
  }

  Future<void> _loadDonationHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('walletAddress') ?? '';
      print('Loading donations for wallet: $walletAddress');

      final donationsJson = prefs.getString('donations_$walletAddress');
      if (donationsJson != null) {
        final List<dynamic> donations = json.decode(donationsJson);
        historyList = await Future.wait<Map<String, dynamic>>(
          donations
              .where((donation) =>
                  donation['donorWallet']?.toString().toLowerCase() ==
                  walletAddress.toLowerCase())
              .map((donation) async {
            // Get current project status and details from Firestore
            String status = 'unknown';
            String projectName = 'Unknown Project';
            String projectType = 'Unknown';
            double totalAmount = 0.0;
            String description = '';

            try {
              final projectDoc = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(donation['id'].toString())
                  .get();

              if (projectDoc.exists) {
                final data = projectDoc.data() as Map<String, dynamic>;
                status = data['status'] ?? 'unknown';
                projectName = data['name'] ??
                    donation['projectName'] ??
                    donation['name'] ??
                    'Unknown Project';
                projectType =
                    data['projectType'] ?? donation['projectType'] ?? 'Unknown';
                totalAmount =
                    data['totalAmount'] ?? donation['totalAmount'] ?? 0.0;
                description = data['description'] ??
                    donation['description'] ??
                    donation['description'] ??
                    donation['name'] ?? // as an extreme fallback
                    'No description available';
                donation['description'] = description;

                // Calculate status based on dates and amounts
                if (data['isCanceled'] == true) {
                  status = 'cancelled';
                } else {
                  final now = DateTime.now();
                  final startDate = data['startDate']?.toDate() ?? now;
                  final endDate = data['endDate']?.toDate();
                  final donatedAmount =
                      data['donatedAmount'] ?? donation['donatedAmount'] ?? 0.0;
                  if (donatedAmount >= totalAmount) {
                    status = 'completed';
                  } else if (endDate != null && now.isAfter(endDate)) {
                    status = 'ended';
                  } else if (now.isBefore(startDate)) {
                    status = 'upcoming';
                  } else {
                    status = 'active';
                  }
                }
              }
            } catch (e) {
              print('Error fetching project status: $e');
            }

            // Calculate progress
            final donatedAmount =
                double.tryParse(donation['donatedAmount'].toString()) ?? 0.0;
            final progress =
                totalAmount > 0 ? (donatedAmount / totalAmount) : 0.0;

            return <String, dynamic>{
              ...Map<String, dynamic>.from(donation),
              'status': status,
              'projectName': projectName,
              'projectType': projectType,
              'totalAmount': totalAmount,
              'description': description,
              'progress': progress,
              'formattedDate': donation['endDate'] != null
                  ? DateFormat('yyyy-MM-dd').format(
                      DateTime.fromMillisecondsSinceEpoch(
                          int.parse(donation['endDate'].toString())))
                  : 'N/A',
            };
          }).toList(),
        );

        _sortDonations();
      }
    } catch (e) {
      print('Error loading donation history: $e');
      historyList = [];
    }

    setState(() {
      isLoading = false;
    });
  }

  void _sortDonations() {
    switch (selectedSort) {
      case 'Date (Newest)':
        historyList.sort((a, b) => int.parse(b['timestamp'].toString())
            .compareTo(int.parse(a['timestamp'].toString())));
        break;
      case 'Date (Oldest)':
        historyList.sort((a, b) => int.parse(a['timestamp'].toString())
            .compareTo(int.parse(b['timestamp'].toString())));
        break;
      case 'Amount (Highest)':
        historyList.sort((a, b) => double.parse(b['donatedAmount'].toString())
            .compareTo(double.parse(a['donatedAmount'].toString())));
        break;
      case 'Amount (Lowest)':
        historyList.sort((a, b) => double.parse(a['donatedAmount'].toString())
            .compareTo(double.parse(b['donatedAmount'].toString())));
        break;
    }
  }

  List<Map<String, dynamic>> _getFilteredDonations() {
    if (selectedFilter == 'All') {
      return historyList;
    }
    return historyList
        .where((donation) =>
            donation['status'].toString().toLowerCase() ==
            selectedFilter.toLowerCase())
        .toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredDonations = _getFilteredDonations();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Donation History',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownButton<String>(
                    value: selectedFilter,
                    items: filterOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedFilter = newValue;
                        });
                      }
                    },
                  ),
                  DropdownButton<String>(
                    value: selectedSort,
                    items: sortOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          selectedSort = newValue;
                          _sortDonations();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredDonations.isEmpty
                      ? const Center(
                          child: Text(
                            'No donations found',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadDonationHistory,
                          child: ListView.builder(
                            itemCount: filteredDonations.length,
                            itemBuilder: (context, index) {
                              final donation = filteredDonations[index];
                              final progress =
                                  ((donation['progress'] ?? 0.0) * 100)
                                      .toStringAsFixed(1);

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    donation['projectName'] ??
                                        'Unknown Project',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                        'Donated: ${donation['donatedAmount']} ETH',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Goal: ${donation['totalAmount']} ETH',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Progress: $progress%',
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                      Text(
                                        'End Date: ${donation['formattedDate']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        'Project Type: ${donation['projectType']}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    try {
                                      final projectDoc = await FirebaseFirestore
                                          .instance
                                          .collection('projects')
                                          .doc(donation['id'].toString())
                                          .get();

                                      final data = projectDoc.data()
                                          as Map<String, dynamic>?;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProjectDetails(
                                            projectId: int.parse(
                                                donation['id'].toString()),
                                            projectName:
                                                donation['projectName'] ??
                                                    'Unknown Project',
                                            description:
                                                donation['description'] ??
                                                    data?['description'] ??
                                                    'No description available',
                                            startDate: DateFormat('yyyy-MM-dd')
                                                .format(DateTime
                                                    .fromMillisecondsSinceEpoch(
                                                        donation['timestamp'])),
                                            deadline: donation['endDate'] !=
                                                    null
                                                ? DateFormat('yyyy-MM-dd')
                                                    .format(DateTime
                                                        .fromMillisecondsSinceEpoch(
                                                            donation[
                                                                'endDate']))
                                                : '',
                                            totalAmount:
                                                donation['totalAmount'] ?? 0.0,
                                            donatedAmount:
                                                donation['donatedAmount'] ??
                                                    0.0,
                                            projectType:
                                                donation['projectType'] ??
                                                    'Unknown',
                                            projectCreatorWallet: donation[
                                                    'projectCreatorWallet'] ??
                                                '',
                                            progress:
                                                donation['progress'] ?? 0.0,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      print(
                                          'Error navigating to project details: $e');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Error loading project details'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
