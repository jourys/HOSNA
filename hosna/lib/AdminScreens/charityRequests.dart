import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hosna/AdminScreens/AdminSidebar.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;


class CharityRequests extends StatefulWidget {
  @override
  _CharityRequestsState createState() => _CharityRequestsState();
}

class _CharityRequestsState extends State<CharityRequests> {
  List<String> pendingWalletAddresses = [];
  Map<String, Map<String, dynamic>> charityDetails = {};
 bool isSidebarVisible = true;
  @override
  void initState() {
    super.initState();
    _loadCharityRequests();
  }

Future<List<String>> fetchPendingCharities() async {
  List<String> walletAddresses = [];

  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('accountStatus', isEqualTo: 'pending')
        .where('userType', isEqualTo: 1)
        .get();

    snapshot.docs.forEach((doc) {
      walletAddresses.add(doc['walletAddress']);
    });
  } catch (e) {
    print("Error fetching charity wallet addresses: $e");
  }

  return walletAddresses;
}

  Future<void> _loadCharityRequests() async {
    // Fetch pending charity wallet addresses from Firebase
    List<String> walletAddresses = await fetchPendingCharities();
    setState(() {
      pendingWalletAddresses = walletAddresses;
    });

    // Fetch details for each wallet address from the smart contract
    for (String walletAddress in walletAddresses) {
      CharityService charityService = CharityService();
      var details = await charityService.getCharityDetails(walletAddress);

      setState(() {
        charityDetails[walletAddress] = details;
      });
    }
  }

  @override@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Row(
      children: [
        AdminSidebar(), // Sidebar added
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Charity Requests', // Page title
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(24, 71, 137, 1), // Custom color
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(isSidebarVisible ? Icons.menu_open : Icons.menu),
                  onPressed: () {
                    setState(() {
                      isSidebarVisible = !isSidebarVisible;
                    });
                  },
                ),
              ),
              Expanded(
                child: pendingWalletAddresses.isEmpty
                    ? Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: EdgeInsets.all(16.0),
                        itemCount: pendingWalletAddresses.length,
                        itemBuilder: (context, index) {
                          String walletAddress = pendingWalletAddresses[index];
                          var details = charityDetails[walletAddress];

                          if (details == null) {
                            return ListTile(
                              title: Text('Loading...'),
                            );
                          }

                          return GestureDetector(
                            onTap: () {
                          showDialog(
  context: context,
  builder: (BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white, // Background color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15), // Optional: Rounded corners
      ),
      child: Container(
width: 600, // Set a fixed square width
        height: 600, // Set a fixed square height        padding: EdgeInsets.all(20), // Padding around content
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center, // Center align title
          children: [
            // Title with Charity Name, Centered
             SizedBox(height: 35), // Space below title
            Text(
              details['name'] ?? 'Charity Name',
              textAlign: TextAlign.center, // Ensure text is centered
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(24, 71, 137, 1),
              ),
            ),
            SizedBox(height: 50), // Space below title
            
            // Charity Details (Shifted slightly to the right)
            Align(
              alignment: Alignment.centerLeft, // Align text to left
              child: Padding(
                padding: EdgeInsets.only(left: 30), // Slight right shift
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Email:', details['email']),
                    _buildDetailRow('Phone:', details['phone']),
                    _buildDetailRow('License Number:', details['licenseNumber']),
                    _buildDetailRow('City:', details['city']),
                    _buildDetailRow('Website:', details['website']),
                    _buildDetailRow('Description:', details['description']),
                    _buildDetailRow('Establishment Date:', details['establishmentDate']),
                  ],
                ),
              ),
            ),

            SizedBox(height: 80), // Space before buttons
            
            // Centered Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 197, 47, 36), // Reject button color
                    minimumSize: Size(120, 50),
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  onPressed: () async {
                     if (walletAddress != null && walletAddress.isNotEmpty) {
    try {
      await FirebaseFirestore.instance
          .collection('users') // Collection name: users
          .doc(walletAddress) // Document ID: walletAddress
          .update({'accountStatus': 'rejected'});

      print('Account status updated successfully.');
    } catch (e) {
      print('Error updating account status: $e');
    }
  }

showStatusSuccessPopup( context);
},
                  child: Text('Reject', style: TextStyle(color: Colors.white)),
                ),
                SizedBox(width: 60), // Space between buttons
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 54, 142, 57), // Approve button color
                    minimumSize: Size(120, 50),
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 22),
                    textStyle: TextStyle(fontSize: 18),
                  ),
                 
onPressed: () async {
  
  if (walletAddress != null && walletAddress.isNotEmpty) {
    try {
      await FirebaseFirestore.instance
          .collection('users') // Collection name: users
          .doc(walletAddress) // Document ID: walletAddress
          .update({'accountStatus': 'approved'});

      print('Account status updated successfully.');
    } catch (e) {
      print('Error updating account status: $e');
    }
  }

   showStatusSuccessPopup( context);
},
                  child: Text('Approve', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 15.0 , vertical: 10.0),
                              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), // Increased padding
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.0), // Increased border radius
                                border: Border.all(
                                  color: Color.fromRGBO(24, 71, 137, 1),
                                  width: 3.0, // Slightly thicker border
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  details['name'] ?? 'No name',
                                  style: TextStyle(
                                    color: Color.fromRGBO(24, 71, 137, 1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20.0, // Larger font size
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}



void showStatusSuccessPopup(BuildContext context) {
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
                'Account status updated successfully!',
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
  });
}


// Helper function for formatting detail rows
Widget _buildDetailRow(String label, String? value) {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 8), // Spacing between rows
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color.fromRGBO(24, 71, 137, 1),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value ?? 'No data',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    ),
  );
}


}







class CharityService {
  final String rpcUrl = 'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';

  final String contractAddress = '0x02b0d417D48eEA64Aae9AdA80570783034ED6839';
  late Web3Client _client;
  late DeployedContract _contract;
  late ContractFunction _getCharityFunction;
String abi = '''
[
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "_name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_email",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_phone",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_licenseNumber",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_city",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_description",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_website",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "_establishmentDate",
        "type": "string"
      },
      {
        "internalType": "address",
        "name": "_wallet",
        "type": "address"
      },
      {
        "internalType": "string",
        "name": "_password",
        "type": "string"
      }
    ],
    "name": "registerCharity",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "_email",
        "type": "string"
      }
    ],
    "name": "checkCharityExists",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getAllCharities",
    "outputs": [
      {
        "internalType": "address[]",
        "name": "wallets",
        "type": "address[]"
      },
      {
        "internalType": "string[]",
        "name": "names",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "emails",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "phones",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "cities",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "websites",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "descriptions",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "licenseNumbers",
        "type": "string[]"
      },
      {
        "internalType": "string[]",
        "name": "establishmentDates",
        "type": "string[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "string",
        "name": "_email",
        "type": "string"
      },
      {
        "internalType": "address",
        "name": "_wallet",
        "type": "address"
      }
    ],
    "name": "forceLinkEmailToWallet",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "_wallet",
        "type": "address"
      }
    ],
    "name": "getCharity",
    "outputs": [
      {
        "internalType": "string",
        "name": "name",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "email",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "phone",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "licenseNumber",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "city",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "description",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "website",
        "type": "string"
      },
      {
        "internalType": "string",
        "name": "establishmentDate",
        "type": "string"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  CharityService() {

    _client = Web3Client(rpcUrl, http.Client());
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'CharityRegistration'),
      EthereumAddress.fromHex(contractAddress),
    );
    _getCharityFunction = _contract.function('getCharity');
  }

  Future<Map<String, dynamic>> getCharityDetails(String walletAddress) async {
    EthereumAddress address = EthereumAddress.fromHex(walletAddress);
    List<dynamic> results = await _client.call(
      contract: _contract,
      function: _getCharityFunction,
      params: [address],
    );

    return {
      'name': results[0],
      'email': results[1],
      'phone': results[2],
      'licenseNumber': results[3],
      'city': results[4],
      'description': results[5],
      'website': results[6],
      'establishmentDate': results[7],
    };
  }
}
