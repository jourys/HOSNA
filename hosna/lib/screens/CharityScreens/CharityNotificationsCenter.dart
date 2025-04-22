import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';

class CharityNotificationsPage extends StatefulWidget {
  @override
  _CharityNotificationsPageState createState() => _CharityNotificationsPageState();
}

class _CharityNotificationsPageState extends State<CharityNotificationsPage> {
  String? walletAddress;
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadWalletAndNotifications();
  }

  Future<void> _loadWalletAndNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');

      if (address == null || address.isEmpty) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      setState(() {
        walletAddress = address;
      });

      await _fetchNotifications();
    } catch (e) {
      print("❌ Error loading notifications: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      if (walletAddress == null) return;

      List<Map<String, dynamic>> notificationsList = [];
      
      // 1. Query regular notifications for this charity's wallet address
      final querySnapshot = await FirebaseFirestore.instance
          .collection('charity_notifications')
          .where('charityAddress', isEqualTo: walletAddress)
          .orderBy('timestamp', descending: true) // Most recent first (R3)
          .get();
      
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> notification = doc.data();
        notification['id'] = doc.id; // Add document ID for reference
        notification['notificationType'] = 'regular'; // Mark as regular notification
        
        // Format the timestamp
        if (notification['timestamp'] != null) {
          final timestamp = notification['timestamp'] as Timestamp;
          notification['formattedTime'] = _formatTimestamp(timestamp);
        } else {
          notification['formattedTime'] = 'Unknown time';
        }
        
        notificationsList.add(notification);
      }

      // 2. Query complaint notifications where this charity is the target
      final complaintsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: walletAddress)
          .where('type', whereIn: ['complaint_deleted', 'complaint_restored'])
          .orderBy('timestamp', descending: true)
          .get();
      
      print("📊 Found ${complaintsSnapshot.docs.length} complaint notifications for charity: $walletAddress");
      
      for (var doc in complaintsSnapshot.docs) {
        Map<String, dynamic> notification = doc.data();
        notification['id'] = doc.id;
        notification['notificationType'] = 'complaint'; // Mark as complaint notification
        
        // Check if this notification has already been read
        final readStatusRef = FirebaseFirestore.instance
            .collection('notification_read_status')
            .doc('${walletAddress}_${doc.id}');
            
        final readStatusDoc = await readStatusRef.get();
        notification['isRead'] = readStatusDoc.exists && readStatusDoc.data()?['isRead'] == true;
        notification['readStatusRef'] = readStatusRef;
        
        // Format the timestamp
        if (notification['timestamp'] != null) {
          final timestamp = notification['timestamp'] as Timestamp;
          notification['formattedTime'] = _formatTimestamp(timestamp);
        } else {
          notification['formattedTime'] = 'Unknown time';
        }
        
        notificationsList.add(notification);
      }
      
      // Sort all notifications by timestamp
      notificationsList.sort((a, b) {
        Timestamp aTimestamp = a['timestamp'] ?? Timestamp.now();
        Timestamp bTimestamp = b['timestamp'] ?? Timestamp.now();
        return bTimestamp.compareTo(aTimestamp); // Descending order (newest first)
      });

      if (mounted) {
        setState(() {
          notifications = notificationsList;
          isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching notifications: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Format timestamp to readable date and time
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }

  // Mark notification as read
  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    try {
      if (notification['notificationType'] == 'regular') {
        // Regular charity notification
        await FirebaseFirestore.instance
            .collection('charity_notifications')
            .doc(notification['id'])
            .update({'isRead': true});
      } else if (notification['notificationType'] == 'complaint') {
        // Complaint notification
        if (notification['readStatusRef'] != null) {
          await notification['readStatusRef'].set({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
            'charityAddress': walletAddress,
            'notificationId': notification['id'],
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print("❌ Error marking notification as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60), // Increases app bar height
        child: AppBar(
          backgroundColor: Color.fromRGBO(24, 71, 137, 1),
          elevation: 0, // Remove shadow
          automaticallyImplyLeading: false, // Remove back arrow
          flexibleSpace: Padding(
            padding: EdgeInsets.only(bottom: 20), // Move text down
            child: Align(
              alignment: Alignment.bottomCenter, // Center and move down
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                
                  Text(
                    "Notifications",
                    style: TextStyle(
                      color: Colors.white, // Make text white
                      fontSize: 24, // Increase font size
                      fontWeight: FontWeight.bold,
                    ),
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
              child: _buildNotificationsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          
          if (notification['notificationType'] == 'complaint') {
            return _buildComplaintNotificationCard(notification, index);
          } else {
            return _buildRegularNotificationCard(notification, index);
          }
        },
      ),
    );
  }

  Widget _buildComplaintNotificationCard(Map<String, dynamic> notification, int index) {
    final bool isRead = notification['isRead'] ?? false;
    
    // Determine icon and color based on notification type
    IconData statusIcon;
    Color statusColor;
    
    if (notification['type'] == 'complaint_deleted') {
      statusIcon = Icons.delete;
      statusColor = Colors.red;
    } else if (notification['type'] == 'complaint_restored') {
      statusIcon = Icons.restore;
      statusColor = Colors.green;
    } else {
      statusIcon = Icons.report_problem;
      statusColor = Colors.orange;
    }
    
    return Card(
      elevation: isRead ? 1 : 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.transparent : statusColor,
          width: isRead ? 0 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Mark as read when tapped
          if (!isRead) {
            await _markAsRead(notification);
            
            // Update the UI
            setState(() {
              notifications[index]['isRead'] = true;
            });
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status icon
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Notification content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['title'] ?? 'Complaint Notification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          notification['message'] ?? 'No message',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          notification['formattedTime'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Unread indicator
                  if (!isRead)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegularNotificationCard(Map<String, dynamic> notification, int index) {
    final bool isRead = notification['isRead'] ?? false;
    
    return Card(
      elevation: isRead ? 1 : 3,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.transparent : Color.fromRGBO(24, 71, 137, 1),
          width: isRead ? 0 : 1,
        ),
      ),
      child: InkWell(
        onTap: () async {
          // Mark as read when tapped
          if (!isRead) {
            await _markAsRead(notification);
            
            // Update the UI
            setState(() {
              notifications[index]['isRead'] = true;
            });
          }
          
          // Navigate to project details if projectId exists
          if (notification['projectId'] != null) {
            // Get project details from Firestore
            try {
              final projectDoc = await FirebaseFirestore.instance
                  .collection('projects')
                  .doc(notification['projectId'])
                  .get();
                  
              if (projectDoc.exists) {
                final projectData = projectDoc.data() as Map<String, dynamic>;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetails(
                      projectId: int.parse(notification['projectId']),
                      projectName: notification['projectName'] ?? 'Unknown Project',
                      description: projectData['description'] ?? '',
                      startDate: projectData['startDate']?.toDate().toString() ?? DateTime.now().toString(),
                      deadline: projectData['endDate']?.toDate().toString() ?? DateTime.now().toString(),
                      totalAmount: (projectData['totalAmount'] ?? 0).toDouble(),
                      projectType: projectData['projectType'] ?? 'Unknown',
                      projectCreatorWallet: projectData['projectCreatorWallet'] ?? walletAddress ?? '',
                      donatedAmount: (projectData['donatedAmount'] ?? 0).toDouble(),
                      progress: (projectData['donatedAmount'] ?? 0) / ((projectData['totalAmount'] ?? 1) == 0 ? 1 : projectData['totalAmount']),
                    ),
                  ),
                );
              }
            } catch (e) {
              print("❌ Error navigating to project: $e");
            }
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status icon
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(notification['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getStatusIcon(notification['status']),
                      color: _getStatusColor(notification['status']),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Notification content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification['projectName'] ?? 'Alert',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          notification['message'] ?? 'No message',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          notification['formattedTime'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Unread indicator
                  if (!isRead)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'in-progress':
        return Colors.green;
      case 'voting':
        return Colors.orange;
      case 'ended':
        return Colors.red;
      case 'completed':
        return Color.fromRGBO(24, 71, 137, 1);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'in-progress':
        return Icons.play_circle;
      case 'voting':
        return Icons.how_to_vote;
      case 'ended':
        return Icons.event_available;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }
}
