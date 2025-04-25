import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/NotificationManager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectNotificationListener {
  final BlockchainService blockchainService;
  final NotificationService notificationService;

  ProjectNotificationListener({
    required this.blockchainService,
    required this.notificationService,
  });

  String? lastNotifiedState;

  Future<void> checkProjectsForCreator() async {
    final walletAddress = await _loadWalletAddress();

    if (walletAddress == null) {
      print("❌ No wallet address found. Exiting listener.");
      return;
    }

    try {
      final projectCount = await blockchainService.getProjectCount();
      print("📊 Total Projects: $projectCount");

      for (int i = 0; i < projectCount; i++) {
        final project = await blockchainService.getProjectDetails(i);

        if (project.containsKey("error")) continue;

        final creatorAddress = project["organization"]?.toString().toLowerCase();
        final projectId = project["id"].toString();

        if (creatorAddress == walletAddress.toLowerCase()) {
          // Firestore listeners
          _listenToProjectChanges(project, projectId);
          _listenToVotingChanges(project, projectId);
        }
      }
    } catch (e) {
      print("❌ Error during project checking: $e");
    }
  }
void _listenToProjectChanges(Map<String, dynamic> project, String projectId) {
  FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .snapshots()
      .listen((snapshot) async {
    print("📡 Listening to changes for project $projectId...");
    
    if (snapshot.exists) {
      print("📄 Project document exists for $projectId. Checking state...");
      String newState = await _getProjectState(project);
      print("📌 Calculated new state: $newState, Last notified state: $lastNotifiedState");

      if (newState != lastNotifiedState && _shouldNotify(newState)) {
        print("🔔 State has changed and is eligible for notification.");

        lastNotifiedState = newState;

        final walletAddress = await _loadWalletAddress();
        print("👛 Wallet Address: $walletAddress");

        if (walletAddress == null) {
          print("⚠️ Cannot proceed, wallet address is null.");
          return;
        }

        final title = "${project["name"]} Status Update";
        final body = "Project is '$newState'.";

        print("📲 Showing local notification...");
        notificationService.showNotification(title: title, body: body);

        final userDocRef = FirebaseFirestore.instance.collection("users").doc(walletAddress.toString());

        // Ensure the user document exists
        await userDocRef.get().then((doc) async {
          if (!doc.exists) {
            print("📁 User document doesn't exist. Creating...");
            await userDocRef.set({});
            print("✅ User document created for $walletAddress.");
          } else {
            print("📁 User document already exists.");
          }

          // Add notification to subcollection
          await userDocRef
              .collection("notifications")
              .add({
                "title": title,
                "body": body,
                "timestamp": FieldValue.serverTimestamp(),
                "projectId": projectId,
                "type": "project_state",
                "state": newState,
              }).then((_) {
                print("✅ Notification document added for $walletAddress.");
              }).catchError((error) {
                print("❌ Failed to add notification to Firestore: $error");
              });
        });

        print("✅ Notification stored and sent for project $projectId with state $newState");
      } else {
        print("⏭️ No need to notify. Either state didn't change or not eligible.");
      }
    } else {
      print("⚠️ Project document for $projectId no longer exists.");
    }
  });
}


 void _listenToVotingChanges(Map<String, dynamic> project, String projectId) {
  FirebaseFirestore.instance
      .collection('votings')
      .where('projectId', isEqualTo: projectId)
      .snapshots()
      .listen((snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.modified) {
        print("📡 Voting modified, checking state...");
        String newState = await _getProjectState(project);
        if (newState != lastNotifiedState && _shouldNotify(newState)) {
          lastNotifiedState = newState;

          final walletAddress = await _loadWalletAddress();
          final title = "${project["name"]} Voting Update";
          final body = "Project is now '$newState'.";

          notificationService.showNotification(title: title, body: body);

          // ✅ تخزين الإشعار في Firestore
          await FirebaseFirestore.instance
              .collection("users")
              .doc(walletAddress.toString())
              .collection("notifications")
              .add({
                "title": title,
                "body": body,
                "timestamp": FieldValue.serverTimestamp(),
                "projectId": projectId,
                "type": "voting_update",
                "state": newState,
              });

          print("✅ Notification stored and sent for voting change of project $projectId.");
        }
      }
    }
  });
}


    Future<String?> _loadWalletAddress() async {
    print('Loading wallet address...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("Error: Wallet address not found. Please log in again.");
        return null;
      }

      print('Wallet address loaded successfully: $walletAddress');
      return walletAddress;
    } catch (e) {
      print("Error loading wallet address: $e");
      return null;
    }
  }

  bool _shouldNotify(String state) {
    return ["completed", "canceled", "ended", "voting" , "in-progress" ,"failed" ].contains(state);
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();
    String projectId = project['id'].toString();

    try {
      final docRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
      final doc = await docRef.get();

      if (!doc.exists || !(doc.data()?.containsKey('current') ?? false)) {
        await docRef.set({
          'current': 'active',
          'previous': 'active',
        }, SetOptions(merge: true));
      }

      final data = (await docRef.get()).data() ?? {};
      bool isCanceled = data['isCanceled'] ?? false;
      bool isCompleted = data['isCompleted'] ?? false;
      bool votingInitiated = data['votingInitiated'] ?? false;
      bool isEnded = false;

      if (data['votingId'] != null) {
        final votingDoc = await FirebaseFirestore.instance
            .collection("votings")
            .doc(data['votingId'].toString())
            .get();
        isEnded = votingDoc.data()?['IsEnded'] ?? false;
      }

      // Determine calculated state
      String calculatedState;
      if (isEnded) {
        calculatedState = "ended";
      } else if (isCompleted) {
        calculatedState = "completed";
      } else if (votingInitiated && !isCompleted && !isEnded) {
        calculatedState = "voting";
      } else if (isCanceled && !votingInitiated && !isEnded) {
        calculatedState = "canceled";
      } else {
        DateTime startDate = project['startDate'] ?? DateTime.now();
        DateTime endDate = project['endDate'] ?? DateTime.now();
        double totalAmount = (project['totalAmount'] ?? 0).toDouble();
        double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

        if (now.isBefore(startDate)) {
          calculatedState = "upcoming";
        } else if (donatedAmount >= totalAmount) {
          calculatedState = "in-progress";
        } else if (now.isAfter(endDate)) {
          calculatedState = "failed";
        } else {
          calculatedState = "active";
        }
      }

        final votingDoc = await FirebaseFirestore.instance
            .collection("votings")
            .doc(data['votingId'].toString())
            .get();

      String currentState = data['current'] ?? "active";
      if (currentState != calculatedState) {
        await docRef.update({


   'isEnded': votingDoc.data()?['IsEnded'] ?? false,
          'previous': currentState,
          'current': calculatedState,
          'lastUpdated': Timestamp.now(),
        });

        print("📌 State updated for $projectId: $currentState ➡️ $calculatedState");
      }

      return calculatedState;
    } catch (e) {
      print("❌ Error fetching project state for ID $projectId: $e");
      return "unknown";
    }
  }
}
