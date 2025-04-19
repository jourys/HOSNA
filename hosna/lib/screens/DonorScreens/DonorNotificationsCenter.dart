import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

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
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print("🔍 Loading notifications...");
      print("🔍 Wallet address: ${widget.walletAddress}");

      if (widget.walletAddress.isEmpty) {
        print("❌ No wallet address found");
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get all notifications
      List<Map<String, dynamic>> notifications = [];

      // 1. First load voting notifications
      await _loadVotingNotifications(notifications);
      
      // 2. Then load status change notifications
      await _loadStatusChangeNotifications(notifications);

      // Sort notifications by timestamp (newest first)
      notifications.sort((a, b) {
        final DateTime aTime = a['timestamp'] ?? DateTime.now();
        final DateTime bTime = b['timestamp'] ?? DateTime.now();
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }

      print("✅ All notifications loaded successfully!");
      print("📊 Total notifications: ${notifications.length}");
    } catch (e) {
      print("❌ Error loading notifications: $e");
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

  Future<void> _loadVotingNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      // Get all voting sessions
      final votingSessions = await _blockchainService.getAllVotingSessions();
      print("📊 Found ${votingSessions.length} voting sessions");

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
    } catch (e) {
      print("❌ Error loading voting notifications: $e");
    }
  }

  Future<void> _loadStatusChangeNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      // Query status change notifications for this donor
      final statusChangeSnapshot = await FirebaseFirestore.instance
          .collection('donor_notifications')
          .where('donorAddress', isEqualTo: widget.walletAddress)
          .where('type', isEqualTo: 'status_change')
          .orderBy('timestamp', descending: true)
          .get();

      print("📊 Found ${statusChangeSnapshot.docs.length} status change notifications");

      // Process status change notifications
      for (var doc in statusChangeSnapshot.docs) {
        final data = doc.data();

        // Check if this notification has already been read by this donor
        final readStatusRef = FirebaseFirestore.instance
            .collection('notification_read_status')
            .doc('${widget.walletAddress}_${doc.id}');
            
        final readStatusDoc = await readStatusRef.get();
        final bool isRead = readStatusDoc.exists && readStatusDoc.data()?['isRead'] == true;
        
        notifications.add({
          'id': doc.id,
          'type': 'status_change',
          'title': 'Project Status Update',
          'message': data['message'] ?? 'Project status has changed',
          'projectId': data['projectId'],
          'projectName': data['projectName'] ?? 'Unknown Project',
          'status': data['status'],
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'isRead': isRead,
          'readStatusRef': readStatusRef,
        });
      }
      
      // Query global voting notifications (no donorAddress field)
      final globalVotingSnapshot = await FirebaseFirestore.instance
          .collection('donor_notifications')
          .where('type', isEqualTo: 'voting_status')
          .orderBy('timestamp', descending: true)
          .get();
          
      print("📊 Found ${globalVotingSnapshot.docs.length} global voting notifications");
      
      // Process global voting notifications
      for (var doc in globalVotingSnapshot.docs) {
        final data = doc.data();
        
        // Check if this notification has already been read by this donor
        final readStatusRef = FirebaseFirestore.instance
            .collection('notification_read_status')
            .doc('${widget.walletAddress}_${doc.id}');
            
        final readStatusDoc = await readStatusRef.get();
        final bool isRead = readStatusDoc.exists && readStatusDoc.data()?['isRead'] == true;
        
        notifications.add({
          'id': doc.id,
          'type': 'voting_global',
          'title': 'Voting Announcement',
          'message': data['message'] ?? 'A new voting has been initiated',
          'projectName': data['projectName'] ?? 'Project',
          'status': data['status'] ?? 'voting',
          'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
          'isRead': isRead,
          'readStatusRef': readStatusRef,
        });
      }
    } catch (e) {
      print("❌ Error loading notifications: $e");
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('donor_notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print("❌ Error marking notification as read: $e");
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
                    onPressed: _loadNotifications,
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
                            return _buildNotificationCard(notification);
                          },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final String type = notification['type'];
    
    if (type == 'voting') {
      return _buildVotingNotificationCard(notification);
    } else if (type == 'status_change') {
      return _buildStatusChangeNotificationCard(notification);
    } else if (type == 'voting_global') {
      return _buildGlobalVotingNotificationCard(notification);
    }
    
    // Fallback for unknown notification types
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text('Unknown Notification'),
        subtitle: Text('Unrecognized notification type'),
      ),
    );
  }

  Widget _buildVotingNotificationCard(Map<String, dynamic> notification) {
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
          // TODO: Navigate to voting page
        },
      ),
    );
  }

  Widget _buildStatusChangeNotificationCard(Map<String, dynamic> notification) {
    // Determine icon based on status
    IconData statusIcon;
    Color statusColor;
    
    switch (notification['status']) {
      case 'voting':
        statusIcon = Icons.how_to_vote;
        statusColor = Colors.blue;
        break;
      case 'ended':
        statusIcon = Icons.event_busy;
        statusColor = Colors.grey;
        break;
      case 'in-progress':
        statusIcon = Icons.engineering;
        statusColor = Colors.purple;
        break;
      case 'completed':
        statusIcon = Icons.check_circle;
        statusColor = Color.fromRGBO(24, 71, 137, 1);
        break;
      default:
        statusIcon = Icons.info;
        statusColor = Colors.orange;
    }
    
    // Format timestamp
    String timeAgo = '';
    if (notification['timestamp'] != null) {
      timeAgo = timeago.format(notification['timestamp']);
    }
    
    final bool isRead = notification['isRead'] ?? false;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead 
            ? BorderSide.none 
            : BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 1),
      ),
      color: isRead ? Colors.white : Colors.white,
      child: ListTile(
        leading: Icon(
          statusIcon,
          color: statusColor,
          size: 32,
        ),
        title: Text(
          'Project Status Update',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'],
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: () {
          // Mark notification as read
          if (!isRead && notification['id'] != null) {
            _markAsRead(notification['id']);
            
            // Update UI immediately
            setState(() {
              notification['isRead'] = true;
            });
          }
          
          // TODO: Navigate to project details
        },
      ),
    );
  }

  Widget _buildGlobalVotingNotificationCard(Map<String, dynamic> notification) {
    // Format timestamp
    String timeAgo = '';
    if (notification['timestamp'] != null) {
      timeAgo = timeago.format(notification['timestamp']);
    }
    
    final bool isRead = notification['isRead'] ?? false;
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRead 
            ? BorderSide.none 
            : BorderSide(color: Colors.blue, width: 1),
      ),
      color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
      child: ListTile(
        leading: Stack(
          children: [
            Icon(
              Icons.campaign,
              color: Colors.blue,
              size: 32,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: Icon(
                  Icons.how_to_vote,
                  color: Colors.blue,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
        title: Text(
          notification['title'],
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification['message'],
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        onTap: () {
          // Mark notification as read for this donor
          if (!isRead && notification['readStatusRef'] != null) {
            notification['readStatusRef'].set({
              'isRead': true,
              'readAt': FieldValue.serverTimestamp(),
              'donorAddress': widget.walletAddress,
              'notificationId': notification['id'],
            }, SetOptions(merge: true));
            
            // Update UI immediately
            setState(() {
              notification['isRead'] = true;
            });
          }
          
          // TODO: Navigate to voting page if needed
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    print("Notifications page disposed");
  }
}
