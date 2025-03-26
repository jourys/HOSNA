import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';

import 'DonorProfile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Web3Client _web3Client;
  String _firstName = '';
  String _walletAddress = '';

  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x761a4F03a743faf9c0Eb3440ffeAB086Bd099fbc';
  final String DonationContractAddress =
      "0x204e30437e9B11b05AC644EfdEaCf0c680022Fe5";

  List<String> donatedProjectNames =
      []; // This will hold the project names from SharedPreferences
  List<int> projectIds = [];
  Future<List<Map<String, dynamic>>>? donatedProjects;

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    _loadWalletAddress();
    printUserType();
    _loadDonatedProjectIds(); // Load the projects when the page is initialized
  }

  Future<void> _loadDonatedProjectIds() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? storedIds =
        prefs.getStringList('donatedProjects_$_walletAddress');

    if (storedIds != null) {
      setState(() {
        projectIds = storedIds
            .where((id) =>
                RegExp(r'^\d+$').hasMatch(id)) // Ensure it's a valid number
            .map((id) => int.parse(id))
            .toList();
        donatedProjects = _fetchDonatedProjects();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchDonatedProjects() async {
    List<Map<String, dynamic>> projects = [];

    for (int projectId in projectIds) {
      Map<String, dynamic> projectDetails =
          await BlockchainService().getProjectDetails(projectId);
      projects.add(projectDetails);
    }

    return projects;
  }

  void _loadWalletAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String walletAddress = prefs.getString('walletAddress') ?? '';
    print("Wallet Address from SharedPreferences: $walletAddress");

    if (walletAddress.isNotEmpty) {
      setState(() {
        _walletAddress = walletAddress;
      });
    } else {
      print("⚠️ Wallet address is not available!");
    }
  }

  Future<void> _getDonorData() async {
    try {
      final contract = await _loadContract();
      final result = await _web3Client.call(
        contract: contract,
        function: contract.function('getDonor'),
        params: [EthereumAddress.fromHex(_walletAddress)],
      );

      if (mounted) {
        // Check if the widget is still mounted
        setState(() {
          _firstName = result[0]; // First name from blockchain
        });
      }
    } catch (e) {
      print("Error fetching donor data: $e");
    }
  }

  Future<void> _initializeWeb3() async {
    print("Initializing Web3 client...");
    _web3Client = Web3Client(rpcUrl, Client());

    final prefs = await SharedPreferences.getInstance();
    _walletAddress = prefs.getString('walletAddress') ?? '';
    print("Wallet address from SharedPreferences: $_walletAddress");

    if (_walletAddress.isNotEmpty) {
      await _getDonorData();
    }
  }

  Future<void> printUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? userType = prefs.getInt('userType'); // 0 = Donor, 1 = Charity

    if (userType != null) {
      if (userType == 0) {
        print("User Type: Donor");
      } else if (userType == 1) {
        print("User Type: Charity Employee");
      }
    } else {
      print("No user type found in SharedPreferences");
    }
  }

  Future<DeployedContract> _loadContract() async {
    final contractAbi = '''[
      {
        "constant": true,
        "inputs": [{"name": "_wallet", "type": "address"}],
        "name": "getDonor",
        "outputs": [
          {"name": "firstName", "type": "string"},
          {"name": "lastName", "type": "string"},
          {"name": "email", "type": "string"},
          {"name": "phone", "type": "string"},
          {"name": "walletAddress", "type": "address"},
          {"name": "registered", "type": "bool"}
        ],
        "payable": false,
        "stateMutability": "view",
        "type": "function"
      }
    ]''';

    final contract = DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );

    return contract;
  }

  // Future<void> _getDonorData() async {
  //   try {
  //     print("Fetching donor data for wallet: $_walletAddress");
  //     final contract = await _loadContract();
  //     final result = await _web3Client.call(
  //       contract: contract,
  //       function: contract.function('getDonor'),
  //       params: [EthereumAddress.fromHex(_walletAddress)],
  //     );

  //     if (result.isNotEmpty) {
  //       setState(() {
  //         _firstName = result[0]; // First name from blockchain
  //       });
  //       print("Donor first name: $_firstName");
  //     }
  //   } catch (e) {
  //     print("Error fetching donor data: $e");
  //   }
  // }
  String _getProjectState(Map<String, dynamic> project) {
    DateTime now = DateTime.now();

    DateTime startDate = project['startDate'] != null
        ? DateTime.parse(project['startDate'].toString())
        : now;

    DateTime endDate = project['endDate'] != null
        ? DateTime.parse(project['endDate'].toString())
        : now;

    double totalAmount = (project['totalAmount'] ?? 0.0).toDouble();
    double donatedAmount = (project['donatedAmount'] ?? 0.0).toDouble();

    if (now.isBefore(startDate)) {
      return "upcoming";
    } else if (donatedAmount >= totalAmount && now.isBefore(endDate)) {
      return "completed";
    } else if (now.isAfter(endDate) && donatedAmount < totalAmount) {
      return "failed";
    } else {
      return "active";
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "active":
        return Colors.green;
      case "failed":
        return Colors.red;
      case "completed":
        return Colors.blue;
      case "upcoming":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: Padding(
            padding: const EdgeInsets.only(left: 25, bottom: 10),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(top: 50), // Moves everything down
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Day, ${_firstName}!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: 120, // Define an explicit width
                      height: 90, // Define an explicit height
                      child: IconButton(
                        icon: const Icon(Icons.account_circle,
                            size: 75, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfileScreenTwo()),
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 1,
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
                future: donatedProjects,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text(
                            "Currently, there are no projects available."));
                  }

                  final projectList = snapshot.data!;

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: projectList.length,
                    itemBuilder: (context, index) {
                      final project = projectList[index];
                      final projectState = _getProjectState(project);
                      final stateColor = _getStateColor(projectState);
                      final deadline = project['endDate'] != null
                          ? DateFormat('yyyy-MM-dd').format(
                              DateTime.parse(project['endDate'].toString()))
                          : 'No deadline available';
                      final double progress =
                          project['donatedAmount'] / project['totalAmount'];

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: Color.fromRGBO(24, 71, 137, 1), width: 3),
                        ),
                        elevation: 2,
                        margin:
                            EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                        child: ListTile(
                          tileColor: Colors.grey[200],
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          title: Text(
                            project['name'] ?? 'Untitled',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color.fromRGBO(24, 71, 137, 1)),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  text: 'Deadline: ',
                                  style: TextStyle(
                                      fontSize: 17,
                                      color: Color.fromRGBO(238, 100, 90, 1)),
                                  children: [
                                    TextSpan(
                                      text: '$deadline',
                                      style: TextStyle(
                                          fontSize: 17, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.grey[200],
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(stateColor),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: stateColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      projectState,
                                      style: TextStyle(
                                          color: stateColor,
                                          fontWeight: FontWeight.bold),
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
                                builder: (context) => ProjectDetails(
                                  projectName: project['name'],
                                  description: project['description'],
                                  startDate: project['startDate'].toString(),
                                  deadline: project['endDate'].toString(),
                                  totalAmount: project['totalAmount'],
                                  projectType: project['projectType'],
                                  projectCreatorWallet:
                                      project['organization'] ?? '',
                                  donatedAmount: project['donatedAmount'],
                                  projectId: project['id'],
                                  progress: progress,
                                ),
                              ),
                            );
                          },
                        ),
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
