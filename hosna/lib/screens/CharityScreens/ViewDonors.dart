import 'package:flutter/material.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class ViewDonorsPage extends StatefulWidget {
  final int projectId;

  const ViewDonorsPage({super.key, required this.projectId});

  @override
  _ViewDonorsPageState createState() => _ViewDonorsPageState();
}

class _ViewDonorsPageState extends State<ViewDonorsPage> {
  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String donationContractAddress = '0x74409493A94E68496FA90216fc0A40BAF98CF0B9';
  final String donorContractAddress = '0x8a69415dcb679d808296bdb51dFcb01A4Cd2Bb79';

  late Web3Client _web3Client;
  late DeployedContract _donationContract;
  late ContractFunction _getProjectDonorsWithAmounts;

  late DeployedContract _donorContract;
  late ContractFunction _getDonor;

  List<Map<String, dynamic>> donorProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeContracts();
  }

  Future<void> _initializeContracts() async {
    _web3Client = Web3Client(rpcUrl, Client());

    final donationAbi = '''
    [
      {
        "constant": true,
        "inputs": [{"name": "projectId", "type": "uint256"}],
        "name": "getProjectDonorsWithAmounts",
        "outputs": [
          {"name": "", "type": "address[]"},
          {"name": "", "type": "uint256[]"},
          {"name": "", "type": "uint256[]"}
        ],
        "stateMutability": "view",
        "type": "function"
      }
    ]
    ''';

    final donorAbi = '''
[
  {
    "constant": true,
    "inputs": [{"name": "_wallet", "type": "address"}],
    "name": "getDonor",
    "outputs": [
      {"name": "", "type": "string"},
      {"name": "", "type": "string"},
      {"name": "", "type": "string"},
      {"name": "", "type": "string"},
      {"name": "", "type": "address"},
      {"name": "", "type": "bool"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

    _donationContract = DeployedContract(
      ContractAbi.fromJson(donationAbi, 'DonationContract'),
      EthereumAddress.fromHex(donationContractAddress),
    );
    _getProjectDonorsWithAmounts = _donationContract.function('getProjectDonorsWithAmounts');

    _donorContract = DeployedContract(
      ContractAbi.fromJson(donorAbi, 'DonorContract'),
      EthereumAddress.fromHex(donorContractAddress),
    );
    _getDonor = _donorContract.function('getDonor');

    await _fetchDonorsWithProfiles();
  }

  Future<String?> _fetchProfilePicture(String walletAddress) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(walletAddress)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        return userDoc['profile_picture'];
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
    }
    return null;
  }

  Future<void> _fetchDonorsWithProfiles() async {
    try {
      final result = await _web3Client.call(
        contract: _donationContract,
        function: _getProjectDonorsWithAmounts,
        params: [BigInt.from(widget.projectId)],
      );

      final addresses = result[0] as List;
      final anonymousAmounts = result[1] as List;
      final nonAnonymousAmounts = result[2] as List;

      List<Map<String, dynamic>> donors = [];

      for (int i = 0; i < addresses.length; i++) {
        final EthereumAddress addr = addresses[i];
        final BigInt anonAmount = anonymousAmounts[i];
        final BigInt nonAnonAmount = nonAnonymousAmounts[i];

          try {
            final profile = await _web3Client.call(
              contract: _donorContract,
              function: _getDonor,
              params: [addr],
            );

            final walletAddress = profile[4].toString();
            final profilePic = await _fetchProfilePicture(walletAddress);

            donors.add({
              'firstName': profile[0],
              'lastName': profile[1],
              'email': profile[2],
              'phone': profile[3],
              'wallet': walletAddress,
              'anonymousAmount': anonAmount,
              'nonAnonymousAmount': nonAnonAmount,
              'profile_picture': profilePic,
            });
          } catch (e) {
            print("Error fetching profile: $e");
          }
        }
      

      setState(() {
        donorProfiles = donors;
        _isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDetails(Map<String, dynamic> donor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DonorDetailsPage(donor: donor),
      ),
    );
  }

  Widget _buildProfileImage(String? url) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
        radius: 30,
      );
    } else {
      return Icon(Icons.account_circle, size: 60, color: Colors.grey);
    }
  }
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        "Donors",
        style: TextStyle(
          color: Color.fromRGBO(24, 71, 137, 1),
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
      iconTheme: IconThemeData(color: Color.fromRGBO(24, 71, 137, 1)),
    ),
    body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : donorProfiles.isEmpty
            ? Center(
                child: Text(
                  "No donors found.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView.builder(
                itemCount: donorProfiles.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final donor = donorProfiles[index];
                  final double anon = donor['anonymousAmount'].toDouble() / 1e18;
                  final double nonAnon = donor['nonAnonymousAmount'].toDouble() / 1e18;

                  List<Widget> tiles = [];

                  if (nonAnon > 0) {
                    tiles.add(
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        color: Colors.white, // Set the background color to white
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: _buildProfileImage(donor['profile_picture']),
                          title: Text(
                            donor['firstName'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              "Donated amount: ${nonAnon.toStringAsFixed(8)} ETH",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                          onTap: () => _navigateToDetails(donor),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                          children: [
  GestureDetector(
    onTap: () async {
      bool? result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return ReportDonorPopup(donor: donor);
        },
      );
      if (result == true) {
        // Handle the successful report sending here
      }
    },
    child: Icon(Icons.flag, size: 32, color: Colors.grey),
  ),
],

                          ),
                        ),
                      ),
                    );
                  }

                  if (anon > 0) {
                    tiles.add(
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        color: Colors.white, // Set the background color to white
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(Icons.account_circle, size: 50, color: Colors.grey[400]),
                          title: Text(
                            "Anonymous",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              "Donated amount: ${anon.toStringAsFixed(8)} ETH",
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                           children: [
  GestureDetector(
    onTap: () async {
      bool? result = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return ReportDonorPopup(donor: donor);
        },
      );
      if (result == true) {
        // Handle the successful report sending here
      }
    },
    child: Icon(Icons.flag, size: 32, color: Colors.grey),
  ),
],

                          ),
                        ),
                      ),
                    );
                  }

                  return Column(children: tiles);
                },
              ),
  );
}
}

class ReportDonorPopup extends StatefulWidget {
  final Map<String, dynamic> donor;

  const ReportDonorPopup({super.key, required this.donor});

  @override
  _ReportDonorPopupState createState() => _ReportDonorPopupState();
}

class _ReportDonorPopupState extends State<ReportDonorPopup> {
  late String targetDonorAddress;
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  int titleLength = 0;
  int descriptionLength = 0;
  final int titleMax = 30;
  final int descriptionMax = 300;

  bool isTitleEmpty = false;
  bool isDescriptionEmpty = false;

  @override
  void initState() {
    super.initState();
    targetDonorAddress = widget.donor["wallet"] ?? "";
    print("Target Donor Address: $targetDonorAddress");

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
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Center(
        child: Text(
          "Report Donor",
          style: TextStyle(
            color: Color.fromRGBO(24, 71, 137, 1),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            maxLength: titleMax,
            decoration: InputDecoration(
              labelText: "Title*",
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              counterText: "$titleLength/$titleMax",
              counterStyle: TextStyle(color: titleLength >= titleMax ? Colors.red : Colors.grey),
            ),
          ),
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
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              counterText: "$descriptionLength/$descriptionMax",
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
                if (leave) Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 2.5),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                " Cancel ",
                style: TextStyle(color: Color.fromRGBO(24, 71, 137, 1), fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
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
                  // showSuccessPopup(context); // Reuse the same success popup
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
    // You can reuse the same leave dialog from the organization popup
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Confirm Leaving',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            content: const Text(
              'Are you sure you want to leave without sending the report?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 3),
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromRGBO(212, 63, 63, 1), width: 3),
                      backgroundColor: Color.fromRGBO(212, 63, 63, 1),
                    ),
                    child: const Text('   Yes   ', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showSendConfirmationDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Confirm Sending',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            content: const Text(
              'Are you sure you want to send the report?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 3.5),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 20, color: Color.fromRGBO(24, 71, 137, 1))),
                  ),
                  const SizedBox(width: 20),
                  OutlinedButton(
onPressed: () async {
  if (targetDonorAddress.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error: Donor wallet address is missing!')),
    );
    return;
  }

  try {
    final walletAddress = await _loadWalletAddress();

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
      'targetCharityAddress': targetDonorAddress,
      'complainant': walletAddress,
      'timestamp': FieldValue.serverTimestamp(),
      'resolved': false,
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




    //                 onPressed: () async {
    //                   if (targetDonorAddress.isEmpty) {
    //                     ScaffoldMessenger.of(context).showSnackBar(
    //                       const SnackBar(content: Text('Error: Donor wallet address is missing!')),
    //                     );
    //                     return;
    //                   }

    //                   try {
    //                     final complaintService = ComplaintService(
    //                     rpcUrl: 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1' , // Replace securely
    //   contractAddress: '0x89284505E6EbCD2ADADF3d1B5cbc51B3568CcFd1', // Replace securely
    // );

    //                     String result = await complaintService.sendComplaint(
    //                       title: titleController.text.trim(),
    //                       description: descriptionController.text.trim(),
    //                       targetCharityAddress: targetDonorAddress, // It's the donor this time
    //                     );

    //                     if (result.startsWith('Error')) {
    //                       ScaffoldMessenger.of(context).showSnackBar(
    //                         SnackBar(content: Text('Failed to send complaint: $result')),
    //                       );
    //                     } else {
    //                       Navigator.pop(context, true);
    //                       showSuccessPopup(context);
    //                     }
    //                   } catch (e) {
    //                     print("Exception: $e");
    //                   }
    //                 },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color.fromRGBO(24, 71, 137, 1), width: 3.5),
                      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                    ),
                    child: const Text(' Send ', style: TextStyle(fontSize: 20, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ) ??
        false;
  }

 // Method to load the wallet address from SharedPreferences
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
                'Complaint send successfully!',
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
    Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
  Navigator.of(context, rootNavigator: true).pop(); 
   });
}

}








class DonorDetailsPage extends StatelessWidget {
  final Map<String, dynamic> donor;

  const DonorDetailsPage({super.key, required this.donor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color.fromRGBO(24, 71, 137, 1)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${donor['firstName']}'s Profile",
          style: TextStyle(
            color: Color.fromRGBO(24, 71, 137, 1),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            children: [
              SizedBox(height: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  donor['profile_picture'] != null
                      ? CircleAvatar(
                          backgroundImage: NetworkImage(donor['profile_picture']),
                          radius: 60,
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          child: Icon(Icons.person, size: 60, color: Colors.white),
                        ),

                ],
              ),
              SizedBox(height: 65),
              ProfileItem(title: "Name", value: "${donor['firstName']} ${donor['lastName']}"),
              Divider(),
              ProfileItem(title: "Email", value: donor['email']),
              Divider(),
              ProfileItem(title: "Phone", value: donor['phone']),
            ],
          ),
        ),
      ),
    );
  }
}


class ProfileItem extends StatelessWidget {
  final String title;
  final String value;

  const ProfileItem({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            _getIconForTitle(title),
            color: Color.fromRGBO(24, 71, 137, 1), // Updated color
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromRGBO(24, 71, 137, 1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'name':
        return Icons.person;
      case 'email':
        return Icons.email;
      case 'phone':
        return Icons.phone;
      default:
        return Icons.info;
    }
  }
}

