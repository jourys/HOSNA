import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For formatted date (optional)

class OrganizationsPage extends StatefulWidget {
  final String walletAddress;
  const OrganizationsPage({super.key, required this.walletAddress});

  @override
  _OrganizationsPageState createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends State<OrganizationsPage> {
  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0xa4234E1103A8d00c8b02f15b7F3f1C2eDbf699b7';

  late Web3Client _client;
  late DeployedContract _contract;
  List<Map<String, dynamic>> organizations = [];
  bool isLoading = true;
  final TextEditingController _searchController =
      TextEditingController(); // Declare the controller

  final String abiString = '''
[
  {
    "constant": true,
    "inputs": [],
    "name": "getAllCharities",
    "outputs": [
      { "name": "wallets", "type": "address[]" },
      { "name": "names", "type": "string[]" },
      { "name": "emails", "type": "string[]" },
      { "name": "phones", "type": "string[]" },
      { "name": "cities", "type": "string[]" },
      { "name": "websites", "type": "string[]" },
      { "name": "descriptions", "type": "string[]" },
      { "name": "licenseNumbers", "type": "string[]" },
      { "name": "establishmentDates", "type": "string[]" }
    ],
    "payable": false,
    "stateMutability": "view",
    "type": "function"
  }
]
''';

  String _searchQuery = ''; // Search query variable

  @override
  void initState() {
    super.initState();
    _client = Web3Client(rpcUrl, Client());
    _loadContract();
  }

  @override
  void dispose() {
    _searchController
        .dispose(); // Dispose the controller when the widget is disposed
    super.dispose();
  }

  Future<List<String>> fetchApprovedCharities() async {
    List<String> walletAddresses = [];

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('accountStatus', isEqualTo: 'approved')
          .where('userType', isEqualTo: 1)
          .get();

      for (var doc in snapshot.docs) {
        walletAddresses.add(doc['walletAddress']);
      }
    } catch (e) {
      print("Error fetching charity wallet addresses: $e");
    }

    return walletAddresses;
  }

  Future<void> _loadContract() async {
    try {
      var abi = jsonDecode(abiString);
      _contract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(abi), "CharityRegistration"),
        EthereumAddress.fromHex(contractAddress),
      );
      await _fetchCharities();
    } catch (e) {
      print("Error loading contract: $e");
    }
  }

  Future<void> _fetchCharities() async {
    try {
      // Fetch approved wallet addresses from Firestore
      List<String> approvedWallets = await fetchApprovedCharities();

      // Fetch all organizations from the smart contract
      final function = _contract.function("getAllCharities");
      final result = await _client.call(
        contract: _contract,
        function: function,
        params: [],
      );

      List<dynamic> wallets = result[0];
      List<dynamic> names = result[1];
      List<dynamic> emails = result[2];
      List<dynamic> phones = result[3];
      List<dynamic> cities = result[4];
      List<dynamic> websites = result[5];
      List<dynamic> descriptions = result[6];
      List<dynamic> licenseNumbers = result[7];
      List<dynamic> establishmentDates = result[8];

      List<Map<String, dynamic>> tempOrganizations = [];

      for (int i = 0; i < wallets.length; i++) {
        String wallet = wallets[i].toString();

        // Only include charities that are approved in Firestore
        if (approvedWallets.contains(wallet)) {
          tempOrganizations.add({
            "wallet": wallet,
            "name": names[i],
            "email": emails[i],
            "phone": phones[i],
            "city": cities[i],
            "website": websites[i],
            "description": descriptions[i],
            "licenseNumber": licenseNumbers[i],
            "establishmentDate": establishmentDates[i],
          });
        }
      }

      setState(() {
        organizations = tempOrganizations;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching charities: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to filter organizations based on search query
  List<Map<String, dynamic>> _getFilteredOrganizations() {
    if (_searchQuery.isEmpty) {
      return organizations;
    } else {
      return organizations.where((organization) {
        return organization["name"]
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  // Function to handle search query input
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    resizeToAvoidBottomInset: false, // Prevent UI from resizing when keyboard appears
    backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Background matches app bar
    appBar: PreferredSize(
      preferredSize: Size.fromHeight(55), // Increase app bar height
      child: AppBar(
        backgroundColor: Color.fromRGBO(24, 71, 137, 1), // Top bar color
        elevation: 0, // Remove shadow
        automaticallyImplyLeading: false, // Remove back arrow
        flexibleSpace: Padding(
          padding: EdgeInsets.only(bottom: 14), // Move text down
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              "Organizations",
              style: TextStyle(
                color: Colors.white, // Make text white
                fontSize: 23, // Increase font size
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    ),
    body: SingleChildScrollView( // Wrap the entire body with a SingleChildScrollView
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(20)), // Rounded top corners only
            child: Container(
              color: Colors.white, // Set the background to white
              width: double.infinity, // Make it stretch across the full width
              height: _getFilteredOrganizations().isEmpty || _getFilteredOrganizations().length <= 2
                  ? MediaQuery.of(context).size.height // Stretch to fill the screen when empty or small result
                  : null, // Default size when there are multiple results
              child: Column(
                children: [
                  // Search bar at the top
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController, // Bind the controller to the search bar
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search Organizations',
                        hintStyle: TextStyle(color: Colors.black),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1),
                              width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1),
                              width: 2),
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.black),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.black),
                                onPressed: () {
                                  _searchController.clear(); // Clears the text input
                                  _onSearchChanged(''); // Reset search filter
                                },
                              )
                            : null,
                      ),
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  // Loading or organizations list
                  isLoading
                      ? Center(
                          child: CircularProgressIndicator(),
                        )
                      : _getFilteredOrganizations().isEmpty
                          ? const Center(
                              child: Text("No registered charities found."),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(), // Prevent double scroll
                              itemCount: _getFilteredOrganizations().length,
                              itemBuilder: (context, index) {
                                var charity = _getFilteredOrganizations()[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 18),
                                  elevation: 6,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: const Color.fromRGBO(240, 248, 255, 1),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    leading: Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF8EC5FC),
                                            Color(0xFFE0C3FC)
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.account_circle,
                                        size: 55,
                                        color: Colors.white,
                                      ),
                                    ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ShaderMask(
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                            colors: [
                                              Color(0xFF0B2447),
                                              Color(0xFF19376D),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: Text(
                                            charity["name"],
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 1.2,
                                              shadows: [
                                                Shadow(
                                                  offset: Offset(0.5, 1),
                                                  blurRadius: 2,
                                                  color: Colors.black26,
                                                )
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF0A2647),
                                                  Color(0xFF144272)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                              child: const Icon(
                                                  Icons.location_on,
                                                  size: 22,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(width: 6),
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF102C57),
                                                  Color(0xFF205295)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                              child: Text(
                                                " ${charity["city"]}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF001F54),
                                                  Color(0xFF00337C)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                              child: const Icon(
                                                  Icons.email,
                                                  size: 22,
                                                  color: Colors.white),
                                            ),
                                            const SizedBox(width: 6),
                                            ShaderMask(
                                              shaderCallback: (bounds) =>
                                                  const LinearGradient(
                                                colors: [
                                                  Color(0xFF0B2447),
                                                  Color(0xFF19376D)
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ).createShader(bounds),
                                              child: Text(
                                                " ${charity["email"]}",
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              OrganizationProfilePage(
                                                  organization: charity),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

}

class OrganizationProfilePage extends StatelessWidget {
  final Map<String, dynamic> organization;

  const OrganizationProfilePage({super.key, required this.organization});
// Method to load the wallet address from SharedPreferences

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

  Future<String?> _loadPrivateKey() async {
    print('Loading private key...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('Error: Wallet address not found.');
        return null;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
        print('✅ Private key $privateKey');
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

  @override
  Widget build(BuildContext context) {
    // Get the address and validate it before passing
    String orgAddress = organization["wallet"];
    print("Organization Wallet Address: $orgAddress");
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1), // Top bar color
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60), // Increased app bar height
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0, // Remove shadow
          leading: Padding(
            padding: const EdgeInsets.only(top: 10), // Adjust icon position
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 30, // Adjusted size
              ),
              onPressed: () {
                Navigator.pop(context); // Navigate back
              },
            ),
          ),
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(bottom: 20), // Moves text down
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(
                organization["name"] ?? "Unknown Organization",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22, // Increased size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
  child: Column(
    children: [

       CircleAvatar(
                radius: 38,
                backgroundColor: Colors.transparent,
                
                child: Icon(Icons.account_circle, size: 100, color: Colors.grey)
                  
              ),
  
   
              SizedBox(height: 60),


      InfoRow(
  icon: Icons.phone,
  label: "Phone",
  value: organization["phone"],
),
InfoRow(
  icon: Icons.email,
  label: "Email",
  value: organization["email"],
),
InfoRow(
  icon: Icons.location_on,
  label: "City",
  value: organization["city"],
),



      InfoRow(
  icon: Icons.badge,
  label: "License Number",
  value: organization["licenseNumber"],
),
InfoRow(
  icon: Icons.explore,
  label: "Website",
  value: organization["website"],
  isLink: true,
),
InfoRow(
  icon: Icons.rocket_launch,
  label: "Established",
  value: organization["establishmentDate"],
),


    InfoRow(
  icon: Icons.description,
  label: "About Us",
  value: organization["description"],
),

              SizedBox(height: 80),

   AnimatedArrowButton(
  label: "${organization["name"]} Projects", 
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewProjectsPage(
          orgAddress: organization["wallet"],
          orgName: organization["name"] ?? "Organization",
        ),
      ),
    );
  },
),



      const SizedBox(height: 150),
    ],
  ),
),

          ),
          FutureBuilder<String?>(
            future: _loadPrivateKey(), // Call the asynchronous function
            builder: (context, snapshot) {
              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(); // or some loading indicator
              }

              // Check if the private key is available (not null)
              if (snapshot.hasData && snapshot.data != null) {
                return Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.flag,
                        color: Colors.grey, size: 40), // Increased icon size
                    iconSize: 38, // Ensures the button itself is larger
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return ReportPopup(
                              organization:
                                  organization); // Pass organization data
                        },
                      );
                    },
                  ),
                );
              }

              // If private key is null or not found, do not show the icon
              return Container();
            },
          ),
        ],
      ),
    );
  }

}
class AnimatedArrowButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const AnimatedArrowButton({
    super.key,
    required this.onTap,
    required this.label,
  });

  @override
  _AnimatedArrowButtonState createState() => _AnimatedArrowButtonState();
}

class _AnimatedArrowButtonState extends State<AnimatedArrowButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _offsetAnimation = Tween<double>(begin: 0, end: 12).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0), // Animate the button to the right
          child: GestureDetector(
            onTap: widget.onTap,
            child: ClipPath(
              clipper: SharpArrowClipper(), // Use updated arrow clipper
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volunteer_activism,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class SharpArrowClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double arrowWidth = 25; // Arrow head width
    double borderRadius = 25; // Rounded corners

    final path = Path();
    path.moveTo(borderRadius, 0); // Rounded left-top corner
    path.lineTo(size.width - arrowWidth, 0); // Start of the triangle (right)
    
    // Draw the arrowhead at the right side
    path.lineTo(size.width, size.height / 2); // Point at the tip of the triangle (right middle)
    path.lineTo(size.width - arrowWidth, size.height); // Back down the triangle
    
    // Return to the left side and apply rounded corners
    path.lineTo(borderRadius, size.height); // Rounded bottom-left corner
    path.quadraticBezierTo(0, size.height, 0, size.height - borderRadius); // Bottom left curve
    path.lineTo(0, borderRadius); // Rounded top-left corner
    path.quadraticBezierTo(0, 0, borderRadius, 0); // Top-left curve closing the shape
    
    path.close(); // Close the path to form a complete arrow shape
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


class InfoRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? value;
  final bool isLink;

  const InfoRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLink = false,
  }) : super(key: key);

  @override
  State<InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<InfoRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String content = widget.value?.trim() ?? "Not provided ";
    final bool isLongText = content.length > 60;
    final String displayText =
        _isExpanded || !isLongText ? content : '${content.substring(0, 60)}...';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue[100],
            child: Icon(widget.icon, color: Colors.blue[800], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_addEmoji(widget.label)}: ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily : 'Georgia',
                          color: Color.fromRGBO(24, 71, 137, 1),
                        ),
                      ),
                      TextSpan(
                        text: displayText,
                        style: TextStyle(
                          fontSize: 15,
                           fontFamily : 'Georgia',
                          color: widget.isLink ? Colors.blue : Colors.black87,
                          decoration: widget.isLink
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLongText)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Text(
                        _isExpanded ? "Show less" : "Show more",
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// Adds a fun emoji next to each label based on common fields
  String _addEmoji(String label) {
    switch (label.toLowerCase()) {
      case 'phone':
        return "Phone ";
      case 'email':
        return "Email ";
      case 'city':
        return "City ";
      case 'license number':
        return "License Number ";
      case 'website':
        return "Website ";
      case 'established':
      case 'founded':
      case 'start':
        return "Founded ";
      case 'about us':
        return "About Us ";
      default:
        return label;
    }
  }
}





class ViewProjectsPage extends StatefulWidget {
  final String orgAddress;
  final String orgName;

  const ViewProjectsPage(
      {super.key, required this.orgAddress, required this.orgName});

  @override
  _ViewProjectsPageState createState() => _ViewProjectsPageState();
}

class _ViewProjectsPageState extends State<ViewProjectsPage> {
  late Future<List<Map<String, dynamic>>> projects;

  @override
  void initState() {
    super.initState();
    projects = BlockchainService().fetchOrganizationProjects(widget.orgAddress);
  }



  
Future<String> _getProjectState(Map<String, dynamic> project) async {
  DateTime now = DateTime.now();
  String projectId = project['id'].toString(); // Ensure it's a String

  try {
    final doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();

    if (!doc.exists) {
      print("⚠️ Project not found. Creating default fields...");
      await FirebaseFirestore.instance.collection('projects').doc(projectId).set({
        'isCanceled': false,
        'isCompleted': false,
        'isEnded': false,
        'votingInitiated': false,
      });
    }

    final data = doc.data() as Map<String, dynamic>? ?? {};

    bool isCanceled = data['isCanceled'] ?? false;
    bool isCompleted = data['isCompleted'] ?? false;
bool isEnded = false;
final votingId = data['votingId'];

if (votingId != null) {
  final votingDocRef = FirebaseFirestore.instance
      .collection("votings")
      .doc(votingId.toString());

  final votingDoc = await votingDocRef.get();
  final votingData = votingDoc.data();

  if (votingDoc.exists) {
    isEnded = votingData?['IsEnded'] ?? false;
  }
}
    bool votingInitiated = data['votingInitiated'] ?? false;

    // Determine projectState based on Firestore flags
    if (isEnded) {
      return "ended";}
    if (isCompleted) {
      return "completed";
    } else if (votingInitiated && (!isCompleted) && (!isEnded)) {
      return "voting";
    } else if (isCanceled && (!votingInitiated) && (!isEnded)) {
      return "canceled";
    }

    // Fallback to logic based on time and funding progress
    DateTime startDate = project['startDate'] != null
        ? (project['startDate'] is DateTime
            ? project['startDate']
            : DateTime.parse(project['startDate']))
        : DateTime.now();

    DateTime endDate = project['endDate'] != null
        ? (project['endDate'] is DateTime
            ? project['endDate']
            : DateTime.parse(project['endDate']))
        : DateTime.now();

    double totalAmount = (project['totalAmount'] ?? 0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming";
    } else if (donatedAmount >= totalAmount) {
      return "in-progress";
    } else if (now.isAfter(endDate)) {
      return "failed";
    } else {
      return "active";
    }
  } catch (e) {
    print("❌ Error determining project state for ID $projectId: $e");
    return "unknown";
  }
}

  Future<bool> _isProjectCanceled(String projectId) async {
    try {
      // Fetch the project document from Firestore using the projectId
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();

      // Check if the document exists
      if (doc.exists) {
        // Retrieve the 'isCanceled' field and return true or false
        bool isCanceled = doc['isCanceled'] ?? false;
        return isCanceled; // Return true if canceled, false otherwise
      } else {
        print("Project not found");
        return false; // If the project does not exist, return false
      }
    } catch (e) {
      print("Error fetching project state: $e");
      return false; // Return false in case of an error
    }
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
      return  Color.fromRGBO(24, 71, 137, 1);
    default:
      return Colors.grey;
  }
}

  double weiToEth(BigInt wei) {
    return (wei / BigInt.from(10).pow(18)).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(24, 71, 137, 1),
      appBar: AppBar(
        toolbarHeight: 55,
        title: Padding(
          padding: EdgeInsets.only(bottom: 1),
          child: Text(
            "${widget.orgName}'s Projects",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 25,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromRGBO(24, 71, 137, 1),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 30,
          weight: 800,
        ),
        leading: Padding(
          padding: EdgeInsets.only(left: 10, bottom: 1),
          child: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 16,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: projects, // Ensure this Future is properly initialized
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                        child: CircularProgressIndicator(
                      color: Colors.white,
                    ));
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child:
                          Text("Currently, there are no projects available."),
                    );
                  }

                  final projectList = snapshot.data!;

                  return 
                  

       ListView.builder(
  padding: const EdgeInsets.all(14), // Slightly increased padding
  itemCount: projectList.length,
  itemBuilder: (context, index) {
    final project = projectList[index];

    return FutureBuilder<String>(
      future: _getProjectState(project),
      builder: (context, stateSnapshot) {
        if (stateSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Colors.white));
        } else if (stateSnapshot.hasError) {
          return Center(child: Text("Error: ${stateSnapshot.error}"));
        } else if (!stateSnapshot.hasData) {
          return SizedBox();
        }

        final projectState = stateSnapshot.data!;
        final stateColor = _getStateColor(projectState);

        final deadline = project['endDate'] != null
            ? DateFormat('yyyy-MM-dd').format(DateTime.parse(project['endDate'].toString()))
            : 'No deadline';
        final double progress = project['donatedAmount'] / project['totalAmount'];

        // Light grey color instead of gradient
        final bgColor = const Color.fromARGB(255, 230, 227, 227); // Very light grey background

        // Dark red ombré for deadline
        final deadlineColor = LinearGradient(
          colors: [
            Color(0xFF8B0000), // Dark Red
            Color(0xFFB22222), // Firebrick Red
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        // Navy blue ombré for name
        final nameColor = LinearGradient(
          colors: [
            Color(0xFF000080), // Navy Blue
            Color(0xFF4682B4), // Steel Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetails(
                  projectName: project['name'],
                  description: project['description'],
                  startDate: project['startDate'].toString(),
                  deadline: project['endDate'].toString(),
                  totalAmount: project['totalAmount'],
                  projectType: project['projectType'],
                  projectCreatorWallet: project['organization'] ?? '',
                  donatedAmount: project['donatedAmount'],
                  projectId: project['id'],
                  progress: progress,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6), // Reduced margin for smaller card size
            padding: const EdgeInsets.all(12), // Reduced padding for smaller card size
            decoration: BoxDecoration(
              color: bgColor, // Light grey color background
              borderRadius: BorderRadius.circular(12), // Slightly smaller border radius for smaller card
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8, // Reduced blur radius for smaller shadow
                  offset: Offset(0, 4), // Reduced shadow offset for smaller card
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) {
                    return nameColor.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
                  },
                  child: Text(
                    project['name'] ?? 'Untitled Project',
                    style: TextStyle(
                      fontSize: 16, // Slightly smaller font size for title
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // The color here is overridden by the ShaderMask
                    ),
                  ),
                ),
                SizedBox(height: 10), // Reduced space between title and progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8), // Smaller border radius for progress bar
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                    minHeight: 6, // Reduced height for progress bar
                  ),
                ),
                SizedBox(height: 8), // Reduced space between progress bar and state text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14, // Smaller font size for progress percentage
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
                      decoration: BoxDecoration(
                        color: stateColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16), // Slightly smaller border radius
                      ),
                      child: Text(
                        projectState,
                        style: TextStyle(
                          color: stateColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13, // Smaller font size for state text
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10), // Reduced space for deadline section
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return deadlineColor.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
                      },
                      child: Icon(
                        Icons.access_time, // Deadline icon
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 6), // Reduced space between icon and text
                    Text(
                      'Deadline: $deadline',
                      style: TextStyle(
                        fontSize: 13, // Smaller font size for deadline text
                        foreground: Paint()..shader = deadlineColor.createShader(Rect.fromLTWH(0, 0, 200, 70)), // Dark red ombré for deadline text
                      ),
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

class ReportPopup extends StatefulWidget {
  final Map<String, dynamic> organization;

  const ReportPopup({super.key, required this.organization});

  @override
  _ReportPopupState createState() => _ReportPopupState();
}

class _ReportPopupState extends State<ReportPopup> {
  late String targetCharityAddress;
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
    targetCharityAddress = widget.organization["wallet"] ?? "";
    print("Target Charity Address: $targetCharityAddress"); // Debugging print
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
    String orgAddress = widget.organization["wallet"] ?? "Unknown";
    print("Organization Wallet Address: $orgAddress");

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
                borderSide:
                    const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              counterText: "$titleLength/$titleMax", // Dynamic counter
              counterStyle: TextStyle(
                  color: titleLength >= titleMax ? Colors.red : Colors.grey),
            ),
          ),
          const SizedBox(height: 1),
          if (isTitleEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 130),
              child: Text(
                "Title is required.",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
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
              contentPadding: const EdgeInsets.only(
                  top: 20, left: 12, right: 12, bottom: 12),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color.fromRGBO(24, 71, 137, 1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              counterText:
                  "$descriptionLength/$descriptionMax", // Dynamic counter
              counterStyle: TextStyle(
                  color: descriptionLength >= descriptionMax
                      ? Colors.red
                      : Colors.grey),
            ),
          ),
          if (isDescriptionEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 100),
              child: Text(
                "Description is required.",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
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
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)), // Rounded border
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10), // Padding
              ),
              child: const Text(
                " Cancel ",
                style: TextStyle(
                    color: Color.fromRGBO(24, 71, 137, 1),
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 20),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    descriptionController.text.isEmpty) {
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)), // Rounded border
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10), // Padding
              ),
              child: const Text(
                "  Send  ",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
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
                        backgroundColor: Colors.white,
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
                        // Validate input fields
                        if (titleController.text.trim().isEmpty ||
                            descriptionController.text.trim().isEmpty) {
                          print("Title or description is empty");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter both title and description')),
                          );
                          return;
                        }

                        // Prepare the complaint details
                        String title = titleController.text.trim();
                        String description = descriptionController.text.trim();
                        String targetCharityAddress =
                            widget.organization["wallet"] ?? "";

                        print("Submitting complaint...");
                        print("Title: $title");
                        print("Description: $description");
                        print("Target Charity Address: $targetCharityAddress");

                        if (targetCharityAddress.isEmpty) {
                          print("Error: Charity wallet address is missing!");
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Error: Charity wallet address is missing!')),
                          );
                          return;
                        }

                        // Load the complainant wallet address
                        String? complainantAddress = await _loadWalletAddress();
                        if (complainantAddress == null ||
                            complainantAddress.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Error: Could not load your wallet address. Please log in again.')),
                          );
                          return;
                        }

                        try {
                          // Create the complaint document
                          await FirebaseFirestore.instance
                              .collection('reports')
                              .add({
                            'title': title,
                            'description': description,
                            'targetCharityAddress': targetCharityAddress,
                            'complainant': complainantAddress,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          print('Complaint stored successfully in Firestore.');
                          showSuccessPopup(context); // Show confirmation popup
                        } catch (e) {
                          print('Exception occurred: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('An error occurred: $e')),
                          );
                        }
                      },

//                 onPressed: () async {
//   // Validate input fields
//   if (titleController.text.trim().isEmpty || descriptionController.text.trim().isEmpty) {
//     print("Title or description is empty");
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Please enter both title and description')),
//     );
//     return;
//   }

//   // Prepare the complaint details
//   String title = titleController.text.trim();
//   String description = descriptionController.text.trim();
//   String targetCharityAddress = widget.organization["wallet"] ?? "";

//   print("Submitting complaint...");
//   print("Title: $title");
//   print("Description: $description");
//   print("Target Charity Address: $targetCharityAddress");

//   if (targetCharityAddress.isEmpty) {
//     print("Error: Charity wallet address is missing!");
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Error: Charity wallet address is missing!')),
//     );
//     return;
//   }

//   try {
//     // Create an instance of ComplaintService
//     final complaintService = ComplaintService(
//       rpcUrl: 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1' , // Replace securely
//       contractAddress: '0x89284505E6EbCD2ADADF3d1B5cbc51B3568CcFd1', // Replace securely
//     );

//     // Call the sendComplaint function and get the transaction hash
//     String result = await complaintService.sendComplaint(
//       title: title,
//       description: description,
//       targetCharityAddress: targetCharityAddress,
//     );

//     // Handle the response
//     if (result.startsWith('Error')) {
//       print('Failed to send complaint: $result');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to send complaint: $result')),
//       );
//     } else {
//       print('Complaint sent successfully. Transaction hash: $result');
//       // After the complaint is sent successfully

//              showSuccessPopup(context); // Call the popup here

//     }
//   } catch (e) {
//     print('Exception occurred: $e');
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('An error occurred: $e')),
//     );
//   }
// },

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
          contentPadding:
              EdgeInsets.all(20), // Add padding around the dialog content
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15), // Rounded corners for a better look
          ),
          content: SizedBox(
            width: 250, // Set a custom width for the dialog
            child: Column(
              mainAxisSize: MainAxisSize
                  .min, // Ensure the column only takes the required space
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
}

class ComplaintService {
  final Web3Client _web3Client;
  final String _contractAddress;
  late final DeployedContract _complaintContract;
  late final ContractFunction _submitComplaint;

  // The ABI as a string (replace with actual ABI content)
  final String _complaintContractABI = '''
  [
    {
      "constant": false,
      "inputs": [
        { "name": "_title", "type": "string" },
        { "name": "_description", "type": "string" },
        { "name": "_targetCharity", "type": "address" }
      ],
      "name": "submitComplaint",
      "outputs": [],
      "payable": false,
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [{ "name": "_complaintId", "type": "uint256" }],
      "name": "viewComplaint",
      "outputs": [
        { "name": "title", "type": "string" },
        { "name": "description", "type": "string" },
        { "name": "complainant", "type": "address" },
        { "name": "targetCharity", "type": "address" },
        { "name": "timestamp", "type": "uint256" },
        { "name": "resolved", "type": "bool" }
      ],
      "payable": false,
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  ComplaintService({
    required String rpcUrl, // The rpcUrl passed into the constructor
    required String contractAddress, // Replace with your smart contract address
  })  : _contractAddress = contractAddress,
        _web3Client = Web3Client(rpcUrl, http.Client()) {
    _initializeContract();
  }

  // Initialize the contract and its functions
  void _initializeContract() {
    print('Initializing contract...');
    try {
      _complaintContract = DeployedContract(
        ContractAbi.fromJson(_complaintContractABI, 'ComplaintRegistry'),
        EthereumAddress.fromHex(_contractAddress),
      );
      print('Contract initialized successfully.');
    } catch (e) {
      print('Error initializing contract: $e');
    }
    _submitComplaint = _complaintContract.function('submitComplaint');
    print('Contract function "submitComplaint" initialized.');
  }

  // Method to send a complaint
  Future<String> sendComplaint({
    required String title,
    required String description,
    required String targetCharityAddress,
  }) async {
    print('🛠 Preparing to send complaint...');

    // Load the wallet address and private key from SharedPreferences
    final privateKey = await _loadPrivateKey();
    if (privateKey == null) {
      print('❌ Error: Private key not found!');
      return 'Error: Private key not found!';
    }

    print(
        '✅ Private key successfully loaded: ${privateKey.substring(0, 6)}... (hidden for security)');

    // Fetch the credentials from the private key
    final credentials = EthPrivateKey.fromHex(privateKey);
    print('🔑 Credentials created from private key.');

    // Set up the parameters
    final params = [
      title,
      description,
      EthereumAddress.fromHex(targetCharityAddress),
    ];

    print('📡 Connecting to blockchain...');
    try {
      print('📤 Sending transaction to contract...');

      final transaction = await _web3Client.sendTransaction(
        credentials,
        web3.Transaction.callContract(
          contract: _complaintContract,
          function: _submitComplaint,
          parameters: params,
          maxGas: 1000000, // Increased gas limit
        ),
        chainId:
            11155111, // Ensure this is correct (Ethereum Mainnet = 1, Sepolia = 11155111, etc.)
      );

      print('✅ Transaction sent successfully!');

      print('🔗 Transaction Hash: $transaction');
      return transaction;
    } catch (e) {
      print('❌ Error sending transaction: $e');
      return 'Error: $e';
    }
  }

  // Fetch credentials using the private key from shared preferences
  Future<String?> _loadPrivateKey() async {
    print('Loading private key...');
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? walletAddress = await _loadWalletAddress();
      if (walletAddress == null) {
        print('Error: Wallet address not found.');
        return null;
      }

      String privateKeyKey = 'privateKey_$walletAddress';
      print('Retrieving private key for address: $walletAddress');

      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey != null) {
        print('✅ Private key retrieved for wallet $walletAddress');
        print('✅ Private key $privateKey');
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
}
