import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:hosna/screens/CharityScreens/InitiateVoting.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/CharityScreens/ViewDonors.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/VotingDetails.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'package:hosna/screens/CharityScreens/PostUpdate.dart';
import 'package:hosna/screens/DonorScreens/ViewUpdate.dart';



class ProjectDetails extends StatefulWidget {
  final String projectName;
  final String description;
  final String startDate;
  final String deadline;
  final double totalAmount;
  final String projectType;
  final String projectCreatorWallet;
  final double donatedAmount;
  final int projectId;
  final double progress;

  const ProjectDetails(
      {super.key,
      required this.projectName,
      required this.description,
      required this.startDate,
      required this.deadline,
      required this.totalAmount,
      required this.projectType,
      required this.projectCreatorWallet,
      required this.donatedAmount,
      required this.projectId,
      required this.progress});

  @override
  _ProjectDetailsState createState() => _ProjectDetailsState();
}


class _ProjectDetailsState extends State<ProjectDetails> {
  final donorServices = DonorServices();
  bool canVote = false; // To store the result of whether the user can vote

  int? userType;
  final TextEditingController amountController = TextEditingController();
  String? globalWalletAddress;
  bool _isFetchingDonatedAmount = false;
  bool isCanceled = false; // Default value
  String projectState = "";
   bool votingInitiated = false; // Initialize votingInitiated as false
bool isEnded = false;
bool isCompleted = false;
  // Web3 Variables
  late Web3Client _web3client;
  final String rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final EthereumAddress contractAddress =
      EthereumAddress.fromHex("0x95a20778c2713a11ff61695e57cd562f78f75754");
  bool isLoading = true;

  final BlockchainService _blockchainService = BlockchainService();
  bool _isLoadingState = true;
  @override
  void initState()  {
    super.initState();
_loadProjectState();
    _getUserType();
    _web3client = Web3Client(rpcUrl, Client());

    if (globalWalletAddress == null) {
      _loadWalletAddress();
    } else {
      _loadPrivateKey(globalWalletAddress!).then((privateKey) {
        if (privateKey != null) {
          print("✅ Loaded Private Key: $privateKey");
        } else {
          print("❌ No private key found for this wallet address.");
        }
      });
    }

    print("Project Creator Wallet Address: ${widget.projectCreatorWallet}");
    print("Wallet Address: $globalWalletAddress");
  }

  String? _globalPrivateKey;

  String? get globalPrivateKey => _globalPrivateKey;

  set globalPrivateKey(String? privateKey) {
    _globalPrivateKey = privateKey;
    print('✅ Global private key set: $privateKey');

//  checkVotingStatus() ;

     _listenToProjectState();
                  _fetchVotingStatus();


  }



Future<void> _loadProjectState() async {
   setState(() {
    _isLoadingState = true;
  });
  final state = await determineProjectState(widget.projectId.toString());
 setState(() {
    projectState = state;
    _isLoadingState = false;
  });
}
 // Method to load the wallet address from SharedPreferences
  Future<String?> _loadAddress() async {
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

Future<void> _fetchVotingStatus() async {
  print('🔍 Fetching voting status for project: ${widget.projectId}');

  try {
    if (globalWalletAddress == null) {
      print('❌ Wallet address is null. Cannot check voting eligibility.');
      setState(() {
        canVote = false;
        votingInitiated = false;
      });
      return;
    }

    final BigInt bigProjectId = BigInt.from(widget.projectId);
    print('🔢 Converted project ID to BigInt: $bigProjectId');
    print('🧾 Checking if donor can vote using address: $globalWalletAddress');

    print('🛑 isCanceled: $isCanceled');

    // Check donor voting eligibility
    final bool donorEligibility = await donorServices.checkIfDonorCanVote(
      bigProjectId,
      globalWalletAddress.toString(),
    );

    print('✅ Donor voting eligibility status: $donorEligibility');

    setState(() {
      canVote = donorEligibility;
    });

    // Check voting status from Firestore
    final projectDocRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId.toString());

    final projectDoc = await projectDocRef.get();
    print('📌 Fetched document for Project ID: ${widget.projectId}');

    if (projectDoc.exists) {
      final data = projectDoc.data();
      print('📄 Project document exists. Data: $data');

      setState(() {
        votingInitiated = data?['votingInitiated'] ?? false;
      });
    } else {
      print('❌ Project document not found in Firestore. Creating default document...');
      await projectDocRef.set({'votingInitiated': false});

      print('✅ Default project document created with votingInitiated = false');

      setState(() {
        votingInitiated = false;
      });
    }
  } catch (e) {
    print('⚠️ Error while fetching voting status: $e');
  }
}


StreamSubscription<DocumentSnapshot>? _projectSubscription;

void _listenToProjectState() {
  _projectSubscription = FirebaseFirestore.instance
      .collection('projects')
      .doc(widget.projectId.toString())
      .snapshots()
      .listen((doc) async {
    if (doc.exists) {
      setState(() {
        final data = doc.data() as Map<String, dynamic>;

        // Ensure 'isCanceled' exists in the document
        if (!data.containsKey('isCanceled')) {
          FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId.toString())
              .update({'isCanceled': false});
          isCanceled = false;
        } else {
          isCanceled = data['isCanceled'];
        }

if (isEnded) {
      projectState = "ended";
       print("is ended : $isEnded");
      return;}
        // Check if project is completed
        if (isCompleted) {
          projectState = "completed";
        } else {
          projectState = votingInitiated && (!isCompleted) && (!isEnded)
              ? "voting"
              : isCanceled && (!votingInitiated) && (!isEnded)
                  ? "canceled"
                  : getProjectState(data, votingInitiated, isCanceled, isEnded, isCompleted);
        }

        print("Firestore data: $data");
        print("isCanceled: $isCanceled");
        print("Final Project Status: $projectState");
      });
    } else {
      print("Document not found");
    }
  }, onError: (e) {
    print("Error loading project state: $e");
  });
}



@override
void dispose() {
  _projectSubscription?.cancel(); // Cancel the listener when the widget is removed
  super.dispose();
}



  Future<void> _getUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userType = prefs.getInt('userType');
    });
    print("All keys: ${prefs.getKeys()}");
  }

  Future<String?> _loadWalletAddress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = prefs.getString('walletAddress');

      if (walletAddress == null) {
        print("Error: Wallet address not found. Please log in again.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Wallet address not found. Please log in again.')),
        );
        return null;
      }

      setState(() {
        globalWalletAddress = walletAddress;
      });

      String? privateKey = await _loadPrivateKey(walletAddress);

      if (privateKey == null && userType != null) {
        print("Error: Private key not found for wallet address.");
    ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(
      'Your account has been suspended. You are currently unable to perform any operations. Please contact support for further details and assistance.',
    ),
  // Set duration to 1 minute
    backgroundColor: Colors.red, // Set background color to red
  ),
);


        return null;
      }

      return privateKey;
    } catch (e) {
      print("Error loading wallet address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading wallet address: $e')),
      );
      return null;
    }
  }

  Future<String?> _loadPrivateKey(String walletAddress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
        print('✅ Private key : $privateKey');
        globalPrivateKey = privateKey;
        return privateKey;
      } else {
        print('❌ Private key not found for wallet $walletAddress');
        return null;
      }
    } catch (e) {
      print('⚠️ Error retrieving private key: $e');
      return null;
    }
  }

  Future<void> _fetchDonatedAmount() async {
    setState(() {
      _isFetchingDonatedAmount = true;
    });

    try {
      print("Fetching donated amount for project ID: ${widget.projectId}");

      final donationContract = DeployedContract(
        ContractAbi.fromJson(_contractAbi, 'DonationContract'),
        contractAddress,
      );

      final function = donationContract.function('getProjectDonations');

      final result = await _web3client.call(
        contract: donationContract,
        function: function,
        params: [BigInt.from(widget.projectId)],
      );

      print("Raw Result from Smart Contract: $result");

      if (result.isEmpty || result[0] == null) {
        print("⚠️ Warning: No data returned from contract!");
        return;
      }

      final donatedAmountInWei = result[0] as BigInt;
      final donatedAmountInEth = donatedAmountInWei / BigInt.from(10).pow(18);

      print("✅ Donated Amount (ETH): $donatedAmountInEth");
    } catch (e) {
      print("❌ Error fetching donated amount: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching donated amount: $e')),
      );
    } finally {
      setState(() {
        _isFetchingDonatedAmount = false;
      });
    }
  }

  String _getProjectState() {
  Map<String, dynamic> project = {
    'startDate': widget.startDate,
    'endDate': widget.deadline,
    'totalAmount': widget.totalAmount,
    'donatedAmount': widget.donatedAmount,
    
  };

  return getProjectState(project, votingInitiated, isCanceled , isEnded , isCompleted );
}


// void checkVotingStatus() async {
//  _projectSubscription = FirebaseFirestore.instance
//     .collection('projects')
//     .doc(widget.projectId.toString())
//     .snapshots()
//     .listen((doc) {
//   if (doc.exists) {
//     setState(() {
//       final data = doc.data() as Map<String, dynamic>;

//       // Load isCanceled (optional, based on your use case)
//       if (data.containsKey('isCanceled')) {
//         isCanceled = data['isCanceled'] is bool
//             ? data['isCanceled']
//             : data['isCanceled'] == "canceled";
//       } else {
//         isCanceled = false;
//       }

//       // Load votingInitiated
//       votingInitiated = data['votingInitiated'] ?? false;

//       // Set project state
//       projectState = votingInitiated ? "voting" : "canceled";

//       print("📢 VOTING INITIATED: $votingInitiated");
//       print("📛 Project State: $projectState");
//     });
//   }
// });

// }



Future<String> determineProjectState(String projectId) async {
  print("📥 Fetching project with ID: $projectId");
final docRef = FirebaseFirestore.instance.collection('projects').doc(projectId);
DocumentSnapshot doc = await docRef.get();

if (!doc.exists) {
  print("⚠️ Document does not exist for project ID: $projectId");

  // Create the document with default fields
  await docRef.set({
    'isCanceled': false,
    'isCompleted': false,
    'votingInitiated': false,
  
  });

  print("✅ Created default document for project ID: $projectId");

  // Re-fetch the document after creating it
  doc = await docRef.get();
}

// Now it's safe to cast
final data = doc.data() as Map<String, dynamic>;

  print("📄 Project data fetched: $data");

  votingInitiated = data['votingInitiated'] ?? false;
  isCanceled = data['isCanceled'] == true || data['isCanceled'] == "canceled";

  print("🗳️ votingInitiated: $votingInitiated");
  print("❌ isCanceled: $isCanceled");

  // 🆕 Get votingId and check if endedisEnded = false;
final votingId = data['votingId'];
if (votingId != null) {
  final votingDocRef = FirebaseFirestore.instance
      .collection("votings")
      .doc(votingId.toString());

  final votingDoc = await votingDocRef.get();
  final votingData = votingDoc.data();

  if (votingDoc.exists) {
    // If 'IsEnded' is missing, create it with default false
    if (!votingData!.containsKey('IsEnded')) {
      await votingDocRef.update({'IsEnded': false});
      print("✅ 'IsEnded' field added to voting document $votingId.");
    }

    isEnded = votingData['IsEnded'] ?? false;
  } else {
    print("⚠️ Voting document not found for ID: $votingId.");
  }
}




 print("is ended : $isEnded");


// Set the global isCompleted value if it exists in Firestore
if (data.containsKey('isCompleted')) {
  isCompleted = data['isCompleted'] ;
}

        

  return getProjectState(data, votingInitiated, isCanceled, isEnded , isCompleted);
}

String getProjectState(Map<String, dynamic> project, bool votingInitiated, bool isCanceled, bool isEnded, bool isCompleted) {
  DateTime now = DateTime.now();

  // 🗓️ Handle startDate
  DateTime startDate;
  if (project['startDate'] == null) {
    return "upcoming";
  } else if (project['startDate'] is DateTime) {
    startDate = project['startDate'];
  } else if (project['startDate'] is Timestamp) {
    startDate = (project['startDate'] as Timestamp).toDate();
  } else {
    startDate = DateTime.parse(project['startDate'].toString());
  }

  // 🗓️ Handle endDate
  DateTime endDate;
  if (project['endDate'] == null) {
    return "active";
  } else if (project['endDate'] is DateTime) {
    endDate = project['endDate'];
  } else if (project['endDate'] is Timestamp) {
    endDate = (project['endDate'] as Timestamp).toDate();
  } else {
    endDate = DateTime.parse(project['endDate'].toString());
  }

  // 💰 Handle amounts
  double totalAmount = (project['totalAmount'] ?? 0).toDouble();
  double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

  // ✅ PRIORITY ORDER (Highest to Lowest)
   if ((donatedAmount >= totalAmount) && (isCompleted))  return "completed";
  if (isEnded) return "ended";                // 🟢 ended status added
  if (votingInitiated && (!isEnded)) return "voting";       // 🔵 voting comes next
  if (isCanceled && (!votingInitiated)) return "canceled"; // 🟠 then canceled
  if (now.isBefore(startDate)) return "upcoming";
  if ((donatedAmount >= totalAmount) && (!isCompleted)) return "in-progress";
  if (now.isAfter(endDate)) return "failed";
  if (now.isAfter(startDate) && now.isBefore(endDate) && (!isCanceled) && (!votingInitiated)) return "active";

  return "unknown";
}

 Color _getStateColor(String state) {
  switch (state) {
    case "active":
      return Colors.green;
    case "failed":
      return Colors.red;
    case "in-progress":
      return Colors.purple;
    case "voting":
      return Colors.blue;
    case "canceled":
      return Colors.orange;
    case "ended":
      return Colors.grey;
    case "completed":
      return const Color.fromRGBO(24, 71, 137, 1);
    default:
      return Colors.grey;
  }
}
Future<void> _markProjectAsCompleted() async {
    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId.toString())
          .update({'isCompleted': true});
      print("Project marked as completed.");
    } catch (e) {
      print("Error marking project as completed: $e");
    }
  }
Widget _buildCreativeProjectType(String type) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.blue.shade50, // Light blue background for contrast
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.blue.shade200, width: 2), // Subtle border
      boxShadow: [
        BoxShadow(
          color: Colors.blue.shade100,
          blurRadius: 8,
          offset: Offset(2, 4), // Shadow effect
        ),
      ],
    ),
    child: Row(
      children: [
        Icon(
          Icons.label_important, // Optional: Add an icon
          color: Colors.blue.shade600,
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          type,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
            letterSpacing: 1.2, // Spacing between letters
            shadows: [
              Shadow(
                blurRadius: 2.0,
                color: Colors.blue.shade300,
                offset: Offset(1.5, 1.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildTypeItem(String title, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            
            color: Color.fromRGBO(24, 71, 137, 1), // Project Title Color
          ),
        ),
        const SizedBox(width: 10),
      Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Adjust padding to fit the text
  decoration: BoxDecoration(
    color: Colors.grey.shade300, // Set the background color to grey
    borderRadius: BorderRadius.circular(12), // Make the corners circular
  ),
  child: Text(
    value,
    style: TextStyle(
      fontSize: 16,
      color: Colors.grey.shade700, // Text color inside the grey background
    ),
  ),
)


      ],
    ),
  );
}


  @override
Widget build(BuildContext context) {
 

    String projectState = _getProjectState();
print("Project status: $projectState");

//   String projectState = (isCanceled && !votingInitiated) ? "canceled" : _getProjectState();
//   print("Project status: $projectState");

//  projectState = (isCanceled && votingInitiated) ? "voting" : _getProjectState();
//   print("Project status: $projectState");

  Color stateColor = _getStateColor(projectState);
  double totalAmount = widget.totalAmount;

  return Scaffold(
    backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(60), // Increases app bar height
      child: AppBar(
  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
  elevation: 0, // Remove shadow
  automaticallyImplyLeading: false, // We're adding a custom back button
  leading: IconButton(
    icon: Icon(Icons.arrow_back, color: Colors.white , size : 30), // White back arrow
    onPressed: () {
      Navigator.pop(context); // Navigate back when tapped
    },
  ),
  flexibleSpace: Padding(
    padding: EdgeInsets.only(bottom: 20), // Move text down
    child: Align(
      alignment: Alignment.bottomCenter, // Center and move down
      child: Text(
        widget.projectName,
        style: TextStyle(
          color: Colors.white, // Make text white
          fontSize: 24, // Increase font size
          fontWeight: FontWeight.bold,
        ),
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
                topLeft: Radius.circular(20), // Adjust top-left corner
                topRight: Radius.circular(20), // Adjust top-right corner
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                        const SizedBox(height: 10),

                   Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out the items
  children: [
    Align(
      alignment: Alignment.centerLeft, // Aligns the widget to the left
      child: _buildTypeItem(
        '', 
        widget.projectType, // Passing the project type here
      ),
    ),
   if(userType != null && _globalPrivateKey != null )
       GestureDetector(
      onTap: () {
  print("Report Project Pressed!");
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return ReportPopup(
        projectCreatorWallet: widget.projectCreatorWallet,
        projectId: widget.projectId,
      );
    },
  );
},

      
        child: Icon(
          Icons.flag, // Flag icon for report
          color: Colors.grey, // White color for the icon
          size: 40, // Icon size
        ),
      
    ),
    
  ],
),
                    const SizedBox(height: 25),
                   Text(
  widget.description,
  textAlign: TextAlign.center,
  style: TextStyle(fontSize: 17, color: Colors.grey[700]),
),
                    const SizedBox(height: 20),
                     LinearProgressIndicator(
                            value: widget.progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(widget.progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                         Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _isLoadingState
            ? Colors.white.withOpacity(0.2)
            : _getStateColor(projectState).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _isLoadingState
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 0),
            )
          : Text(
              projectState,
              style: TextStyle(
                color: _getStateColor(projectState),
                fontWeight: FontWeight.bold,
              ),
            ),
    ),


  ],

  

),

   
                            ],
                          ),
SizedBox(height: 15),
    
                           SizedBox(height: 30),
                          //  if (userType == 1 &&
                          //     widget.projectCreatorWallet == globalWalletAddress) 
                          GestureDetector(
                            onTap: () {
                              print("View all donors");
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewDonorsPage(
                                    projectId: widget.projectId,
                                  ),
                                ),
                              );
                            },
                            child: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
 
    const Text(
      'View All Donors',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color.fromRGBO(24, 71, 137, 1),
        decoration: TextDecoration.underline,
        letterSpacing: 0.5,
      ),
    ),
     SizedBox(width: 8),
     Icon(Icons.group, color: Color.fromRGBO(24, 71, 137, 1) , size : 30),
   
  ],
),

                          ), 
                          SizedBox(height: 30),

                     Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out the items
  children: [
    _buildDetailItem(
      'Funded:', '${widget.donatedAmount.toStringAsFixed(5)} ETH'),
    _buildDetailItem(
      'Goal:', '${totalAmount.toStringAsFixed(5)} ETH'),
  ],
                     ),

 SizedBox(height: 15),
                       Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Optional: Adjust alignment if needed
   children: [
  _buildDateItem(
    'Begins:', 
    parseDate(DateTime.parse(widget.startDate)),
    valueColor: Colors.green,
  ),
  _buildDateItem(
    'Ends:', 
    parseDate(DateTime.parse(widget.deadline)),
    valueColor: Colors.red,
  ),
],

),

                                     SizedBox(height: 15),
                                      

                    Visibility(
                      visible: _isFetchingDonatedAmount,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    Visibility(
                      visible: !_isFetchingDonatedAmount,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        
                         
                          const SizedBox(height: 100),
if (projectState == "active" && userType == 0)
                            Center(
                              child: ElevatedButton(
                                onPressed: () => _showDonationPopup(context, widget.donatedAmount, totalAmount),

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 100, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text('Donate',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                        
                       
if (userType == 1 &&
    (projectState == "failed" || projectState == "canceled")
     && widget.projectCreatorWallet == globalWalletAddress
    )
 Center(
            child: ElevatedButton(
              onPressed: () async {
             if (votingInitiated) {
  try {
    // 🔍 Step 1: Fetch the votingId from Firestore
    DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId.toString())
        .get();

    if (projectSnapshot.exists) {
      final data = projectSnapshot.data() as Map<String, dynamic>;
      final votingId = data['votingId'].toString();

      if (votingId != null) {
        // ✅ Step 2: Navigate to VotingDetailsPage with the votingId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotingDetailsPage(
              walletAddress: globalWalletAddress ?? '',
              votingId: votingId.toString(), // 👈 Pass it here
            ),
          ),
        );
      } else {
        print("❌ votingId is null");
        // Optionally show a snackbar or alert to user
      }
    }
  } catch (e) {
    print("❌ Error fetching votingId: $e");
  }
}
else {
                   Navigator.push(
                    context,
               MaterialPageRoute(
              builder: (context) => InitiateVoting(walletAddress: globalWalletAddress ?? '' , projectId: widget.projectId),
            ),
             );

                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                votingInitiated ? 'Check Voting' : 'Start Voting',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

                 
if (userType == 1 &&
    (projectState == "voting")
     && widget.projectCreatorWallet == globalWalletAddress
    )
 Center(
            child: ElevatedButton(
              onPressed: () async {
             if (votingInitiated) {
  try {
    // 🔍 Step 1: Fetch the votingId from Firestore
    DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId.toString())
        .get();

   
      final data = projectSnapshot.data() as Map<String, dynamic>;
      final votingId = data['votingId'].toString();

      if (votingId != null) {
        // ✅ Step 2: Navigate to VotingDetailsPage with the votingId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VotingDetailsPage(
              walletAddress: globalWalletAddress ?? '',
              votingId: votingId.toString(), // 👈 Pass it here
            ),
          ),
        );
      } else {
        print("❌ votingId is null");
        // Optionally show a snackbar or alert to user
      }
    
  } catch (e) {
    print("❌ Error fetching votingId: $e");
  }
}

               

               
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                'Check Voting',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),



if (canVote && votingInitiated && userType == 0 && (!isEnded))
  Center(
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
   onPressed: ()async {
    try {
    // 🔍 Step 1: Fetch the votingId from Firestore
    DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId.toString())
        .get();

    if (projectSnapshot.exists) {
      final data = projectSnapshot.data() as Map<String, dynamic>;
      final votingId = data['votingId'].toString();

      if (votingId != null) {
        // ✅ Step 2: Navigate to VotingDetailsPage with the votingId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DonorVotePage(
              projectId: widget.projectId.toString(),
              walletAddress: globalWalletAddress ?? '',
              votingId: votingId.toString(), // 👈 Pass it here
            ),
          ),
        );
      } else {
        print("❌ votingId is null");
        // Optionally show a snackbar or alert to user
      }
    }
  } catch (e) {
    print("❌ Error fetching votingId: $e");
  }
},


      child: Text(
        "Cast Your Vote!",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
  ), 
                            if (userType == 1 &&
                                projectState == "in-progress" &&
                                widget.projectCreatorWallet ==
                                    globalWalletAddress)
                              Column(
                                children: [
                                  // Post Update button
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PostUpdate(
                                                projectId: widget.projectId),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromRGBO(
                                            24, 71, 137, 1),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 100, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                      ),
                                      child: const Text(
                                        'Post Update',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),  ),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  // Mark as Completed button
                                  if (!isCompleted && widget.projectCreatorWallet == globalWalletAddress)
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await _markProjectAsCompleted();
                                          setState(() {
                                            isCompleted = true;
                                            projectState = "completed";
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blueGrey,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 80, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                        ),
                                        child: const Text(
                                          'Mark as Completed',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],  ),
                            if (userType == 0 &&
                                (projectState == "in-progress" ||
                                    projectState == "completed"))
                              Center(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => ViewUpdate(
                                              projectName: widget.projectName,
                                              projectId: widget.projectId)),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromRGBO(24, 71, 137, 1),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 100,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: const Text(
                                    'View Updates',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ), ),

                    
                          if ((userType == 1 &&
                              projectState == "active" &&
                              widget.projectCreatorWallet == globalWalletAddress) || (userType == null && projectState == "active"))
                            Center(
                              child: ElevatedButton(
                                onPressed: () async {
                                  print("press cancel button");
                                  print("Project ID: ${widget.projectId}");
                                  bool confirmCancel =
                                      await _showcancelConfirmationDialog(context);
                                  if (confirmCancel) {
                                    setState(() {
                                      isCanceled = true;
                                      projectState = "canceled";
                                      print("Project canceled: $isCanceled");
                                    });

                                    DocumentSnapshot document =
                                        await FirebaseFirestore.instance
                                            .collection('projects')
                                            .doc(widget.projectId.toString())
                                            .get();

                                    if (document.exists) {
                                      await FirebaseFirestore.instance
                                          .collection('projects')
                                          .doc(widget.projectId.toString())
                                          .update({'isCanceled': true});
                                      print("Project state updated in Firestore.");
                                    } else {
                                      print("Project document not found. Creating a new project...");
                                      await FirebaseFirestore.instance
                                          .collection('projects')
                                          .doc(widget.projectId.toString())
                                          .set({'isCanceled': true});
                                      print("New project document created and canceled.");
                                    }
                                    showCancelSuccessPopup(context);
                                  } else {
                                    print("Cancellation not confirmed.");
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 100, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text('Cancel Project',
                                    style: TextStyle(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildDateItem(String title, String value, {Color valueColor = Colors.grey}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: RichText(
      text: TextSpan(
        text: '$title ',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          fontFamily: 'Georgia',
          color: Color.fromRGBO(24, 71, 137, 1),
        ),
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: valueColor,
              fontSize: 15,
            ),
          ),
        ],
      ),
    ),
  );
}

String parseDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

// Function to show success popup after project cancellation
void showCancelSuccessPopup(BuildContext context) {
  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Project cancelled successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  ).then((value) {
    // Close the dialog after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context, rootNavigator: true).pop();
    });
  });
}

// Function to show confirmation dialog before cancellation
Future<bool> _showcancelConfirmationDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white, // Set background to white
        title: const Text(
          'Confirm cancelation',
          style: TextStyle(
            fontWeight: FontWeight.bold, // Make title bold
            fontSize: 22, // Increase title font size
          ),
          textAlign: TextAlign.center, // Center the title text
        ),
        content: const Text(
          'Are you sure you want to cancel this project ?',
          style: TextStyle(
            fontSize: 18, // Make content text bigger
          ),
          textAlign: TextAlign.center, // Center the content text
        ),
        actions: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the buttons
            children: [
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, false); // Return false on cancel
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Color.fromRGBO(24, 71, 137, 1),// Border color for Cancel button
                    width: 3,
                  ),
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),// Background color
                ),
                child: const Text(
                  '  No  ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size for buttons
                    color: Colors.white, // White text color
                  ),
                ),
              ),
              const SizedBox(width: 20), // Add space between buttons
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Return true after confirming save
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color:const Color.fromARGB(255, 182, 12, 12), // Border color for Save button
                    width: 3,
                  ),
                  backgroundColor:const Color.fromARGB(255, 182, 12, 12), // Background color
                ),
                child: const Text(
                  '  Yes  ',
                  style: TextStyle(
                    fontSize: 20, // Increase font size
                    color: Colors.white, // White text color
                  ),
                ),
              ),
            ],
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(vertical: 10), // Add padding for the actions
      );
    },
  ) ?? false; // If null, default to false
}

 Widget _buildDetailItem(String title, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: RichText(
      text: TextSpan(
        text: '$title ',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16, // Decrease font size here
          fontFamily: 'Georgia',

          color: Color.fromRGBO(24, 71, 137, 1), // Set title color
        ),
        children: [
          TextSpan(
            text: value,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 15, // Decrease font size for value
              color: Colors.grey, // Set value color to gray
            ),
          ),
        ],
      ),
    ),
  );
}

  
  
  
  void _showDonationPopup(BuildContext context ,  double donatedAmount, double totalAmount) {
  TextEditingController amountController = TextEditingController();
  bool isAnonymous = false; // Track anonymous donation state
  String? errorMessage;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter Donation Amount',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Amount',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    errorText: errorMessage, // Show error message if invalid
suffixIcon: Padding(
    padding: const EdgeInsets.only(right: 10, top: 10), // move ETH downward
    child: Text(
      'ETH',
      style: TextStyle(fontSize: 16, color: Colors.grey[700]),
    ),
  ),                  ),
                onChanged: (value) {
  setState(() {
    double? amount = double.tryParse(value);
    double remaining = totalAmount - donatedAmount;

    if (amount == null || amount <= 0) {
      errorMessage = "Please enter a valid amount greater than zero";
    } else if (amount > remaining) {
      errorMessage = "Amount exceeds remaining goal of ${remaining.toStringAsFixed(5)} ETH";
    } else {
      errorMessage = null;
    }
  });
},

                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: isAnonymous,
                      onChanged: (value) {
                        setState(() {
                          isAnonymous = value ?? false;
                        });
                      },
                    ),
                    const Text('Donate anonymously'),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: errorMessage == null
                      ? () async {
                          await _processDonation(amountController.text, isAnonymous);
                          Navigator.pop(context);
                        }
                      : null, // Disable if input is invalid
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Send', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      );
    },
  );
}

Future<void> _processDonation(String amount, bool isAnonymous) async {
  if (globalPrivateKey == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Private key is missing.')),
    );
    return;
  }

  if (widget.projectCreatorWallet.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Project creator address is empty or invalid.')),
    );
    return;
  }

  try {
    final credentials = EthPrivateKey.fromHex(globalPrivateKey!);
    final senderAddress = await credentials.extractAddress();

    if (amount.isEmpty || double.tryParse(amount) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid donation amount.')),
      );
      return;
    }

    final donationAmountInEth = double.parse(amount);
    final donationAmountInWei = BigInt.from(donationAmountInEth * 1e18);

    // Check balance
    final balance = await _web3client.getBalance(senderAddress);
    final gasPrice = await _web3client.getGasPrice();
    final gasLimit = BigInt.from(300000); // Estimated gas limit
    final totalGasFee = gasPrice.getInWei * gasLimit;

    if (balance.getInWei < (donationAmountInWei + totalGasFee)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient funds for donation and gas fees.')),
      );
      return;
    }

    // Load contract
    final donationContract = DeployedContract(
      ContractAbi.fromJson(_contractAbi, 'DonationContract'),
      EthereumAddress.fromHex('0x6753413d428794F8CE9a9359E1739450A8cfED45'),
    );

    final function = donationContract.function('donate');

    // Send transaction
    final transaction = web3.Transaction.callContract(
      contract: donationContract,
      function: function,
      parameters: [BigInt.from(widget.projectId), isAnonymous],
      value: EtherAmount.fromUnitAndValue(EtherUnit.wei, donationAmountInWei),
      gasPrice: gasPrice,
      maxGas: gasLimit.toInt(),
    );

    final result = await _web3client.sendTransaction(
      credentials,
      transaction,
      chainId: 11155111, // Sepolia Testnet
    );

    // Print transaction hash with check emoji
    print("Transaction successful! ✅ Hash: $result");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Donation successful! ✅')),
    );

    // Store donation details
// Store donation details
    await _storeDonationInfo(
      {
        'id': widget.projectId,
        'name': widget.projectName,
        'description': widget.description,
        'startDate': widget.startDate,
        'endDate': widget.deadline,
        'totalAmount': widget.totalAmount,
        'projectType': widget.projectType,
        'projectCreatorWallet': widget.projectCreatorWallet,
        'donatedAmount': donationAmountInEth,
      },
      donationAmountInEth
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error processing donation: $e')),
    );
  }
}

Future<void> _storeDonationInfo(Map<String, dynamic> projectDetails, double donatedAmount) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('walletAddress');
    
    if (address == null) {
      print("❌ No wallet address found");
      return;
    }

    // Get existing donations
    final donationsKey = 'donations_${address}';
    final donationsJson = prefs.getString(donationsKey) ?? '[]';
    final List<dynamic> donations = json.decode(donationsJson);

    print("📌 Current donations count: ${donations.length}");

    // Create donation info with all necessary details
    final donationInfo = {
      'id': projectDetails['id'],
      'name': projectDetails['name'],
      'description': projectDetails['description'],
      'donatedAmount': donatedAmount,
      'totalAmount': double.parse(projectDetails['totalAmount'].toString()),
      'projectType': projectDetails['projectType'],
      'endDate': projectDetails['endDate'] is int 
          ? projectDetails['endDate'] 
          : DateTime.parse(projectDetails['endDate'].toString()).millisecondsSinceEpoch,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'projectCreatorWallet': projectDetails['projectCreatorWallet'],
      'donorWallet': address,
    };
// Check if donation already exists
    final existingIndex = donations.indexWhere((d) => d['id'].toString() == projectDetails['id'].toString());
    if (existingIndex >= 0) {
      donations[existingIndex] = donationInfo;
      print("✅ Updated existing donation for project ${projectDetails['name']}");
    } else {
      donations.add(donationInfo);
      print("✅ Added new donation for project ${projectDetails['name']}");
    }

    // Save updated donations
    await prefs.setString(donationsKey, json.encode(donations));
    print("✅ Successfully stored ${donations.length} donations for wallet $address");

  } catch (e) {
    print("❌ Error storing donation info: $e");
  }
}

}
final String _contractAbi = '''[
  {
    "constant": true,
    "inputs": [{"name": "projectId", "type": "uint256"}],
    "name": "getProjectDonorsWithAmounts",
    "outputs": [
      {"name": "addresses", "type": "address[]"},
      {"name": "amounts", "type": "uint256[]"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "projectId", "type": "uint256"}],
    "name": "getProjectDonations",
    "outputs": [
      {"name": "totalDonations", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [{"name": "donor", "type": "address"}],
    "name": "getDonorInfo",
    "outputs": [
      {"name": "totalDonated", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "getContractBalance",
    "outputs": [
      {"name": "balance", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{"name": "_postProjectAddress", "type": "address"}],
    "name": "constructor",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "projectId", "type": "uint256"},
      {"name": "isAnonymous", "type": "bool"}
    ],
    "name": "donate",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "name": "donor", "type": "address"},
      {"indexed": false, "name": "amount", "type": "uint256"},
      {"indexed": true, "name": "projectCreator", "type": "address"},
      {"indexed": false, "name": "projectId", "type": "uint256"}
    ],
    "name": "DonationReceived",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {"indexed": true, "name": "projectCreator", "type": "address"},
      {"indexed": false, "name": "amount", "type": "uint256"}
    ],
    "name": "FundsTransferred",
    "type": "event"
  }
]''';


class DonorServices {
  final Web3Client _web3Client;
  final DeployedContract _contract;

  // Contract address and RPC URL as constants
  static const String _rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1'; // Sepolia RPC URL
  static const String _contractAddress = '0x6753413d428794F8CE9a9359E1739450A8cfED45'; // Contract address on Sepolia
  
  // Constructor for initializing Web3 client and contract
  DonorServices()
      : _web3Client = Web3Client(_rpcUrl, Client()),
        _contract = DeployedContract(
            ContractAbi.fromJson(_contractABI, 'DonationContract'),
            EthereumAddress.fromHex(_contractAddress));

  // Contract ABI (replace with actual ABI string)
  static const String _contractABI = ''' 
  [
    {
      "inputs": [{"internalType": "uint256", "name": "projectId", "type": "uint256"}],
      "name": "getProjectDonorsWithAmounts",
      "outputs": [
        {"internalType": "address[]", "name": "", "type": "address[]"},
        {"internalType": "uint256[]", "name": "", "type": "uint256[]"},
        {"internalType": "uint256[]", "name": "", "type": "uint256[]"}
      ],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "uint256", "name": "projectId", "type": "uint256"}],
      "name": "getProjectState",
      "outputs": [{"internalType": "string", "name": "", "type": "string"}],
      "stateMutability": "view",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "projectId", "type": "uint256"},
        {"internalType": "address", "name": "donor", "type": "address"}
      ],
      "name": "getDonorInfo",
      "outputs": [
        {"internalType": "uint256", "name": "", "type": "uint256"},
        {"internalType": "uint256", "name": "", "type": "uint256"}
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  // Fetch the project donors from the blockchain
  Future<List<dynamic>> fetchProjectDonors(BigInt projectId) async {
    final getDonorsFunction = _contract.function('getProjectDonorsWithAmounts');
    final result = await _web3Client.call(
      contract: _contract,
      function: getDonorsFunction,
      params: [projectId],
    );

    if (result.isEmpty) {
      print("❌ No donors found for project.");
      return [];
    }

    return result;
  }

  // Fetch project state to check if voting has started
  Future<String> fetchProjectState(BigInt projectId) async {
    final getProjectStateFunction = _contract.function('getProjectState');
    final result = await _web3Client.call(
      contract: _contract,
      function: getProjectStateFunction,
      params: [projectId],
    );

    return result[0]; // Assuming the state is a string like "VotingStarted"
  }


// Check if the user has donated to the project and if voting has started
Future<bool> checkIfDonorCanVote(BigInt projectId, String userAddress) async {
  try {
    print("📌 Starting donor check for project ID: $projectId");
    print("👤 Checking for user address: $userAddress");

    if (userAddress == "null" || userAddress.isEmpty) {
      print("❌ Invalid user address provided.");
      return false;
    }

    final normalizedUserAddress = userAddress.toLowerCase();

    // Fetch Firestore project data (to check if project is canceled)
    final firestoreData = await fetchProjectFirestoreData(projectId);
    print("📄 Firestore data: $firestoreData");

 final donorsResult = await fetchProjectDonors(projectId);
    print("📦 Donors fetched from blockchain: $donorsResult");

    List<EthereumAddress> donorAddresses = List<EthereumAddress>.from(donorsResult[0]);
    print("📜 List of donor addresses:");
    donorAddresses.forEach((addr) => print("   ➤ ${addr.hex}"));

    bool isDonor = donorAddresses.any(
      (address) => address.hex.toLowerCase() == normalizedUserAddress,
    );

  if (isDonor) return true;
    // else return false;

    print(isDonor
        ? "✅ User IS a donor for this project."
        : "❌ User is NOT a donor for this project.");

 bool isCanceled = firestoreData['isCanceled'] ?? false;
    if (isCanceled) {
      print(" ✅  Project is canceled.  Voting has started.");
    }

   

    try {
      // Fetch project state from blockchain
      final projectState = await fetchProjectState(projectId);
      print("📊 Project state fetched: $projectState");

      if (projectState == "VotingStarted") {
        print("🗳️ Voting has started. User can vote.");
        return true;
      } else {
        print("🚫 Voting has not started yet.");
        return false;
      }
    } catch (e) {
      print("❗ Error while fetching project state: $e");
      return false;
    }
  } catch (e) {
    print("⚠️ Error in checkIfDonorCanVote: $e");
    return false;
  }
}

// Fetch Firestore data for project status (e.g., canceled or voting initiated)

Future<Map<String, dynamic>> fetchProjectFirestoreData(BigInt projectId) async {
  try {
    // Reference to the Firestore collection containing project data
    final projectDocRef = FirebaseFirestore.instance.collection('projects').doc(projectId.toString());

    // Fetch the document data
    final projectSnapshot = await projectDocRef.get();

    if (projectSnapshot.exists) {
      // Document found, returning the necessary fields
      final projectData = projectSnapshot.data()!;
      return {
        'isCanceled': projectData['isCanceled'] ?? false,
        'votingInitiated': projectData['votingInitiated'] ?? false,
      };
    } else {
      print("❌ Project not found in Firestore.");
      return {
        'isCanceled': false,
        'votingInitiated': false,
      };
    }
  } catch (e) {
    print("⚠️ Error fetching project data from Firestore: $e");
    return {
      'isCanceled': false,
      'votingInitiated': false,
    };
  }
}
Future<double> getProjectDonations(BigInt projectId) async {
  try {
    final getDonorsFunction = _contract.function('getProjectDonations');
    final result = await _web3Client.call(
      contract: _contract,
      function: getDonorsFunction,
      params: [projectId],
    );

    if (result.isEmpty) {
      print("No donations found for project $projectId");
      return 0.0;
    }

    final donationAmountInWei = result[0] as BigInt;
    final donationAmountInEth = donationAmountInWei.toDouble() / 1e18;
    print("✅ Project $projectId donation amount: $donationAmountInEth ETH");
    return donationAmountInEth;
  } catch (e) {
    print("❌ Error fetching donation amount for project $projectId: $e");
    return 0.0;
  }
}

}




class ReportPopup extends StatefulWidget {
   final String projectCreatorWallet;
  final int projectId;

  const ReportPopup({
    super.key,
    required this.projectCreatorWallet,
    required this.projectId,
  });
  @override
  _ReportPopupState createState() => _ReportPopupState();
}

class _ReportPopupState extends State<ReportPopup> {
  // late String targetCharityAddress; 
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  
  int titleLength = 0;
  int descriptionLength = 0;
  final int titleMax = 30;
  final int descriptionMax = 300;

  // Flags for validation
  bool isTitleEmpty = false;
  bool isDescriptionEmpty = false;

  @override
  void initState() {
    super.initState();
 // Assign the wallet address from the organization data
    // targetCharityAddress = widget.organization["wallet"] ?? "";
    // print("Target Charity Address: $targetCharityAddress"); // Debugging print
    titleController.addListener(() {
      setState(() {
        titleLength = titleController.text.length;
        isTitleEmpty = titleController.text.isEmpty;
      });
    });

    descriptionController.addListener(() {
      setState(() {
        descriptionLength = descriptionController.text.length;
        isDescriptionEmpty = descriptionController.text.isEmpty;
      });
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    // Get the address and validate it before passing
    // String orgAddress = widget.organization["wallet"] ?? "Unknown";
    // print("Organization Wallet Address: $orgAddress");


  return AlertDialog(
    
    backgroundColor: Colors.white,
   title: Stack(
    
  children: [


    Center(
      child: const Text(
        "Report",
        style: TextStyle(
          color: Color.fromRGBO(24, 71, 137, 1),
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),

    content: Column(
      mainAxisSize: MainAxisSize.min,
      
      children: [
        SizedBox(height: 20),
        TextField(
          controller: titleController,
          maxLength: titleMax,
          decoration: InputDecoration(
            labelText: "Title*",
            labelStyle: const TextStyle(color: Colors.grey),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            counterText: "$titleLength/$titleMax", // Dynamic counter
            counterStyle: TextStyle(color: titleLength >= titleMax ? Colors.red : Colors.grey),
          ),
        ),
        const SizedBox(height: 1),
        if (isTitleEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 130),
            child: Text(
              "Title is required.",
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: descriptionController,
          maxLength: descriptionMax,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: "Description*",
            labelStyle: const TextStyle(color: Colors.grey),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.only(top: 20, left: 12, right: 12, bottom: 12),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            counterText: "$descriptionLength/$descriptionMax", // Dynamic counter
            counterStyle: TextStyle(color: descriptionLength >= descriptionMax ? Colors.red : Colors.grey),
          ),
        ),
        if (isDescriptionEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 100),
            child: Text(
              "Description is required.",
              style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    ),
   actions: [
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      OutlinedButton(
        onPressed: () async {
      bool leave = await _showLeaveConfirmationDialog(context);
      if (leave) {
        Navigator.pop(context); // Close the report popup and leave
      }
    },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(
            color: Color.fromRGBO(24, 71, 137, 1), // Border color
            width: 2.5, // Increase the border width here
          ),
           backgroundColor:  Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20) ), // Rounded border
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Padding
        ),
        child: const Text(
          " Cancel ",
          style: TextStyle(color: Color.fromRGBO(24, 71, 137, 1),  fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      const SizedBox(width: 20),
      ElevatedButton(
        onPressed: () async {
          if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
            setState(() {
              isTitleEmpty = titleController.text.isEmpty;
              isDescriptionEmpty = descriptionController.text.isEmpty;
            });
          } else {
            await _showSendConfirmationDialog(context);
             Navigator.pop(context, true);

              
//  showSuccessPopup(context); // Call the popup here
            
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Rounded border
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), // Padding
        ),
        child: const Text(
          "  Send  ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    ],
  ),
],

  );
}


  Future<bool> _showLeaveConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Confirm Leaving',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to leave without sending the report?',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                  onPressed: () {
                    
                    Navigator.pop(context, true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(212, 63, 63, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(212, 63, 63, 1),
                  ),
                  child: const Text(
                    '   Yes   ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(vertical: 10),
        );
      },
    ) ??
        false;
  }

  Future<bool> _showSendConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Confirm Sending',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to send the report?',
            style: TextStyle(
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3.5,
                    ),
                    backgroundColor:  Colors.white,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color.fromRGBO(24, 71, 137, 1),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                OutlinedButton(
                   onPressed: () async {
                try {
                  final walletAddress = await _loadAddress();

                  if (walletAddress == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error: Wallet address not found. Please log in again.')),
                    );
                    return;
                  }

                  final title = titleController.text.trim();
                  final description = descriptionController.text.trim();

                  if (title.isEmpty || description.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter both title and description.')),
                    );
                    return;
                  }

                await FirebaseFirestore.instance.collection('reports').add({
  'title': title,
  'description': description,
  'complainant': walletAddress,
  'targetCharityAddress': widget.projectCreatorWallet,
  'project_id': widget.projectId,
  'timestamp': FieldValue.serverTimestamp(),
  'complaintType': 'project', // ✅ Added the complaintType field
});

                  Navigator.pop(context, true);
                  showSuccessPopup(context);
                } catch (e) {
                  print("❌ Error submitting complaint: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to submit complaint: $e')),
                  );
                }
              },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Color.fromRGBO(24, 71, 137, 1),
                      width: 3,
                    ),
                    backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  ),
                  child: const Text(
                    '   Yes   ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(vertical: 10),
        );
      },
    ) ??
        false;
        
  }
  void showSuccessPopup(BuildContext context) {
  // Show dialog
  showDialog(
    context: context,
    barrierDismissible: true, // Allow closing the dialog by tapping outside
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(20), // Add padding around the dialog content
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded corners for a better look
        ),
        content: SizedBox(
          width: 250, // Set a custom width for the dialog
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ensure the column only takes the required space
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle, 
                color: Color.fromARGB(255, 54, 142, 57), 
                size: 50, // Bigger icon
              ),
              SizedBox(height: 20), // Add spacing between the icon and text
              Text(
                'Complaint sent successfully!',
                style: TextStyle(
                  color: const Color.fromARGB(255, 54, 142, 57), 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16, // Bigger text
                ),
                textAlign: TextAlign.center, // Center-align the text
              ),
            ],
          ),
        ),
      );
    },
  );

  // Automatically dismiss the dialog after 3 seconds
  Future.delayed(const Duration(seconds: 3), () {
    // Check if the widget is still mounted before performing Navigator.pop
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
    }
     Navigator.pop(context, true);
  });
}

 // Method to load the wallet address from SharedPreferences
  Future<String?> _loadAddress() async {
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

}