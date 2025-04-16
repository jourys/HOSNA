import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

class EligibleVotingProjectsPage extends StatelessWidget {
  final List<Map<String, dynamic>> votingProjects;

  const EligibleVotingProjectsPage({super.key, required this.votingProjects});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
        title: const Text(
          'Projects Awaiting Your Vote',
          style: TextStyle(color: Colors.white), // 👈 white title text
        ),
        iconTheme: const IconThemeData(
            color: Colors.white), // Optional: white back icon
      ),
      body: votingProjects.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'You’ve already voted on all available projects.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: const Color.fromARGB(255, 0, 0, 0),
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: votingProjects.length,
              itemBuilder: (context, index) {
                final project = votingProjects[index];
                final progress = ((project['donatedAmount'] ?? 0.0) /
                        (project['totalAmount'] ?? 1.0) *
                        100)
                    .toStringAsFixed(1);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(project['name'] ?? 'Unnamed Project'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progress: $progress%'),
                        if (project['votingDeadline'] != null)
                          Text('Voting Deadline: ${project['votingDeadline']}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetails(
                            projectId: project['id'],
                            projectName: project['name'] ?? 'Unnamed Project',
                            description: project['description'] ?? '',
                            startDate: DateTime.now().toString(),
                            deadline: project['votingDeadline'] ??
                                DateTime.now().toString(),
                            totalAmount:
                                (project['totalAmount'] ?? 0.0).toDouble(),
                            projectType: project['projectType'] ?? 'Unknown',
                            projectCreatorWallet: project['organization'] ?? '',
                            donatedAmount:
                                (project['donatedAmount'] ?? 0.0).toDouble(),
                            progress: ((project['donatedAmount'] ?? 0.0) /
                                (project['totalAmount'] ?? 1.0)),
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
