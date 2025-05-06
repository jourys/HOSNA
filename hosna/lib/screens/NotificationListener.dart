import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:hosna/screens/NotificationManager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:web3dart/web3dart.dart';

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

        final creatorAddress =
            project["organization"]?.toString().toLowerCase();
        final projectId = project["id"].toString();

        // Firestore listeners
        _listenToProjectChanges(project, projectId);
        // _listenToVotingChanges(project, projectId);
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

      if (!snapshot.exists) {
        print(
            "⚠️ Project document for $projectId no longer exists. Skipping...");
        return;
      }

      // Extract Firestore project state
      final data = snapshot.data() ?? {};
      String currentState = data['current'] ?? "active";
      print(
          "🗂️ Firestore current state for project $projectId: $currentState");

      // Calculate new state
      String newState = await _getProjectState(project);
      print("🔍 Recalculated project state: $newState");

      // Compare current and new state
      if (newState != currentState && _shouldNotify(newState)) {
        print(
            "🚨 State change detected! Updating Firestore and notifying users...");
        print("➡️ From: $currentState ➡️ To: $newState");

        try {
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .update({
            'previous': currentState,
            'current': newState,
            'lastUpdated': Timestamp.now(),
          });
          print("✅ Firestore state updated for project $projectId.");
        } catch (e) {
          print(
              "❌ Failed to update Firestore state for project $projectId: $e");
          return;
        }

        // Prepare notification content
        final projectName = project["name"] ?? "Your Project";
        final title = "$projectName Status Update";
        final body = "Project is '$newState'.";
        print("🔔 Notification prepared: $title - $body");

        // Load current user's wallet
        final loadedWallet = await _loadWalletAddress();
        print("👤 Loaded wallet address: ${loadedWallet ?? 'null'}");

        final creatorWallet =
            (project["organization"] ?? "").toString().toLowerCase();
        print("🏢 Project creator wallet: $creatorWallet");

        // Notify creator
        if (creatorWallet == loadedWallet?.toLowerCase()) {
           await Future.delayed(Duration(seconds: 10));
          print("📬 Sending notification to creator...");
         
          notificationService.showNotification(title: title, body: body);

          final userDocRef =
              FirebaseFirestore.instance.collection("users").doc(creatorWallet);
          await userDocRef.set({}, SetOptions(merge: true));
          await userDocRef.collection("notifications").add({
            "title": title,
            "body": body,
            "timestamp": FieldValue.serverTimestamp(),
            "projectId": projectId,
            "type": "project_state",
            "state": newState,
          });
          print("✅ Creator notification stored and sent.");
        } else {
          print(
              "⛔ Current user is not the creator. Skipping creator notification.");
        }

        // Notify donors
        try {
          final donorServices = DonorServices();
          final donorsResult =
              await donorServices.fetchProjectDonors(BigInt.parse(projectId));
          List<EthereumAddress> donorAddresses =
              List<EthereumAddress>.from(donorsResult[0]);

          print(
              "🧾 Found ${donorAddresses.length} donor(s) for project $projectId.");

          final projectBigInt = BigInt.parse(projectId);

// Process donors in parallel using Future.wait
          await Future.wait(donorAddresses.map((donor) async {
            final userAddress = donor.hex.toLowerCase();

            try {
              bool canVote = await donorServices.checkIfDonorCanVote(
                  projectBigInt, userAddress);
              print("✅ Donor $userAddress voting eligibility: $canVote");

              if (canVote) {
                final donorDoc = FirebaseFirestore.instance
                    .collection("users")
                    .doc(userAddress);
                     await Future.delayed(Duration(seconds: 10));
                await donorDoc.set({}, SetOptions(merge: true));
                await donorDoc.collection("notifications").add({
                  "title": title,
                  "body": body,
                  "timestamp": FieldValue.serverTimestamp(),
                  "projectId": projectId,
                  "type": "donor_update",
                  "state": newState,
                });

                // ✅ Only show local notification if the current device belongs to this donor
                if (loadedWallet?.toLowerCase() == userAddress) {
                  notificationService.showNotification(
                      title: title, body: body);
                  print("✅ Donor notification shown locally for $userAddress.");
                } else {
                  print(
                      "ℹ️ Notification stored for donor $userAddress but not shown (different device).");
                }
              }
            } catch (e) {
              print("❌ Error checking donor $userAddress: $e");
            }
          }));
        } catch (e) {
          print("❌ Error notifying donors: $e");
        }
      } else {
        print(
            "⏭️ No state change or notification not required. Skipping update.");
        print(
            "📌 currentState: $currentState, newState: $newState, shouldNotify: ${_shouldNotify(newState)}");
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

            print(
                "✅ Notification stored and sent for voting change of project $projectId.");
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
    return ["completed", "canceled", "ended", "voting", "in-progress", "failed"]
        .contains(state);
  }

  Future<String> _getProjectState(Map<String, dynamic> project) async {
    DateTime now = DateTime.now();
    String projectId = project['id'].toString();

    try {
      final docRef =
          FirebaseFirestore.instance.collection('projects').doc(projectId);
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
      DateTime startDate = project['startDate'] ?? DateTime.now();
      DateTime endDate = project['endDate'] ?? DateTime.now();
      double totalAmount = (project['totalAmount'] ?? 0).toDouble();
      double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();
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
        if (donatedAmount >= totalAmount &&
            now.isBefore(endDate) &&
            !isCompleted) {
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
          //  'isEnded': votingDoc.data()?['IsEnded'] ?? false,
          'previous': currentState,
          'current': calculatedState,
          'lastUpdated': Timestamp.now(),
        });

        print(
            "📌 State updated for $projectId: $currentState ➡️ $calculatedState");
      }

      return calculatedState;
    } catch (e) {
      print("❌ Error fetching project state for ID $projectId: $e");
      return "unknown";
    }
  }
}
