import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';


class NotificationService {
  late Web3Client _web3Client;

  final String _donationAbi = '''[
    {
      "inputs": [
        {
          "internalType": "uint256",
          "name": "projectId",
          "type": "uint256"
        }
      ],
      "name": "getProjectDonorsWithAmounts",
      "outputs": [
        {
          "internalType": "address[]",
          "name": "",
          "type": "address[]"
        },
        {
          "internalType": "uint256[]",
          "name": "",
          "type": "uint256[]"
        },
        {
          "internalType": "uint256[]",
          "name": "",
          "type": "uint256[]"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]''';
  
  // Send voting notifications to all registered donors regardless of project
  Future<void> sendVotingStatusNotification(String projectName, String newStatus) async {
    try {
      // Create a unique batch identifier for this notification
      final String batchId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Send notifications to all donors
      try {
        // Create a unique notification ID
        final notificationId = 'voting_global_${batchId}'; 
        
        // Send notification
        await firestore.FirebaseFirestore.instance
            .collection('donor_notifications')
            .doc(notificationId)
            .set({
              'projectName': projectName,
              'message': 'Voting has started for project "$projectName". Your participation is needed!',
              'type': 'voting_status',
              'status': newStatus,
              'timestamp': firestore.FieldValue.serverTimestamp(),
              'isRead': false,
            }, firestore.SetOptions(merge: true));
            
        print("✅ Voting notification sent to all donors");
      } catch (e) {
        print("❌ Error sending notification to all donors: $e");
      }
    } catch (e) {
      print("❌ Error in sendVotingStatusNotification: $e");
    }
  }
  
  // Send project status change notifications to donors of a specific project
  Future<void> sendProjectStatusNotification(int projectId, String projectName, String newStatus) async {
    try {
      print("🔔 Sending notification for project status change: Project ID: $projectId, Status: $newStatus");
      
      // Get all donors who contributed to this project
      final donorAddresses = await getDonorsForProject(projectId);
      print("📊 Found ${donorAddresses.length} donors for this project");
      
      if (donorAddresses.isEmpty) {
        print("⚠️ No donors found for project #$projectId");
        return;
      }
      
      // Create a notification for each donor
      for (var donorAddress in donorAddresses) {
        // Create a unique document ID that won't duplicate if the same notification is sent again
        final notificationId = 'status_${projectId}_${donorAddress}_${newStatus}';
        
        await firestore.FirebaseFirestore.instance
            .collection('donor_notifications')
            .doc(notificationId)
            .set({
              'donorAddress': donorAddress,
              'projectId': projectId,
              'projectName': projectName,
              'message': _getStatusChangeMessage(newStatus, projectName),
              'type': 'status_change',
              'status': newStatus,
              'timestamp': firestore.FieldValue.serverTimestamp(),
              'isRead': false,
            }, firestore.SetOptions(merge: true)); // Using merge: true to prevent overwriting if exists
            
        print("✅ Notification sent to donor: $donorAddress");
      }
    } catch (e) {
      print("❌ Error sending project status notifications: $e");
    }
  }
  
  // Send voting notifications to all donors of a specific project
  Future<void> sendProjectVotingNotification(int projectId, String projectName) async {
    try {
      print("🔔 Sending voting notifications for project #$projectId");
      
      // Check if notifications have already been sent for this project
      final notificationTrackingRef = firestore.FirebaseFirestore.instance
          .collection('notification_tracking')
          .doc('voting_${projectId}');
          
      final doc = await notificationTrackingRef.get();
      if (doc.exists && doc.data()?['notified'] == true) {
        print("ℹ️ Notifications already sent for project #$projectId");
        return;
      }
      
      // Get all donors for this project
      final donorAddresses = await getDonorsForProject(projectId);
      print("📊 Found ${donorAddresses.length} donors for project #$projectId");
      
        if (donorAddresses.isEmpty) {
        print("⚠️ No donors found for project #$projectId");
        return;
      }
      
      // Send notifications to all donors
      bool allSuccessful = true;
      for (var donorAddress in donorAddresses) {
        try {
          // Create a unique notification ID
          final notificationId = 'voting_${projectId}_${donorAddress}';
          
          // Send notification
          await firestore.FirebaseFirestore.instance
              .collection('donor_notifications')
              .doc(notificationId)
              .set({
                'donorAddress': donorAddress,
                'projectId': projectId,
                'projectName': projectName,
                'message': 'Voting has started for project "$projectName". Your participation is needed!',
                'type': 'voting_status',
                'status': 'voting',
                'timestamp': firestore.FieldValue.serverTimestamp(),
                'isRead': false,
              }, firestore.SetOptions(merge: true));
              
          print("✅ Voting notification sent to donor: $donorAddress for project #$projectId");
        } catch (e) {
          print("❌ Error sending notification to donor $donorAddress: $e");
          allSuccessful = false;
        }
      }
      
      // Mark this project as having had notifications sent
      if (allSuccessful) {
        await notificationTrackingRef.set({
          'notified': true,
          'timestamp': firestore.FieldValue.serverTimestamp(),
          'projectId': projectId,
          'projectName': projectName,
        }, firestore.SetOptions(merge: true));
        
        print("✅ Marked project #$projectId as having had voting notifications sent");
      }
    } catch (e) {
      print("❌ Error sending project voting notifications: $e");
    }
  }
  
  // Helper method to get a user-friendly message based on status
  String _getStatusChangeMessage(String status, String projectName) {
    switch (status) {
      case 'voting':
        return 'Voting has started for project "$projectName". Your participation is needed!';
      case 'ended':
        return 'Project "$projectName" has ended.';
      case 'in-progress':
        return 'Project "$projectName" is now in progress and implementing changes.';
      case 'completed':
        return 'Project "$projectName" has been successfully completed!';
      default:
        return 'Project "$projectName" status has changed to $status.';
    }
  }

  // Get a list of donor addresses that contributed to a project
  Future<List<String>> getDonorsForProject(int projectId) async {
    try {
      // Use the existing method from the contract to get donors
      final donationContract = DeployedContract(
        ContractAbi.fromJson(_donationAbi, 'DonationContract'),
        EthereumAddress.fromHex('0x74409493A94E68496FA90216fc0A40BAF98CF0B9'), // Donation contract address
      );
      
      final getProjectDonorsFunc = donationContract.function('getProjectDonorsWithAmounts');
      
      final response = await _web3Client.call(
        contract: donationContract,
        function: getProjectDonorsFunc,
        params: [BigInt.from(projectId)],
      );
      
      if (response.isEmpty || response[0].isEmpty) {
        return [];
      }
      
      // Extract donor addresses from response
      List<String> donorAddresses = [];
      for (var address in response[0]) {
        if (address is EthereumAddress) {
          donorAddresses.add(address.hex);
        }
      }
      
      return donorAddresses;
    } catch (e) {
      print("❌ Error getting donors for project: $e");
      return [];
    }
  }
  
} 