import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/ProjectDetails.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CanceledFailedProjects extends StatefulWidget {
  const CanceledFailedProjects({super.key});

  @override
  _CanceledFailedProjectsState createState() => _CanceledFailedProjectsState();
}

class _CanceledFailedProjectsState extends State<CanceledFailedProjects> {
  List<Map<String, dynamic>> _projects = [];
  String? walletAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final savedWallet = prefs.getString('walletAddress');

    if (savedWallet == null) {
      print("❌ No wallet address found.");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      walletAddress = savedWallet;
    });

    print('🧾 Logged-in Wallet Address: $walletAddress');

    final blockchainService = BlockchainService();
    final myProjects =
        await blockchainService.fetchOrganizationProjects(walletAddress!);

    List<Map<String, dynamic>> filtered = [];

    for (var project in myProjects) {
      final id = project['id'];
      if (id == null) {
        print("⚠️ Skipping project with missing ID: $project");
        continue;
      }

      final projectId = id.toString();
      bool isCanceled = await _isProjectCanceled(projectId);
      bool hasVoting = await blockchainService.hasExistingVoting(id);

      String status = await _getProjectState(project);

      print("🔍 Checking Project ID: $projectId");
      print("- Name: ${project['name']}");
      print("- Status: $status");
      print("- IsCanceled: $isCanceled");
      print("- Has Existing Voting: $hasVoting");

      if (!hasVoting && (status == 'failed' || isCanceled)) {
        print("✅ Adding project ID $projectId to filtered list");

        filtered.add({
          'id': id,
          'name': project['name'] ?? 'Unnamed Project',
          'organization': walletAddress,
          'status': isCanceled ? 'canceled' : status,
          'progress': (project['donatedAmount'] ?? 0.0) /
              ((project['totalAmount'] ?? 1.0) == 0
                  ? 1.0
                  : project['totalAmount']),
          'description': project['description'],
          'startDate': project['startDate'],
          'endDate': project['endDate'],
          'totalAmount': project['totalAmount'],
          'projectType': project['projectType'],
          'donatedAmount': project['donatedAmount'],
        });
      }
    }

    setState(() {
      _projects = filtered;
      _isLoading = false;
    });

    print("✅ Filtered Projects Count: ${_projects.length}");
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();

    DateTime startDate = project['startDate'] != null
        ? (project['startDate'] is DateTime
            ? project['startDate']
            : DateTime.parse(project['startDate']))
        : now;

    DateTime endDate = project['endDate'] != null
        ? (project['endDate'] is DateTime
            ? project['endDate']
            : DateTime.parse(project['endDate']))
        : now;

    double totalAmount = (project['totalAmount'] ?? 0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming";
    } else if (donatedAmount >= totalAmount) {
      return "completed";
    } else if (now.isAfter(endDate)) {
      return "failed";
    } else {
      return "active";
    }
  }

  Future<bool> _isProjectCanceled(String projectId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data != null && data['isCanceled'] == true;
      }
    } catch (e) {
      print("❌ Error checking if project is canceled: $e");
    }

    return false;
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final status = project['status'];
    final color = status == 'failed' ? Colors.red : Colors.orange;
    final progress = '${(project['progress'] * 100).toStringAsFixed(0)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetails(
                projectName: project['name'],
                description: project['description'],
                startDate: project['startDate'].toString(),
                deadline: project['endDate'].toString(),
                totalAmount: project['totalAmount'],
                projectType: project['projectType'],
                projectCreatorWallet: project['organization'] ?? '',
                donatedAmount: project['donatedAmount'],
                projectId: project['id'],
                progress: project['progress'],
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      project['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(
                      width: 10), // Add spacing between text and badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: ${project['totalAmount']} ETH',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: project['progress'],
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Ended and failed Projects',
          style: TextStyle(color:const Color.fromRGBO(24, 71, 137, 1)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color:const Color.fromRGBO(24, 71, 137, 1)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: _projects.isEmpty
                  ? Center(
                      child: Text(
                        'No canceled or failed projects found',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _projects.length,
                      itemBuilder: (context, index) {
                        return _buildProjectCard(_projects[index]);
                      },
                    ),
            ),
    );
  }
}
