import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

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
    setState(() {
      _isLoading = true;
    });

    try {
      final projectCount = await _blockchainService.getProjectCount();
      List<Map<String, dynamic>> projects = [];

      for (int i = 0; i < projectCount; i++) {
        final project = await _blockchainService.getProjectDetails(i);
        projects.add(project);
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

    return filteredProjects;
  }

  void _resetFilters() {
    setState(() {
      _selectedProjectType = null;
      _searchQuery = '';
    });
  }

  @override
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
          if (_selectedProjectType != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Chip(
                    label: Text('Filter: $_selectedProjectType'),
                    onDeleted: () {
                      setState(() {
                        _selectedProjectType = null;
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
                          children: _getFilteredProjects()
                              .map((project) => Card(
                                    margin: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    child: ListTile(
                                      title: Text(
                                        project['name'],
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(project['description']),
                                          SizedBox(height: 5),
                                          Text(
                                            'Posted by: ${project['organization']}',
                                            style: TextStyle(
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                projectDetails(
                                              projectName: project['name'],
                                              description:
                                                  project['description'],
                                              startDate: project['startDate']
                                                  .toString(),
                                              deadline:
                                                  project['endDate'].toString(),
                                              totalAmount:
                                                  project['totalAmount']
                                                      .toString(),
                                              projectType:
                                                  project['projectType'],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
