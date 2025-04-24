import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/ProfileScreenCharity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/ProjectDetails.dart';
import 'package:hosna/screens/CharityScreens/DraftsPage.dart';
import 'package:hosna/screens/CharityScreens/CanceledFailedProjects.dart';
import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

import 'package:hosna/screens/NotificationService.dart';

import 'package:hosna/screens/CharityScreens/CharityNotificationsCenter.dart';

class CharityEmployeeHomePage extends StatefulWidget {
  const CharityEmployeeHomePage({super.key});

  @override
  _CharityEmployeeHomePageState createState() =>
      _CharityEmployeeHomePageState();
}

class _CharityEmployeeHomePageState extends State<CharityEmployeeHomePage> {
  String _organizationName = '';
  List<Map<String, dynamic>> _projects = [];
  String? walletAddress;
  @override
  void initState() {
    super.initState();
    _loadWalletAndProjects();
    _loadOrganizationData();
    printUserType();
    _checkProjectStates();
  }

  Future<void> printUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userType = prefs.getInt('userType'); // 0 = Donor, 1 = Charity

    if (userType != null) {
      if (userType == 0) {
        print("User Type: Donor");
      } else if (userType == 1) {
        print("User Type: Charity Employee");
      }
    } else {
      print("No user type found in SharedPreferences");
    }
  }

  Future<void> _loadWalletAndProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWallet = prefs.getString('walletAddress');

    if (savedWallet == null) {
      print("❌ No wallet address found.");
      return;
    }

    setState(() {
      walletAddress = savedWallet;
    });

    print('🧾 Logged-in Wallet Address: $walletAddress');

    // ✅ Fetch projects created by this wallet from blockchain
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

      // Get project status from blockchain data
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
      } else {
        print("⛔ Not eligible — Reason(s): "
            "${hasVoting ? 'Already has voting. ' : ''}"
            "${(status != 'failed' && !isCanceled) ? 'Not failed/canceled. ' : ''}");
      }
    }

    setState(() {
      _projects = filtered;
    });

    print("✅ Filtered Projects Count: ${_projects.length}");
    await _checkProjectStates();
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();

    // Handle startDate (could be DateTime, String, or null)
    DateTime startDate = project['startDate'] != null
        ? (project['startDate'] is DateTime
            ? project['startDate']
            : DateTime.parse(project['startDate']))
        : now;

    // Handle endDate (could be DateTime, String, or null)
    DateTime endDate = project['endDate'] != null
        ? (project['endDate'] is DateTime
            ? project['endDate']
            : DateTime.parse(project['endDate']))
        : now;

    // Get totalAmount and donatedAmount, handle null or invalid values
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

  Future<void> _loadOrganizationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedWallet = prefs.getString('walletAddress');

      if (savedWallet == null) {
        print("❌ No wallet address found.");
        return;
      }

      final blockchainService = BlockchainService();
      final contract = await _loadContract();
      final function = contract.function('getCharity');

      // Create a new Web3Client instance
      final web3Client = Web3Client(
        'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac',
        http.Client(),
      );

      final result = await web3Client.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(savedWallet)],
      );

      if (result.isNotEmpty && result[0] != null) {
        setState(() {
          _organizationName = result[0].toString();
          print("✅ Organization name loaded: $_organizationName");
        });
      }
    } catch (e) {
      print("❌ Error loading organization data: $e");
    }
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
      {
        "inputs": [
          {"internalType": "address", "name": "_wallet", "type": "address"}
        ],
        "name": "getCharity",
        "outputs": [
          {"internalType": "string", "name": "name", "type": "string"},
          {"internalType": "string", "name": "email", "type": "string"},
          {"internalType": "string", "name": "phone", "type": "string"},
          {"internalType": "string", "name": "licenseNumber", "type": "string"},
          {"internalType": "string", "name": "city", "type": "string"},
          {"internalType": "string", "name": "description", "type": "string"},
          {"internalType": "string", "name": "website", "type": "string"},
          {"internalType": "string", "name": "establishmentDate", "type": "string"}
        ],
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    return DeployedContract(
      ContractAbi.fromJson(contractAbi, 'CharityRegistration'),
      EthereumAddress.fromHex('0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 20),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Day, ${_organizationName}!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // IconButton(

                      //   icon: const Icon(

                      //     Icons.notifications,

                      //     color: Colors.white,

                      //     size: 30,

                      //   ),
                      //   onPressed: () {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //           builder: (context) => CharityNotificationsPage(),

                      //       ),
                      //     );
                      //   },
                      // ),
                      // SizedBox(width: 10),

                      SizedBox(
                        width: 100,
                        height: 50,
                        child: IconButton(
                          icon: const Icon(Icons.account_circle,
                              size: 85, color: Colors.white),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ProfileScreenCharity()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Projects Awaiting section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header with arrow
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Projects Awaiting You To Start Voting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(24, 71, 137, 1),
                              ),
                            ),
                          ),
                        ),

                        // Projects list
                        ..._projects.take(2).map((project) {
                          final status = project['status'];
                          final color = status == 'failed'
                              ? Colors.red
                              : (status == 'canceled'
                                  ? Colors.orange
                                  : Colors.blue);

                          return _buildProjectCard(
                            project['name'],
                            status[0].toUpperCase() + status.substring(1),
                            color,
                            '${(project['progress'] * 100).toStringAsFixed(0)}%',
                          );
                        }).toList(),
                        if (_projects.length > 2)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CanceledFailedProjects(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Color.fromRGBO(24, 71, 137, 1),
                              ),
                              label: const Text(
                                'See All',
                                style: TextStyle(
                                  color: Color.fromRGBO(24, 71, 137, 1),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(right: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Draft Projects section
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header with arrow
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Draft Projects',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(24, 71, 137, 1),
                              ),
                            ),
                          ),
                        ),

                        // Draft projects list
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadDrafts(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return Center(
                                  child: Text('Error loading drafts'));
                            }

                            final drafts = snapshot.data ?? [];

                            if (drafts.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No draft projects available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...drafts
                                    .take(2)
                                    .map((draft) => _buildDraftCard(draft))
                                    .toList(),
                                if (drafts.length > 2)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 8.0, right: 16.0),
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => DraftsPage(
                                                  walletAddress: walletAddress),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Color.fromRGBO(24, 71, 137, 1),
                                        ),
                                        label: const Text(
                                          'See All',
                                          style: TextStyle(
                                            color:
                                                Color.fromRGBO(24, 71, 137, 1),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
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

  Widget _buildProjectCard(
      String title, String status, Color statusColor, String progress) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          // Find the project in _projects list
          try {
            final project = _projects.firstWhere(
              (p) => p['name'] == title,
            );

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
          } catch (e) {
            print("❌ Project not found: $title");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: Project details not found')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Await the start of voting',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: double.parse(progress.replaceAll('%', '')) / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () {
          if (walletAddress == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: Wallet address not found')),
            );
            return;
          }

          // Navigate to DraftsPage with the specific draft
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DraftsPage(
                walletAddress: walletAddress!,
                initialDraft:
                    draft, // Pass the specific draft to show its details
              ),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                draft['name'] ?? 'Untitled Project',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Amount: ${draft['totalAmount']} ETH',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadDrafts() async {
    if (walletAddress == null) {
      print("❌ No wallet address found for loading drafts");
      return [];
    }

    final prefs = await SharedPreferences.getInstance();
    final userDraftsKey = 'drafts_$walletAddress';
    final drafts = prefs.getStringList(userDraftsKey) ?? [];

    print("📝 Found ${drafts.length} drafts for wallet: $walletAddress");

    return drafts.map((draft) {
      try {
        return jsonDecode(draft) as Map<String, dynamic>;
      } catch (e) {
        print("❌ Error decoding draft: $e");
        return <String, dynamic>{};
      }
    }).toList();
  }

  Widget _buildNavItem(IconData icon, String label, bool isSelected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color:
              isSelected ? const Color.fromRGBO(24, 71, 137, 1) : Colors.grey,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color:
                isSelected ? const Color.fromRGBO(24, 71, 137, 1) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _checkProjectStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedWallet = prefs.getString('walletAddress');

      if (savedWallet == null) {
        print("❌ No wallet address found for checking project states");

        return;
      }

      // Get organization's projects

      final blockchainService = BlockchainService();

      final myProjects =
          await blockchainService.fetchOrganizationProjects(savedWallet);

      // Process each project

      for (var project in myProjects) {
        final projectId = project['id'].toString();

        // Get current project details from Firestore

        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();

        if (!projectDoc.exists) continue;

        final data = projectDoc.data() as Map<String, dynamic>;

        // Check project state

        final bool isCanceled = data['isCanceled'] ?? false;

        final bool isCompleted =
            project['donatedAmount'] >= project['totalAmount'];

        final bool isEnded = DateTime.now().isAfter(project['endDate']);

        final bool votingInitiated = data['votingInitiated'] ?? false;

        final bool hasVoting =
            await blockchainService.hasExistingVoting(project['id']);

        final bool votingEnded = hasVoting &&
            DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(
                (data['votingEndDate'] ?? 0) * 1000));

        // Determine current state

        String currentState;

        if (isCanceled) {
          currentState = votingInitiated ? "voting" : "canceled";

          if (votingEnded) currentState = "ended";
        } else if (isCompleted) {
          currentState = "in-progress"; // Project funded successfully
        } else if (isEnded) {
          currentState = "ended";
        } else {
          currentState = "active";
        }

        // Get previous state

        String previousState = data['currentState'] ?? 'active';

        print(
            "Project ${project['name']} - Current state: $currentState, Previous state: $previousState");

        // Only handle state changes

        if (currentState != previousState) {
          print(
              "🔄 Project state changed from $previousState to $currentState for project ${project['name']}");

          // Update current state in Firestore

          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .update({'currentState': currentState});

          // Create a notification for charity employee based on specific state changes (R1 and R2)

          if ((currentState == "in-progress" &&
                  previousState ==
                      "active") || // R1: Project funded -> in-progress

              (currentState == "ended" && previousState == "voting")) {
            // R2: Voting ended -> ended

            try {
              // Create a unique notification ID

              final notificationId =
                  'charity_${projectId}_${currentState}_${DateTime.now().millisecondsSinceEpoch}';

              // Create notification in Firestore

              await FirebaseFirestore.instance
                  .collection('charity_notifications')
                  .doc(notificationId)
                  .set({
                'charityAddress': savedWallet,
                'projectId': projectId,
                'projectName': project['name'] ?? 'Unknown Project',
                'message': _getStatusChangeMessage(
                    currentState, project['name'] ?? 'Unknown Project'),
                'type': 'status_change',
                'status': currentState,
                'timestamp': FieldValue.serverTimestamp(),
                'isRead': false,
              });

              print(
                  "✅ Notification created for charity: $savedWallet about project state change to $currentState");
            } catch (e) {
              print("❌ Error creating notification: $e");
            }
          }
        }
      }

      print("✅ Completed checking all project states");
    } catch (e) {
      print("❌ Error checking project states: $e");
    }
  }

  String _getStatusChangeMessage(String status, String projectName) {
    switch (status) {
      case 'in-progress':
        return 'Project "$projectName" has been fully funded and is now in progress!';

      case 'ended':
        return 'The voting period for project "$projectName" has ended.';

      default:
        return 'Project "$projectName" status has changed to $status.';
    }
  }
}
