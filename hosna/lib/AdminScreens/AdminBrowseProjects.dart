import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/AdminScreens/AdminLogin.dart';
import 'package:hosna/AdminScreens/AdminHomePage.dart';
import 'AdminSidebar.dart';

class AdminBrowseProjects extends StatefulWidget {
  const AdminBrowseProjects({super.key});

  @override
  _AdminBrowseProjectsState createState() => _AdminBrowseProjectsState();
}

// admin@gmail.com

class _AdminBrowseProjectsState extends State<AdminBrowseProjects> {
  bool isSidebarVisible = true;
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedProjectType = 'All';

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
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    try {
      final projectCount = await _blockchainService.getProjectCount();
      List<Map<String, dynamic>> projects = [];

      for (int i = 0; i < projectCount; i++) {
        final project = await _blockchainService.getProjectDetails(i);
        if (!project.containsKey("error")) {
          projects.add(project);
        }
      }

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching projects: $e");
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredProjects() {
    return _projects.where((project) {
      final matchesSearch = _searchQuery.isEmpty ||
          project['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          project['description']
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchesType = _selectedProjectType == 'All' ||
          project['projectType'] == _selectedProjectType;
      return matchesSearch && matchesType;
    }).toList();
  }

  String _getProjectState(Map<String, dynamic> project) {
    DateTime now = DateTime.now();

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
    double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // Change this to your desired color
        child: Row(
          children: [
            AdminSidebar(),
            // admin@gmail.com
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Browse Projects ', // Page title
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(
                            24, 71, 137, 1), // Customize the color
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon:
                          Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                      onPressed: () {
                        setState(() {
                          isSidebarVisible = !isSidebarVisible;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search projects',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery =
                                              ''; // Clear the search query
                                        });
                                      },
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    12.0), // Circular corners
                                borderSide: BorderSide(
                                  color: _searchQuery.isNotEmpty
                                      ? Color.fromRGBO(24, 71, 137,
                                          1) // Border color when not empty
                                      : Colors
                                          .grey, // Default border color when empty
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(
                                  color: _searchQuery.isNotEmpty
                                      ? Color.fromRGBO(24, 71, 137,
                                          1) // Border color when not empty
                                      : Colors
                                          .grey, // Default border color when empty
                                  width: 2.0,
                                ),
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(
                            Icons.filter_list,
                            color: _selectedProjectType != 'All'
                                ? Color.fromRGBO(24, 71, 137,
                                    1) // When selected type is not 'All'
                                : Colors.grey, // When selected type is 'All'
                          ),
                          onPressed: () async {
                            final String? newValue = await showDialog<String>(
                              context: context,
                              builder: (BuildContext context) {
                                return SimpleDialog(
                                  title: const Text('Select Project Type'),
                                  children: _projectTypes.map((type) {
                                    return SimpleDialogOption(
                                      onPressed: () {
                                        Navigator.pop(context, type);
                                      },
                                      child: Text(type),
                                    );
                                  }).toList(),
                                );
                              },
                            );

                            if (newValue != null) {
                              setState(() {
                                _selectedProjectType = newValue;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _getFilteredProjects().isEmpty
                            ? const Center(child: Text('No projects found.'))
                            : ListView.builder(
                                itemCount: _getFilteredProjects().length,
                                itemBuilder: (context, index) {
                                  final project = _getFilteredProjects()[index];
                                  final String state =
                                      _getProjectState(project);
                                  final Color stateColor =
                                      _getStateColor(state);
                                  final double progress =
                                      project['totalAmount'] > 0
                                          ? project['donatedAmount'] /
                                              project['totalAmount']
                                          : 0.0;
                                  return Card(
                                    margin: const EdgeInsets.all(8.0),
                                    color: Colors.grey[
                                        200], // Light grey background color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                      side: BorderSide(
                                        color: Color.fromRGBO(
                                            24, 71, 137, 1), // Border color
                                        width: 2,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.all(16.0),
                                      title: Text(
                                        project['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color.fromRGBO(24, 71, 137,
                                              1), // Project name color
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Posted by: ${project['organization'] ?? "Unknown"}',
                                            style: TextStyle(
                                              color: Colors.grey[
                                                  700], // Organization name color (dark grey)
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Text(project['description']),
                                          SizedBox(height: 5),
                                          LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 5,
                                            valueColor: AlwaysStoppedAnimation<
                                                    Color>(
                                                stateColor), // Set progress bar color to match the status color
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            state.toUpperCase(),
                                            style: TextStyle(
                                                color: stateColor,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          SizedBox(height: 10),
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              'Deadline: ${project['endDate'] != null ? (project['endDate'] is String ? DateTime.parse(project['endDate']).toLocal() : project['endDate']).toString().split(' ')[0] : "N/A"}',
                                              style: TextStyle(
                                                color: Colors
                                                    .red, // Deadline color (red)
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ProjectDetails(
                                            projectName: project['name'],
                                            description: project['description'],
                                            startDate:
                                                project['startDate'].toString(),
                                            deadline:
                                                project['endDate'].toString(),
                                            totalAmount: project['totalAmount'],
                                            projectType: project['projectType'],
                                            projectCreatorWallet:
                                                project['organization'] ?? '',
                                            donatedAmount:
                                                project['donatedAmount'],
                                            projectId: project['id'],
                                            progress: progress,
                                          ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
      BuildContext context, String title, VoidCallback onTap,
      {Color color = const Color.fromRGBO(24, 71, 137, 1)}) {
    return ListTile(
      title: Center(
        // Center the text
        child: Text(
          title,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSidebarButton({
    required String title,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: backgroundColor,
            side: BorderSide(
                color: borderColor, width: 2), // Set border thickness here
            padding: EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(
            title,
            style: TextStyle(
                color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
