import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CharityNotificationsPage extends StatefulWidget {
  @override
  _CharityNotificationsPageState createState() =>
      _CharityNotificationsPageState();
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

      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(walletAddress);

      final notificationsFuture = userDoc
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      final justificationsFuture = userDoc
          .collection('justifications')
          .orderBy('timestamp', descending: true)
          .get();

      final results =
          await Future.wait([notificationsFuture, justificationsFuture]);

      final notificationsSnapshot = results[0];
      final justificationsSnapshot = results[1];

      final combinedItems = [
        ...notificationsSnapshot.docs.map((doc) => {
              'type': 'notification',
              'data': doc.data(),
              'timestamp': doc['timestamp'],
            }),
        ...justificationsSnapshot.docs.map((doc) => {
              'type': 'justification',
              'data': doc.data(),
              'timestamp': doc['timestamp'],
            }),
      ];

      combinedItems.sort((a, b) {
        Timestamp tsA = a['timestamp'];
        Timestamp tsB = b['timestamp'];
        return tsB.compareTo(tsA);
      });

      setState(() {
        notifications = combinedItems;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading notifications: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
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
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                      ? Center(child: Text("No notifications available."))
                      : ListView.builder(
                          itemCount: notifications.length,
                          padding: EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final notif = notifications[index];
                            final data = notif['data'] ?? {};
                            final title = data['title'] ?? 'No Title';
                            final body = data['body'] ?? '';
                            final timestamp = notif['timestamp']?.toDate();

                            Color cardColor = Colors
                                .primaries[index % Colors.primaries.length];
                            Color iconColor = cardColor.withOpacity(0.8);
                            String formattedDate = '';
                            String formattedTime = '';
                            if (timestamp != null) {
                              formattedDate =
                                  DateFormat('dd/MM/yyyy').format(timestamp);
                              formattedTime =
                                  DateFormat('HH:mm').format(timestamp);
                            }

                            return Card(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              margin: EdgeInsets.only(bottom: 16),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: iconColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.notifications,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: cardColor,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          if (timestamp != null) ...[
                                            SizedBox(height: 8),
                                            Text(
                                              '$formattedDate $formattedTime',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
}
