import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class InitiateVoting extends StatefulWidget {
  final int projectId;
  final double failedProjectAmount;
  final String walletAddress;

  const InitiateVoting({
    Key? key,
    required this.projectId,
    required this.failedProjectAmount,
    required this.walletAddress,
  }) : super(key: key);

  @override
  _InitiateVotingState createState() => _InitiateVotingState();
}

class _InitiateVotingState extends State<InitiateVoting> {
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _eligibleProjects = [];
  List<String> _selectedOptions = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = true;
  Map<String, int> _votingResults = {};
  int _totalVoters = 0;
  Timer? _refreshTimer;
  bool _hasExistingVoting = false;
  String _projectName = '';
  bool _isDonor = false;

  @override
  void initState() {
    super.initState();
    _checkExistingVoting();
    _fetchEligibleProjects();
    _fetchProjectName();
    _checkDonorStatus();
    _startVotingResultsRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startVotingResultsRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _fetchVotingResults();
    });
  }

  Future<void> _fetchVotingResults() async {
    try {
      // Get voting results from blockchain
      final results =
          await _blockchainService.getVotingResults(widget.projectId);
      int totalVotes = 0;

      // Calculate total votes
      results.forEach((_, votes) => totalVotes += votes);

      setState(() {
        _votingResults = results;
        _totalVoters = totalVotes;
      });
    } catch (e) {
      print("❌ Error fetching voting results: $e");
    }
  }

  Future<void> _fetchEligibleProjects() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> allProjects =
        await _blockchainService.fetchAllProjects();
    double failedProjectAmount = widget.failedProjectAmount;
    int failedProjectId = widget.projectId;

    List<Map<String, dynamic>> filteredProjects = [];
    DateTime now = DateTime.now();

    for (var project in allProjects) {
      int projectId = project['id'];
      String name = project['name'].toString();

      // Convert Wei to ETH for amounts
      double totalAmount;
      double donatedAmount;

      if (project['totalAmount'] is BigInt) {
        totalAmount = _blockchainService.weiToEth(project['totalAmount']);
      } else {
        totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
      }

      if (project['donatedAmount'] is BigInt) {
        donatedAmount = _blockchainService.weiToEth(project['donatedAmount']);
      } else {
        donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();
      }

      // Handle project state
      int projectState;
      if (project['state'] is int) {
        projectState = project['state'];
      } else if (project['state'] is String) {
        projectState = int.tryParse(project['state']) ?? -1;
      } else {
        projectState = -1;
      }

      // Parse dates properly
      DateTime? endDate;
      if (project['endDate'] != null) {
        if (project['endDate'] is String) {
          endDate = DateTime.tryParse(project['endDate']);
        } else if (project['endDate'] is DateTime) {
          endDate = project['endDate'];
        } else if (project['endDate'] is int) {
          endDate =
              DateTime.fromMillisecondsSinceEpoch(project['endDate'] * 1000);
        }
      }

      // Fetch project status from Firestore
      bool isCanceled = false;
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId.toString())
            .get();
        if (doc.exists) {
          isCanceled = doc['isCanceled'] ?? false;
        }
      } catch (e) {
        print("❌ Error fetching Firestore status for project $projectId: $e");
      }

      double amountRemaining = totalAmount - donatedAmount;

      // ✅ Filters
      bool isSameAsFailed = projectId == failedProjectId;
      bool isEnded = endDate == null || now.isAfter(endDate);
      bool hasEnoughAmount = totalAmount >=
          (failedProjectAmount -
              0.001); // Check total amount instead of remaining

      // Debug print
      print("🔍 Project: $name (ID: $projectId) | "
          "EndDate: ${endDate?.toString() ?? 'null'}, "
          "AmountRemaining: $amountRemaining ETH, "
          "IsCanceled: $isCanceled, "
          "TotalAmount: $totalAmount ETH, "
          "DonatedAmount: $donatedAmount ETH, "
          "FailedAmount: $failedProjectAmount ETH");

      if (isSameAsFailed || isEnded || !hasEnoughAmount || isCanceled) {
        print("⛔ Skipping project: $name | Reason: "
            "SameAsFailed: $isSameAsFailed, Ended: $isEnded, "
            "EnoughFunds: $hasEnoughAmount, Canceled: $isCanceled");
        continue;
      }

      // ✅ Add if it passed all checks
      print("✅ Adding eligible project: $name | "
          "State: $projectState, AmountRemaining: $amountRemaining");
      Map<String, dynamic> projectWithAmounts = Map.from(project);
      projectWithAmounts['calculatedTotalAmount'] = totalAmount;
      projectWithAmounts['calculatedDonatedAmount'] = donatedAmount;
      projectWithAmounts['calculatedRemainingAmount'] = amountRemaining;
      filteredProjects.add(projectWithAmounts);
    }

    setState(() {
      _eligibleProjects = filteredProjects;
      _isLoading = false;
    });
  }

  Future<void> _checkExistingVoting() async {
    try {
      // Check if voting exists for this project
      final votingExists =
          await _blockchainService.hasExistingVoting(widget.projectId);
      setState(() {
        _hasExistingVoting = votingExists;
      });

      if (_hasExistingVoting) {
        // If voting exists, start fetching results
        _startVotingResultsRefresh();
      }
    } catch (e) {
      print("❌ Error checking existing voting: $e");
    }
  }

  Future<void> _fetchProjectName() async {
    try {
      final projectDetails =
          await _blockchainService.getProjectDetails(widget.projectId);
      setState(() {
        _projectName = projectDetails['name'] ?? '';
      });
    } catch (e) {
      print("❌ Error fetching project name: $e");
    }
  }

  Future<void> _checkDonorStatus() async {
    try {
      final hasDonated = await _blockchainService.hasDonatedToProject(
        widget.projectId,
        widget.walletAddress,
      );
      setState(() {
        _isDonor = hasDonated;
      });
    } catch (e) {
      print("❌ Error checking donor status: $e");
    }
  }

  void _toggleSelection(String projectName) {
    setState(() {
      if (_selectedOptions.contains(projectName)) {
        _selectedOptions.remove(projectName);
      } else if (_selectedOptions.length < 5) {
        _selectedOptions.add(projectName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maximum 5 options can be selected'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _initiateVoting() async {
    // Check again before initiating
    final votingExists =
        await _blockchainService.hasExistingVoting(widget.projectId);
    if (votingExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Voting has already been initiated for this project"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate voting period
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please set both start and end dates for voting")),
      );
      return;
    }

    // Validate voting period duration
    final duration = _endDate!.difference(_startDate!);
    if (duration.inDays < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voting period must be at least 1 day")),
      );
      return;
    }

    if (duration.inDays > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voting period cannot exceed 30 days")),
      );
      return;
    }

    // Validate selected options
    if (_selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select at least one project for voting")),
      );
      return;
    }

    // Add "Request a Refund" option if not already present
    if (!_selectedOptions.contains("Request a Refund")) {
      _selectedOptions.add("Request a Refund");
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Get selected project IDs
      List<BigInt> selectedProjectIds = _eligibleProjects
          .where((project) =>
              project['name'] != null &&
              _selectedOptions.contains(project['name'].toString()))
          .map((project) =>
              BigInt.tryParse(project['id'].toString()) ?? BigInt.zero)
          .where((id) => id != BigInt.zero)
          .toList();

      // Initiate voting on blockchain
      await _blockchainService.initiateVoting(
        BigInt.from(widget.projectId),
        selectedProjectIds,
        BigInt.from(_startDate!.millisecondsSinceEpoch ~/ 1000),
        BigInt.from(_endDate!.millisecondsSinceEpoch ~/ 1000),
      );

      // Close loading dialog
      Navigator.pop(context);

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Success"),
          content: Text("Voting has been initiated successfully!\n\n"
              "Donors will be notified and can start voting."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text("OK"),
            ),
          ],
        ),
      );

      // Start refreshing voting results
      _startVotingResultsRefresh();
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print("❌ Error initiating voting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error initiating voting: $e"),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildVotingResultsSection() {
    if (_votingResults.isEmpty) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Voting Results",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text("Total Voters: $_totalVoters"),
            SizedBox(height: 16),
            ..._votingResults.entries.map((entry) {
              final percentage = _totalVoters > 0
                  ? (entry.value / _totalVoters * 100).toStringAsFixed(1)
                  : "0.0";
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key),
                      ),
                      Text("$percentage% (${entry.value} votes)"),
                    ],
                  ),
                  SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _totalVoters > 0 ? entry.value / _totalVoters : 0,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  SizedBox(height: 8),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectList() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_eligibleProjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No eligible projects found',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Selected ${_selectedOptions.length}/5 options',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedOptions.length == 5 ? Colors.red : Colors.black,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _eligibleProjects.length,
            itemBuilder: (context, index) {
              final project = _eligibleProjects[index];
              final projectName = project['name']?.toString() ?? '';
              final isSelected = _selectedOptions.contains(projectName);

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(projectName),
                  subtitle: Text(
                    'Required Amount: ${project['calculatedTotalAmount']?.toStringAsFixed(4)} ETH',
                  ),
                  trailing: isSelected
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : _selectedOptions.length >= 5
                      ? Icon(Icons.radio_button_unchecked, color: Colors.grey)
                      : Icon(Icons.radio_button_unchecked),
                  onTap: () => _toggleSelection(projectName),
                  selected: isSelected,
                  tileColor: isSelected ? Colors.blue.withOpacity(0.1) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Initiate Voting - $_projectName'),
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Select up to 5 projects for voting options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_hasExistingVoting) ...[
            _buildVotingResultsSection(),
          ] else ...[
            Expanded(
              child: _buildProjectList(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    'Set Voting Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(_startDate == null
                              ? 'Select Start Date'
                              : DateFormat('MMM dd, yyyy').format(_startDate!)),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() => _startDate = date);
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text(_endDate == null
                              ? 'Select End Date'
                              : DateFormat('MMM dd, yyyy').format(_endDate!)),
                          onPressed: () async {
                            if (_startDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Please select start date first'),
                                ),
                              );
                              return;
                            }
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _startDate!.add(Duration(days: 1)),
                              firstDate: _startDate!.add(Duration(days: 1)),
                              lastDate: _startDate!.add(Duration(days: 30)),
                            );
                            if (date != null) {
                              setState(() => _endDate = date);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _selectedOptions.isEmpty || _startDate == null || _endDate == null
                        ? null
                        : _initiateVoting,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                      padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Initiate Voting',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
