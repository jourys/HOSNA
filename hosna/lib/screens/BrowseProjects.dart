import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
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
    _fetchProjects();
    // Simulate loading delay
    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        Loading = false;
      });
    });
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
      print("Total Projects: $projectCount");

      List<Map<String, dynamic>> projects = [];

      for (int i = 39; i < projectCount; i++) {
        try {
          final project = await _blockchainService.getProjectDetails(i);
          if (project.containsKey("error")) {
            print("Skipping invalid project ID: $i");
            continue; // Skip invalid projects
          }
          projects.add(project);
        } catch (e) {
          print("Error fetching project ID $i: $e");
        }
      }

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching projects: $e");
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
      await FirebaseFirestore.instance.collection('projects').doc(projectId).set({
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
      return "ended";}
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
      return  Color.fromRGBO(24, 71, 137, 1);
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

    return Scaffold(
      appBar: userType != 0 && userType != 1
          ? null
          : AppBar(
              title: Text('Browse Projects'),
              backgroundColor: appBarBackgroundColor,
              foregroundColor: appBarTitleColor,
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _fetchProjects,
                ),
              ],
            ),
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
                                                          Text(
                                                            'Posted by: ${project['organization']}',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .grey[600]),
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
          : Column(
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
                              child: Column(
                                children: _getFilteredProjects().map((project) {
                                  return FutureBuilder<String>(
                                    future: _getProjectState(project),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Text('Error: ${snapshot.error}');
                                      } else if (snapshot.hasData) {
                                        String projectState = snapshot.data!;
                                        Color stateColor =
                                            _getStateColor(projectState);

                                        double totalAmount =
                                            project['totalAmount'] ?? 0.0;
                                        double donatedAmount =
                                            project['donatedAmount'] ?? 0.0;

                                        double progress = (donatedAmount /
                                            (totalAmount == 0
                                                ? 1
                                                : totalAmount));

                                        return Card(
                                          margin: EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 16),
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ProjectDetails(
                                                    projectName:
                                                        project['name'],
                                                    description:
                                                        project['description'],
                                                    startDate:
                                                        project['startDate']
                                                            .toString(),
                                                    deadline: project['endDate']
                                                        .toString(),
                                                    totalAmount:
                                                        project['totalAmount'],
                                                    projectType:
                                                        project['projectType'],
                                                    projectCreatorWallet:
                                                        project['organization'] ??
                                                            '',
                                                    donatedAmount: project[
                                                        'donatedAmount'],
                                                    projectId: project['id'],
                                                    progress: progress,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    project['name'],
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    project['description'],
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Posted by: ${project['organization']}',
                                                    style: TextStyle(
                                                        color:
                                                            Colors.grey[600]),
                                                  ),
                                                  SizedBox(height: 16),
                                                  LinearProgressIndicator(
                                                    value: progress,
                                                    backgroundColor:
                                                        Colors.grey[200],
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(stateColor),
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
                                                                .grey[600]),
                                                      ),
                                                      Container(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: stateColor
                                                              .withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: Text(
                                                          projectState,
                                                          style: TextStyle(
                                                              color: stateColor,
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
              ],
            ),
    );
  }
}
