import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:web3dart/web3dart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';

class BrowseProjects extends StatefulWidget {
  final String walletAddress;
  const BrowseProjects({super.key, required this.walletAddress});

  @override
  _BrowseProjectsState createState() => _BrowseProjectsState();
}

class _BrowseProjectsState extends State<BrowseProjects> {
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedProjectType;
  int? userType;
  bool _showMyProjects = false;
  bool isCanceled = false; // Default value
  String projectState = "";
  bool isSidebarVisible = false; // To toggle the sidebar visibility
  late GetCharityByWallet _charityService;

  final List<String> _projectTypes = [
    'All',
    'Education',
    'Health',
    'Environment',
    'Food',
    'Religious',
    'Disaster Relief',
    'Other',
  ];
  bool Loading = true;

  @override
  void initState() {
    super.initState();
    _getUserType();

    // Simulate loading delay
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        Loading = false;
      });
    });
    _fetchProjects();
    _charityService = GetCharityByWallet();
  }

// Future<void> _loadProjectState(String projectId) async {
//   try {
//     DocumentSnapshot doc = await FirebaseFirestore.instance
//         .collection('projects')
//         .doc(projectId)
//         .get();

//     if (doc.exists) {
//       setState(() {
//         isCanceled = doc['isCanceled'] ?? false;
//         projectState = isCanceled ? "canceled" : _getProjectState(doc.data() as Map<String, dynamic>);
//       });
//     } else {
//       print("Document not found");
//     }
//   } catch (e) {
//     print("Error loading project state: $e");
//   }
// }

  // Method to load the wallet address from SharedPreferences
  Future<String?> _loadWalletAddress() async {
    print('Loading wallet address...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("Error: Wallet address not found. Please log in again.");
        return null;
      }

      print('Wallet address loaded successfully: $walletAddress');
      return walletAddress;
    } catch (e) {
      print("Error loading wallet address: $e");
      return null;
    }
  }

  Future<void> _getUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getInt('userType');
    });
    print("All keys: ${prefs.getKeys()}");
  }

  Future<void> _fetchProjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final projectCount = await _blockchainService.getProjectCount();
      print("🧮 Total Projects: $projectCount");

      List<Map<String, dynamic>> projects = [];

      for (int i = 0; i < projectCount; i++) {
        print("🔍 Fetching project ID: $i");
        try {
          final project = await _blockchainService.getProjectDetails(i);
          if (project.containsKey("error")) {
            print("⚠️ Skipping invalid project ID: $i");
            continue;
          }

          // ✅ Add the projectId manually for sorting
          project['projectId'] = i;

          print(
              "✅ Project fetched: ID ${project['projectId']} - ${project['name']}");
          projects.add(project);
        } catch (e) {
          print("❌ Error fetching project ID $i: $e");
        }
      }

      // 🔽 Sort by projectId descending
      projects.sort((a, b) {
        final int aId = a['projectId'] as int;
        final int bId = b['projectId'] as int;
        return bId.compareTo(aId); // Descending
      });

      print("📋 Sorted Projects:");
      for (var project in projects) {
        print(
            "➡️ Project ID: ${project['projectId']} | Name: ${project['name']}");
      }

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      print("🚨 Error in _fetchProjects: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredProjects() {
    List<Map<String, dynamic>> filteredProjects = _projects;

    if (_searchQuery.isNotEmpty) {
      filteredProjects = filteredProjects
          .where((project) =>
              project['name']
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              project['description']
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_selectedProjectType != null && _selectedProjectType != 'All') {
      filteredProjects = filteredProjects
          .where((project) => project['projectType'] == _selectedProjectType)
          .toList();
    }
    // Filter by "My Projects" (only for charity employees)
    if (_showMyProjects && userType == 1) {
      filteredProjects = filteredProjects
          .where((project) => project['organization'] == widget.walletAddress)
          .toList();
    }

    return filteredProjects;
  }

  void _resetFilters() {
    setState(() {
      _selectedProjectType = null;
      _searchQuery = '';
      _showMyProjects = false;
    });
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();
    String projectId = project['id'].toString(); // Ensure it's a String

    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      if (!doc.exists) {
        print("⚠️ Project not found. Creating default fields...");
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .set({
          'isCanceled': false,
          'isCompleted': false,
          'isEnded': false,
          'votingInitiated': false,
        });
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};

      bool isCanceled = data['isCanceled'] ?? false;
      bool isCompleted = data['isCompleted'] ?? false;
      bool isEnded = false;
      final votingId = data['votingId'];

      if (votingId != null) {
        final votingDocRef = FirebaseFirestore.instance
            .collection("votings")
            .doc(votingId.toString());

        final votingDoc = await votingDocRef.get();
        final votingData = votingDoc.data();

        if (votingDoc.exists) {
          isEnded = votingData?['IsEnded'] ?? false;
        }
      }
      bool votingInitiated = data['votingInitiated'] ?? false;

      // Determine projectState based on Firestore flags
      if (isEnded) {
        return "ended";
      }
      if (isCompleted) {
        return "completed";
      } else if (votingInitiated && (!isCompleted) && (!isEnded)) {
        return "voting";
      } else if (isCanceled && (!votingInitiated) && (!isEnded)) {
        return "canceled";
      }

      // Fallback to logic based on time and funding progress
      DateTime startDate = project['startDate'] != null
          ? (project['startDate'] is DateTime
              ? project['startDate']
              : DateTime.parse(project['startDate']))
          : DateTime.now();

      DateTime endDate = project['endDate'] != null
          ? (project['endDate'] is DateTime
              ? project['endDate']
              : DateTime.parse(project['endDate']))
          : DateTime.now();

      double totalAmount = (project['totalAmount'] ?? 0).toDouble();
      double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

      if (now.isBefore(startDate)) {
        return "upcoming";
      } else if (donatedAmount >= totalAmount) {
        return "in-progress";
      } else if (now.isAfter(endDate)) {
        return "failed";
      } else {
        return "active";
      }
    } catch (e) {
      print("❌ Error determining project state for ID $projectId: $e");
      return "unknown";
    }
  }

  Future<bool> _isProjectCanceled(String projectId) async {
    try {
      // Fetch the project document from Firestore
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      // Check if the document exists
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;

        // Check if the 'isCanceled' field exists in the document
        if (data != null && data.containsKey('isCanceled')) {
          return data['isCanceled'] == true;
        } else {
          print("⚠️ 'isCanceled' field not found, returning false by default.");
          return false;
        }
      } else {
        print("❌ Project not found.");
        return false;
      }
    } catch (e) {
      print("⚠️ Error fetching project state: $e");
      return false;
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "in-progress":
        return Colors.purple;
      case "voting":
        return Colors.blue;
      case "canceled":
        return Colors.orange;
      case "ended":
        return Colors.grey;
      case "completed":
        return Color.fromRGBO(24, 71, 137, 1);
      default:
        return Colors.grey;
    }
  }

  double weiToEth(BigInt wei) {
    return (wei / BigInt.from(10).pow(18));
  }

  @override
  Widget build(BuildContext context) {
    Color appBarBackgroundColor = Color.fromRGBO(24, 71, 137, 1);
    Color appBarTitleColor = Colors.white;

    if (userType != 0 && userType != 1) {
      appBarBackgroundColor = Colors.white;
      appBarTitleColor = Color.fromRGBO(24, 71, 137, 1);
    }

    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: isKeyboardVisible
          ? Colors.white // Use a different color when the keyboard is visible
          : (userType == 0 || userType == 1)
              ? const Color.fromRGBO(24, 71, 137, 1)
              : null,
      appBar: userType != 0 && userType != 1
          ? null
          : AppBar(
              automaticallyImplyLeading:
                  false, // Removes the default back arrow
              centerTitle: true, // Centers the title
              title: const Text(
                'Browse Projects',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 23,
                ),
              ),
              backgroundColor: appBarBackgroundColor,
              foregroundColor: appBarTitleColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchProjects,
                ),
              ],
            ),
//admin
      body: userType != 0 && userType != 1
          ? Container(
              color: Colors.white,
              child: Row(
                children: [
                  // Sidebar
                  Container(
                    width: 350,
                    child: Loading
                        ? Center(
                            child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ))
                        : AdminSidebar(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        // Search Bar and Filter Options
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        hintText: 'Search for a project name',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  IconButton(
                                    icon: Icon(Icons.filter_list),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (context) {
                                          return Container(
                                            padding: EdgeInsets.all(16),
                                            constraints: BoxConstraints(
                                              maxHeight: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.5,
                                            ),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Text(
                                                    'Filter by Project Type',
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                  if (userType == 1)
                                                    ListTile(
                                                      title:
                                                          Text('My Projects'),
                                                      onTap: () {
                                                        setState(() {
                                                          _showMyProjects =
                                                              true;
                                                          _selectedProjectType =
                                                              null;
                                                        });
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                  for (String type
                                                      in _projectTypes)
                                                    ListTile(
                                                      title: Text(type),
                                                      onTap: () {
                                                        setState(() {
                                                          _selectedProjectType =
                                                              type == 'All'
                                                                  ? null
                                                                  : type;
                                                        });
                                                        Navigator.pop(context);
                                                      },
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                              if (_selectedProjectType != null ||
                                  _showMyProjects)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Chip(
                                        label: Text(_showMyProjects
                                            ? 'Filter: My Projects'
                                            : 'Filter: $_selectedProjectType'),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedProjectType = null;
                                            _showMyProjects = false;
                                          });
                                        },
                                      ),
                                      SizedBox(width: 10),
                                      TextButton(
                                        onPressed: _resetFilters,
                                        child: Text('Reset Filters'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _getFilteredProjects().isEmpty
                                  ? Center(child: Text('No projects found.'))
                                  : SingleChildScrollView(
                                      child: Column(
                                        children: _getFilteredProjects()
                                            .map((project) {
                                          return FutureBuilder<String>(
                                            future: _getProjectState(project),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                );
                                              } else if (snapshot.hasError) {
                                                return Text(
                                                    'Error: ${snapshot.error}');
                                              } else if (snapshot.hasData) {
                                                String projectState =
                                                    snapshot.data!;
                                                Color stateColor =
                                                    _getStateColor(
                                                        projectState);

                                                double totalAmount =
                                                    project['totalAmount'] ??
                                                        0.0;
                                                double donatedAmount =
                                                    project['donatedAmount'] ??
                                                        0.0;

                                                double progress =
                                                    (donatedAmount /
                                                        (totalAmount == 0
                                                            ? 1
                                                            : totalAmount));

                                                return Card(
                                                  margin: EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 16),
                                                  child: InkWell(
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              ProjectDetails(
                                                            projectName:
                                                                project['name'],
                                                            description: project[
                                                                'description'],
                                                            startDate: project[
                                                                    'startDate']
                                                                .toString(),
                                                            deadline: project[
                                                                    'endDate']
                                                                .toString(),
                                                            totalAmount: project[
                                                                'totalAmount'],
                                                            projectType: project[
                                                                'projectType'],
                                                            projectCreatorWallet:
                                                                project['organization'] ??
                                                                    '',
                                                            donatedAmount: project[
                                                                'donatedAmount'],
                                                            projectId:
                                                                project['id'],
                                                            progress: progress,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16.0),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            project['name'],
                                                            style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            project[
                                                                'description'],
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600]),
                                                          ),
                                                          SizedBox(height: 8),
                                                          FutureBuilder<String>(
                                                            future: _charityService
                                                                .getCharityName(
                                                              EthereumAddress
                                                                  .fromHex(project[
                                                                      'organization']),
                                                            ),
                                                            builder: (context,
                                                                snapshot) {
                                                              if (snapshot
                                                                      .connectionState ==
                                                                  ConnectionState
                                                                      .waiting) {
                                                                return Text(
                                                                  'Posted by: loading...',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                              .grey[
                                                                          600]),
                                                                );
                                                              } else if (snapshot
                                                                      .hasError ||
                                                                  snapshot.data ==
                                                                      null) {
                                                                return Text(
                                                                  'Posted by: Unknown',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                              .grey[
                                                                          600]),
                                                                );
                                                              } else {
                                                                return Text(
                                                                  'Posted by: ${snapshot.data}',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                              .grey[
                                                                          600]),
                                                                );
                                                              }
                                                            },
                                                          ),
                                                          SizedBox(height: 16),
                                                          LinearProgressIndicator(
                                                            value: progress,
                                                            backgroundColor:
                                                                Colors
                                                                    .grey[200],
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                        Color>(
                                                                    stateColor),
                                                          ),
                                                          SizedBox(height: 8),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                '${(progress * 100).toStringAsFixed(0)}%',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600]),
                                                              ),
                                                              Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: stateColor
                                                                      .withOpacity(
                                                                          0.2),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                child: Text(
                                                                  projectState,
                                                                  style: TextStyle(
                                                                      color:
                                                                          stateColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                return Text(
                                                    'No data available');
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          //donors and charities
          : Container(
              margin: EdgeInsets.only(
                  top: 10, bottom: 0), // Ensure margins are non-negative
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Search and Filter for non-admin users
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search for a project name',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 10),
                            IconButton(
                              icon: Icon(Icons.filter_list),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return Container(
                                      padding: EdgeInsets.all(16),
                                      constraints: BoxConstraints(
                                        maxHeight:
                                            MediaQuery.of(context).size.height *
                                                0.5,
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            Text(
                                              'Filter by Project Type',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 10),
                                            if (userType == 1)
                                              ListTile(
                                                title: Text('My Projects'),
                                                onTap: () {
                                                  setState(() {
                                                    _showMyProjects = true;
                                                    _selectedProjectType = null;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                              ),
                                            for (String type in _projectTypes)
                                              ListTile(
                                                title: Text(type),
                                                onTap: () {
                                                  setState(() {
                                                    _selectedProjectType =
                                                        type == 'All'
                                                            ? null
                                                            : type;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        if (_selectedProjectType != null || _showMyProjects)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Chip(
                                  label: Text(_showMyProjects
                                      ? 'Filter: My Projects'
                                      : 'Filter: $_selectedProjectType'),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedProjectType = null;
                                      _showMyProjects = false;
                                    });
                                  },
                                ),
                                SizedBox(width: 10),
                                TextButton(
                                  onPressed: _resetFilters,
                                  child: Text('Reset Filters'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // List of Projects
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : _getFilteredProjects().isEmpty
                            ? Center(child: Text('No projects found.'))
                            : SingleChildScrollView(
                                child: GestureDetector(
                                  onTap: () {
                                    // Dismiss the keyboard when tapping outside
                                    FocusScope.of(context).unfocus();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom, // Adjust for keyboard
                                    ),
                                    child: Column(
                                      children:
                                          _getFilteredProjects().map((project) {
                                        return FutureBuilder<String>(
                                          future: _getProjectState(project),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              );
                                            } else if (snapshot.hasError) {
                                              return Text(
                                                  'Error: ${snapshot.error}');
                                            } else if (snapshot.hasData) {
                                              String projectState =
                                                  snapshot.data!;
                                              Color stateColor =
                                                  _getStateColor(projectState);

                                              double totalAmount =
                                                  project['totalAmount'] ?? 0.0;
                                              double donatedAmount =
                                                  project['donatedAmount'] ??
                                                      0.0;

                                              double progress = (donatedAmount /
                                                  (totalAmount == 0
                                                      ? 1
                                                      : totalAmount));

                                              return Card(
                                                margin: EdgeInsets.symmetric(
                                                    vertical: 8,
                                                    horizontal: 16),
                                                child: InkWell(
                                                  onTap: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ProjectDetails(
                                                          projectName:
                                                              project['name'],
                                                          description: project[
                                                              'description'],
                                                          startDate: project[
                                                                  'startDate']
                                                              .toString(),
                                                          deadline:
                                                              project['endDate']
                                                                  .toString(),
                                                          totalAmount: project[
                                                              'totalAmount'],
                                                          projectType: project[
                                                              'projectType'],
                                                          projectCreatorWallet:
                                                              project['organization'] ??
                                                                  '',
                                                          donatedAmount: project[
                                                              'donatedAmount'],
                                                          projectId:
                                                              project['id'],
                                                          progress: progress,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          project['name'],
                                                          style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        SizedBox(height: 8),
                                                        Text(
                                                          project[
                                                              'description'],
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .grey[600]),
                                                        ),
                                                        SizedBox(height: 8),
                                                        FutureBuilder<String>(
                                                          future: _charityService
                                                              .getCharityName(
                                                            EthereumAddress
                                                                .fromHex(project[
                                                                    'organization']),
                                                          ),
                                                          builder: (context,
                                                              snapshot) {
                                                            if (snapshot
                                                                    .connectionState ==
                                                                ConnectionState
                                                                    .waiting) {
                                                              return Text(
                                                                'Posted by: loading...',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600]),
                                                              );
                                                            } else if (snapshot
                                                                    .hasError ||
                                                                snapshot.data ==
                                                                    null) {
                                                              return Text(
                                                                'Posted by: Unknown',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600]),
                                                              );
                                                            } else {
                                                              return Text(
                                                                'Posted by: ${snapshot.data}',
                                                                style: TextStyle(
                                                                    color: Colors
                                                                            .grey[
                                                                        600]),
                                                              );
                                                            }
                                                          },
                                                        ),
                                                        SizedBox(height: 16),
                                                        LinearProgressIndicator(
                                                          value: progress,
                                                          backgroundColor:
                                                              Colors.grey[200],
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                      Color>(
                                                                  stateColor),
                                                        ),
                                                        SizedBox(height: 8),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              '${(progress * 100).toStringAsFixed(0)}%',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      600]),
                                                            ),
                                                            Container(
                                                              padding: EdgeInsets
                                                                  .symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: stateColor
                                                                    .withOpacity(
                                                                        0.2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              ),
                                                              child: Text(
                                                                projectState,
                                                                style: TextStyle(
                                                                    color:
                                                                        stateColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else {
                                              return Text('No data available');
                                            }
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}

class GetCharityByWallet {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';

  late Web3Client _web3Client;
  late EthereumAddress _contractAddress;
  late DeployedContract _contract;

  final String _abi = '''
[
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_wallet",
        "type": "address"
      }
    ],
    "name": "getCharity",
    "outputs": [
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "string", "name": "email", "type": "string" },
      { "internalType": "string", "name": "phone", "type": "string" },
      { "internalType": "string", "name": "licenseNumber", "type": "string" },
      { "internalType": "string", "name": "city", "type": "string" },
      { "internalType": "string", "name": "description", "type": "string" },
      { "internalType": "string", "name": "website", "type": "string" },
      { "internalType": "string", "name": "establishmentDate", "type": "string" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  GetCharityByWallet() {
    _web3Client = Web3Client(rpcUrl, Client());
    _contractAddress =
        EthereumAddress.fromHex("0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7");
    _loadContract();
  }

  Future<void> _loadContract() async {
    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, "CharityRegistration"),
      _contractAddress,
    );
  }

  Future<String> getCharityName(EthereumAddress walletAddress) async {
    final function = _contract.function('getCharity');
    final result = await _web3Client.call(
      contract: _contract,
      function: function,
      params: [walletAddress],
    );

    return result[0] as String; // Only return the name
  }
}
