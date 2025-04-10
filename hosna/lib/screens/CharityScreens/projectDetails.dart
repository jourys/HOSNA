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
  int? userType;
  final TextEditingController amountController = TextEditingController();
  String? globalWalletAddress;
  bool _isFetchingDonatedAmount = false;
  bool isCanceled = false; // Default value
  String projectState = "";
  // Web3 Variables
  late Web3Client _web3client;
  final String rpcUrl =
      "https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1";
  final EthereumAddress contractAddress =
      EthereumAddress.fromHex("0x95a20778c2713a11ff61695e57cd562f78f75754");
  bool isLoading = true;
  final BlockchainService _blockchainService = BlockchainService();
  
  @override
  void initState() {
    super.initState();
    _listenToProjectState();
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
  
  }

StreamSubscription<DocumentSnapshot>? _projectSubscription;
void _listenToProjectState() {
  _projectSubscription = FirebaseFirestore.instance
      .collection('projects')
      .doc(widget.projectId.toString())
      .snapshots()
      .listen((doc) {
    if (doc.exists) {
      setState(() {
        isCanceled = (doc['isCanceled'] is bool) ? doc['isCanceled'] : doc['isCanceled'] == "canceled";
        projectState = isCanceled
            ? "canceled"
            : getProjectState(doc.data() as Map<String, dynamic>);
        
        print("Firestore data: ${doc.data()}");
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

      if (privateKey == null) {
        print("Error: Private key not found for wallet address.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Private key not found for wallet address.')),
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

    return getProjectState(project); // Use the utility function
  }

String getProjectState(Map<String, dynamic> project) {
  if (isCanceled == "canceled") {
    print("Project is canceled globally.");
    return "canceled"; // If the project is canceled globally, return this state
  }

  DateTime now = DateTime.now();

  // Handle startDate (could be DateTime, String, or null)
  DateTime startDate;
  if (project['startDate'] == null) {
    return "upcoming"; // If startDate is null, assume the project is upcoming
  } else if (project['startDate'] is DateTime) {
    startDate = project['startDate'];
  } else {
    startDate = DateTime.parse(project['startDate']);
  }

  // Handle endDate (could be DateTime, String, or null)
  DateTime endDate;
  if (project['endDate'] == null) {
    return "active"; // If endDate is null, assume the project is active
  } else if (project['endDate'] is DateTime) {
    endDate = project['endDate'];
  } else {
    endDate = DateTime.parse(project['endDate']);
  }

  // Handle totalAmount (could be int, String, or null)
  double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
  double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

  // Check if the current date is before the start date
  if (now.isBefore(startDate)) {
    return "upcoming"; // Project is upcoming
  }

  // Check if the project has reached the goal
  if (donatedAmount >= totalAmount) {
    return "in-progress"; // Project reached the goal
  }

  // Check if the project failed (past the end date and not completed)
  if (now.isAfter(endDate)) {
    return "failed"; // Project failed to reach the target
  }

  // Check if the project is active
  if (now.isAfter(startDate) && now.isBefore(endDate) && donatedAmount < totalAmount && isCanceled != "canceled") {
    return "active"; // Project is ongoing and goal is not reached yet
  }

  return "unknown"; // If none of the conditions match, return an unknown state
}

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "in-progress":
        return Colors.purple;
      case "completed":
        return Colors.blue;
         case "canceled":
      return Colors.orange; // Add orange for canceled status

      default:
        return Colors.grey;
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
  String projectState = isCanceled ? "canceled" : _getProjectState();
  print("Project status: $projectState");

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
   
       GestureDetector(
      onTap: () {
        // Add the function to handle the flag press here
        print("Report Project Pressed!");
        // You can replace the print statement with your actual logic, 
        // such as navigating to a report page or opening a dialog.
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
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stateColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  projectState,
                                  style: TextStyle(
                                      color: stateColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                           SizedBox(height: 20),
                           if (userType == 1 &&
                              widget.projectCreatorWallet == globalWalletAddress) 
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
                                onPressed: () => _showDonationPopup(context),
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
                          if (userType == 0)
                            FutureBuilder<bool>(
                              future: _blockchainService.hasDonatedToProject(
                                widget.projectId,
                                globalWalletAddress ?? '',
                              ),
                              builder: (context, hasDonatedSnapshot) {
                                print("Has donated to project: ${hasDonatedSnapshot.data}");
                                if (hasDonatedSnapshot.hasData && hasDonatedSnapshot.data == true) {
                                  return FutureBuilder<bool>(
                                    future: _blockchainService.hasExistingVoting(widget.projectId),
                                    builder: (context, hasVotingSnapshot) {
                                      print("Has existing voting: ${hasVotingSnapshot.data}");
                                      if (hasVotingSnapshot.hasData && hasVotingSnapshot.data == true) {
                                        return Center(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 20),
                                            child: ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => DonorVoting(
                                                      projectId: widget.projectId,
                                                      walletAddress: globalWalletAddress ?? '',
                                                      projectName: widget.projectName,
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 100, vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(15)),
                                              ),
                                              child: const Text('Vote',
                                                  style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white)),
                                            ),
                                          ),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    },
                                  );
                                }
                                return SizedBox.shrink();
                              },
                            ),
                        if (userType == 1 &&
                              (projectState == "failed" || projectState == "canceled") &&
                              widget.projectCreatorWallet == globalWalletAddress)
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InitiateVoting(
                                        projectId: widget.projectId,
                                        failedProjectAmount: widget.totalAmount,
                                        walletAddress: globalWalletAddress ?? '',
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 100, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text('Initiate Voting',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),

                          
                          if (userType == 1 &&
                              projectState == "in-progress" &&
                              widget.projectCreatorWallet == globalWalletAddress)
                            Center(
                              child: ElevatedButton(
                                onPressed: () => print("post update"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 100, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                ),
                                child: const Text('Post Update',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                            ),
                     

                    
                          if (userType == 1 &&
                              projectState == "active" &&
                              widget.projectCreatorWallet == globalWalletAddress)
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

  
  
  
  void _showDonationPopup(BuildContext context) {
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
                  ),
                  onChanged: (value) {
                    setState(() {
                      double? amount = double.tryParse(value);
                      errorMessage = (amount == null || amount <= 0)
                          ? "Please enter a valid amount greater than zero"
                          : null;
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
      EthereumAddress.fromHex('0x0913167630dac537dd9477c68c3c7806159871C9'),
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
    await _storeDonation(senderAddress.hex, donationAmountInEth, isAnonymous);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error processing donation: $e')),
    );
  }
}

Future<void> _storeDonation(String donorAddress, double amount, bool isAnonymous) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String key = 'donationData_$donorAddress';
  String? existingData = prefs.getString(key);

  Map<String, dynamic> donationData = existingData != null
      ? jsonDecode(existingData)
      : {'totalDonated': 0.0, 'isAnonymous': false};

  // Update total donation amount
  donationData['totalDonated'] = (donationData['totalDonated'] as double) + amount;

  // Update anonymity status (if latest donation is anonymous, keep true)
  if (isAnonymous) {
    donationData['isAnonymous'] = true;
  }

  await prefs.setString(key, jsonEncode(donationData));

  print("Stored Data After Donation: $donationData");
}



}final String _contractAbi = '''[
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

