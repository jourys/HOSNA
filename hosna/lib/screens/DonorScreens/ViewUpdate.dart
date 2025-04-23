import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;

class ViewUpdate extends StatefulWidget {
  final String projectName;
  final int projectId;

  const ViewUpdate(
      {super.key, required this.projectName, required this.projectId});

  @override
  State<ViewUpdate> createState() => _ViewUpdateState();
}

class _ViewUpdateState extends State<ViewUpdate> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      body: Column(
        children: [
          // AppBar
          PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: AppBar(
              backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
              elevation: 0,
              leading: Container(),
              flexibleSpace: Padding(
                padding: const EdgeInsets.only(left: 20, top: 50),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        "              Updates",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Content starts here
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project Name in white area
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      widget.projectName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(24, 71, 137, 1),
                      ),
                    ),
                  ),
                  // Updates
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('project_updates')
                          .where('projectId', isEqualTo: widget.projectId)
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          print("Firestore error: ${snapshot.error}");
                          return const Center(
                              child: Text("Something went wrong"));
                        }
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          print(widget.projectId);
                          return const Center(child: Text("No updates yet."));
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final data = snapshot.data!.docs[index];
                            final String text = data['text'] ?? '';
                            final String? imageUrl = data['imageUrl'];
                            final Timestamp? timestamp = data['timestamp'];
                            final String timeAgo = timestamp != null
                                ? timeago.format(timestamp.toDate())
                                : '';

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (imageUrl != null && imageUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: 200,
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                                          },
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return const Text(
                                                "Failed to load image");
                                          },
                                        ),
                                      ),
                                    if (text.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 12.0),
                                        child: Text(
                                          text,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    if (timeAgo.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          timeAgo,
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
