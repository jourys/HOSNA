import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

class VotingProjectsPage extends StatefulWidget {
  const VotingProjectsPage({super.key});

  @override
  State<VotingProjectsPage> createState() => _VotingProjectsPageState();
}

class _VotingProjectsPageState extends State<VotingProjectsPage> {
  List<Map<String, dynamic>> votingProjects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVotingProjects();
  }

  Future<void> _loadVotingProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('walletAddress');
    if (address == null) return;

    final projects = await DonorServices().getEligibleVotingProjects(address);
    setState(() {
      votingProjects = projects;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
        elevation: 0,
        title: const Text(
          'Voting Projects',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : votingProjects.isEmpty
              ? const Center(child: Text('No projects need your vote'))
              : ListView.builder(
                  itemCount: votingProjects.length,
                  itemBuilder: (context, index) {
                    final project = votingProjects[index];
                    final votingDeadline =
                        project['votingDeadline'] ?? 'Unknown';
                    final projectType = project['projectType'] ?? 'Unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(
                          project['name'] ?? 'Unnamed Project',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Voting Deadline: $votingDeadline',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Project Type: $projectType',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetails(
                                projectId: project['id'],
                                projectName:
                                    project['name'] ?? 'Unnamed Project',
                                description: project['description'] ??
                                    'No description available',
                                totalAmount: project['totalAmount'] ?? 0.0,
                                projectType:
                                    project['projectType'] ?? 'Unknown',
                                projectCreatorWallet:
                                    project['projectCreatorWallet'] ?? '',
                                donatedAmount: project['donatedAmount'] ?? 0.0,
                                progress: (project['totalAmount'] ?? 0) > 0
                                    ? (project['donatedAmount'] ?? 0) /
                                        project['totalAmount']
                                    : 0.0,
                                deadline:
                                    project['endDate']?.toString() ?? 'Unknown',
                                startDate: project['startDate']?.toString() ??
                                    'Unknown',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
