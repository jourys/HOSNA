import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatefulWidget {
  final String walletAddress;
  const NotificationsPage({super.key, required this.walletAddress});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final BlockchainService _blockchainService = BlockchainService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("Initializing NotificationsPage with wallet: ${widget.walletAddress}");
    if (widget.walletAddress.isEmpty) {
      print("⚠️ Warning: Empty wallet address provided");
    }
    _loadVotingNotifications();
  }

  Future<void> _loadVotingNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("🔍 Loading voting notifications...");
      print("🔍 Wallet address: ${widget.walletAddress}");

      if (widget.walletAddress.isEmpty) {
        print("❌ No wallet address found");
        return;
      }

      // Get all voting sessions
      final votingSessions = await _blockchainService.getAllVotingSessions();
      print("📊 Found ${votingSessions.length} voting sessions");

      List<Map<String, dynamic>> notifications = [];

      for (var session in votingSessions) {
        final projectId = session['projectId'];
        
        // Check if donor has donated to this project
        final hasDonated = await _blockchainService.hasDonatedToProject(projectId, widget.walletAddress);
        print("📊 Donor ${widget.walletAddress} has donated to project $projectId: $hasDonated");
        
        if (hasDonated) {
          final projectDetails = await _blockchainService.getProjectDetails(projectId);
          
          if (projectDetails.isNotEmpty) {
            notifications.add({
              'type': 'voting',
              'title': 'Voting Available',
              'message': 'Vote on what to do with funds from "${projectDetails['name']}"',
              'projectId': projectId,
              'timestamp': DateTime.now(),
              'projectName': projectDetails['name'],
              'hasVoted': await _blockchainService.hasDonorVoted(projectId, widget.walletAddress),
              'startTime': session['startTime'],
              'endTime': session['endTime'],
              'status': session['status'],
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }

      print("✅ Voting notifications loaded successfully!");
      print("📊 Total notifications: ${notifications.length}");
    } catch (e) {
      print("❌ Error loading voting notifications: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Color.fromRGBO(24, 71, 137, 1),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                "Notifications",
                style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadVotingNotifications,
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty
                      ? Center(
                child: Text(
                            'No notifications',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return Card(
                              margin: EdgeInsets.only(bottom: 16),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.how_to_vote,
                                  color: Color.fromRGBO(24, 71, 137, 1),
                                  size: 32,
                                ),
                                title: Text(
                                  'Voting Available',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${notification['projectName']} needs your vote',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    FutureBuilder<bool>(
                                      future: _blockchainService.hasDonorVoted(
                                        notification['projectId'],
                                        widget.walletAddress,
                                      ),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData && snapshot.data == true) {
                                          return Text(
                                            'You have already voted',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                            ),
                                          );
                                        }
                                        return SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DonorVoting(
                                        projectId: notification['projectId'],
                                        walletAddress: widget.walletAddress,
                                        projectName: notification['projectName'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    print("Notifications page disposed");
  }
}
