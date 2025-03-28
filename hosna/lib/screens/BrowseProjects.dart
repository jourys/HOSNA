import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _getUserType();
    _fetchProjects();
 
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

      for (int i = 0; i < projectCount; i++) {
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
  bool isCanceled = await _isProjectCanceled(projectId); // Await the async call

  if (isCanceled) {
    print("This project is canceled.");
    return "canceled";
  } else {
    print("This project is active.");
  }

  // Handle startDate (could be DateTime, String, or null)
  DateTime startDate = project['startDate'] != null
      ? (project['startDate'] is DateTime
          ? project['startDate']
          : DateTime.parse(project['startDate']))
      : DateTime.now(); // Use current time if startDate is null

  // Handle endDate (could be DateTime, String, or null)
  DateTime endDate = project['endDate'] != null
      ? (project['endDate'] is DateTime
          ? project['endDate']
          : DateTime.parse(project['endDate']))
      : DateTime.now(); // Use current time if endDate is null

  // Get totalAmount and donatedAmount, handle null or invalid values
  double totalAmount = (project['totalAmount'] ?? 0).toDouble();
  double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

  if (now.isBefore(startDate)) {
    return "upcoming"; // Project is not started yet
  } else if (donatedAmount >= totalAmount) {
    return "in-progress"; // Project reached the goal
  } else {
    if (now.isAfter(endDate)) {
      return "failed"; // Project failed to reach the target
    } else {
      return "active"; // Project is ongoing and goal is not reached yet
    }
  }
}

Future<bool> _isProjectCanceled(String projectId) async {
  try {
    // Fetch the project document from Firestore using the projectId
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();

    // Check if the document exists
    if (doc.exists) {
      // Retrieve the 'isCanceled' field and return true or false
      bool isCanceled = doc['isCanceled'] ?? false;
      return isCanceled; // Return true if canceled, false otherwise
    } else {
      print("Project not found");
      return false; // If the project does not exist, return false
    }
  } catch (e) {
    print("Error fetching project state: $e");
    return false; // Return false in case of an error
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
      case "completed":
        return Colors.blue;
        case "canceled":
      return Colors.orange; 
      default:
        return Colors.grey;
    }
  }

  double weiToEth(BigInt wei) {
    return (wei / BigInt.from(10).pow(18));
  }@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Browse Projects'),
      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: _fetchProjects,
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
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
                          maxHeight: MediaQuery.of(context).size.height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                                          type == 'All' ? null : type;
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
        ),
        if (_selectedProjectType != null || _showMyProjects)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _getFilteredProjects().isEmpty
                  ? Center(child: Text('No projects found.'))
                  : SingleChildScrollView(
                      child: Column(
                        children: _getFilteredProjects().map((project) {
                          // Wrap the project state fetching with FutureBuilder
                          return FutureBuilder<String>(
                            future: _getProjectState(project),
                            builder: (context, snapshot) {
                              // Handle loading, error, and data states
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
)
;
                              } else if (snapshot.hasError) {
                                return Text('Error: ${snapshot.error}');
                              } else if (snapshot.hasData) {
                                String projectState = snapshot.data!;
                                Color stateColor = _getStateColor(projectState);

                                double totalAmount = project['totalAmount'] ?? 0.0;
                                double donatedAmount = project['donatedAmount'] ?? 0.0;

                                double progress = (donatedAmount /
                                    (totalAmount == 0 ? 1 : totalAmount));

                                return Card(
                                  margin: EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 16),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProjectDetails(
                                            projectName: project['name'],
                                            description: project['description'],
                                            startDate:
                                                project['startDate'].toString(),
                                            deadline: project['endDate'].toString(),
                                            totalAmount: project['totalAmount'],
                                            projectType: project['projectType'],
                                            projectCreatorWallet:
                                                project['organization'] ?? '',
                                            donatedAmount: project['donatedAmount'],
                                            projectId: project['id'],
                                            progress: progress,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project['name'],
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            project['description'],
                                            style:
                                                TextStyle(color: Colors.grey[600]),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Posted by: ${project['organization']}',
                                            style:
                                                TextStyle(color: Colors.grey[600]),
                                          ),
                                          SizedBox(height: 16),
                                          LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    stateColor),
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${(progress * 100).toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                    color: Colors.grey[600]),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      stateColor.withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  projectState,
                                                  style: TextStyle(
                                                      color: stateColor,
                                                      fontWeight: FontWeight.bold),
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
