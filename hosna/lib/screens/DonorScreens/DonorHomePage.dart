import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/InitiateVoting.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/DonorScreens/VotingProjectsPage.dart';
import 'package:hosna/screens/DonorScreens/DonationHistoryPage.dart';

import 'DonorProfile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final donorServices = DonorServices();
  final BlockchainService _blockchainService = BlockchainService();
  String? walletAddress;
  String _firstName = '';
  List<Map<String, dynamic>> votingProjects = [];
  List<Map<String, dynamic>> donationHistory = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x8a69415dcb679d808296bdb51dFcb01A4Cd2Bb79';
  final String DonationContractAddress =
      "0x204e30437e9B11b05AC644EfdEaCf0c680022Fe5";

  List<String> donatedProjectNames =
      []; // This will hold the project names from SharedPreferences
  List<int> projectIds = [];
  Future<List<Map<String, dynamic>>>? donatedProjects;

  @override
  void initState() {
    super.initState();
    _loadWalletAndData();
    _loadDonorNameFromBlockchain();
    // _loadUserName();
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

  final String donorRegistryAbi = '''
[
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
]
''';
  Future<void> _loadDonorNameFromBlockchain() async {
    try {
      final client = Web3Client(rpcUrl, Client());
      final prefs = await SharedPreferences.getInstance();
      final wallet = prefs.getString('walletAddress');
      if (wallet == null || wallet.isEmpty) return;

      final contract = DeployedContract(
        ContractAbi.fromJson(donorRegistryAbi, 'DonorRegistry'),
        EthereumAddress.fromHex(contractAddress),
      );

      final getDonorFunction = contract.function('getDonor');
      final result = await client.call(
        contract: contract,
        function: getDonorFunction,
        params: [EthereumAddress.fromHex(wallet)],
      );

      if (result.isNotEmpty && result[0] is String) {
        setState(() {
          _firstName = result[0];
        });
      }
    } catch (e) {
      print('❌ Error loading name from blockchain: $e');
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

  // Future<void> _loadUserName() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final address = prefs.getString('walletAddress');
  //     final firstName = prefs.getString('firstName') ?? '';

  //     if (firstName.isNotEmpty) {
  //       setState(() {
  //         _firstName = firstName;
  //       });
  //     }
  //   } catch (e) {
  //     print("Error loading user name: $e");
  //   }
  // }

  Future<void> _storeDonationInfo(
      Map<String, dynamic> projectDetails, double donatedAmount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');

      if (address == null) {
        print("❌ No wallet address found");
        return;
      }

      // Create a unique key for this donation using wallet address and project ID
      final donationKey = 'donation_${address}_${projectDetails['id']}';

      // Create donation info with all necessary details
      final donationInfo = {
        'id': projectDetails['id'],
        'name': projectDetails['name'],
        'description': projectDetails['description'],
        'donatedAmount': donatedAmount,
        'totalAmount': double.parse(projectDetails['totalAmount'].toString()),
        'projectType': projectDetails['projectType'],
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'projectCreatorWallet': projectDetails['projectCreatorWallet'],
        'donorWallet': address, // Store the donor's wallet address
      };

      // Store the donation with its unique key
      await prefs.setString(donationKey, json.encode(donationInfo));
      print(
          "✅ Stored donation for project ${projectDetails['name']} with key: $donationKey");

      // Also store the donation key in a list of all donations for this wallet
      final donationsListKey = 'donations_list_$address';
      final existingList = prefs.getStringList(donationsListKey) ?? [];
      if (!existingList.contains(donationKey)) {
        existingList.add(donationKey);
        await prefs.setStringList(donationsListKey, existingList);
        print("✅ Updated donations list for wallet $address");
      }
    } catch (e) {
      print("❌ Error storing donation info: $e");
    }
  }

  Future<void> _loadWalletAndData() async {
    if (!mounted) return;
    print("🔵 Starting _loadWalletAndData");

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');

      if (address == null || address.isEmpty) {
        throw Exception('❌ Wallet address not found in SharedPreferences');
      }
      print("🔵 Loaded wallet address: $address");

      setState(() {
        walletAddress = address;
      });

      //await _loadUserName();

      // Fetch all projects
      final allProjects = await _blockchainService.fetchAllProjects();
      print("🔵 Fetched ${allProjects.length} projects from blockchain");

      List<Map<String, dynamic>> eligibleVotingProjects = [];

      for (var project in allProjects) {
        if (project == null) {
          print("⚠️ Skipped null project");
          continue;
        }
        final projectId = project['id'];
        if (projectId == null) {
          print("⚠️ Project without ID found, skipping");
          continue;
        }

        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId.toString())
            .get();

        if (projectDoc.exists) {
          final data = projectDoc.data();
          if (data == null) {
            print("⚠️ Project document data is null for ID: $projectId");
            continue;
          }

          final votingInitiated = data['votingInitiated'] ?? false;
          if (votingInitiated) {
            BigInt bigIntProjectId;
            try {
              bigIntProjectId = BigInt.from(projectId);
            } catch (e) {
              print("❌ Error converting projectId to BigInt: $e");
              continue;
            }

            final bool donorEligibility =
                await donorServices.checkIfDonorCanVote(
              bigIntProjectId,
              walletAddress!,
            );
            print(
                "🔵 Donor eligibility for project $projectId: $donorEligibility");

            final votingIdStr = data['votingId']?.toString() ?? '';
            print("🔵 Extracted votingId as String: $votingIdStr");

            if (votingIdStr.isEmpty) {
              print("⚠️ votingId is empty for project $projectId, skipping");
              continue;
            }

            final int votingId = int.tryParse(votingIdStr) ?? -1;
            if (votingId == -1) {
              print("❌ Failed to parse votingId: $votingIdStr");
              continue;
            }
            print("🔵 Parsed votingId to int: $votingId");

            final VoteListener voteListener =
                VoteListener(projectId: projectId);
            voteListener.initializeClient();

            final hasVoted = await voteListener.hasDonorAlreadyVoted(
              votingId,
              EthereumAddress.fromHex(walletAddress!),
            );
            print("🔵 Donor has voted for votingId $votingId: $hasVoted");

            final privateKey = await _loadPrivateKey();
            if (privateKey == null || privateKey.isEmpty) {
              print("❌ Private key not found, skipping refund check");
              continue;
            }

            final refundService = RefundService(
              userAddress: EthereumAddress.fromHex(walletAddress!),
              userCredentials: EthPrivateKey.fromHex(privateKey),
            );

            final hasRequestedRefund =
                await refundService.hasRequestedRefund(projectId);
            print(
                "🔵 Donor has requested refund for project $projectId: $hasRequestedRefund");

            if (donorEligibility && (!hasVoted || !hasRequestedRefund)) {
              project['votingId'] = projectId;
              project['votingDeadline'] = DateTime.fromMillisecondsSinceEpoch(
                (project['endTime'] ?? 0) * 1000,
              ).toString();

              eligibleVotingProjects.add(project);
              print("✅ Added project $projectId to eligible voting projects");
            }
          }
        } else {
          print("⚠️ Project document does not exist for ID: $projectId");
        }
      }

      setState(() {
        votingProjects = eligibleVotingProjects;
        print(
            "✅ Final eligible voting projects count: ${votingProjects.length}");
      });

      print("🗳️ Voting Projects Loaded:");
      for (var project in votingProjects) {
        print(
            "➡️ Project ID: ${project['id']}, Voting ID: ${project['votingId']}, Voting Deadline: ${project['votingDeadline']}");
      }

      // Load donation history
      List<Map<String, dynamic>> historyList = [];
      final donationsKey = 'donations_${address}';
      final donationsJson = prefs.getString(donationsKey);

      print("📦 Loading donations using key: $donationsKey");
      print("📦 Donations JSON: $donationsJson");

      if (donationsJson != null) {
        try {
          final List<dynamic> donations = json.decode(donationsJson);
          final filteredDonations = donations.where((donation) {
            final donorWallet =
                donation['donorWallet']?.toString().toLowerCase();
            return donorWallet == address.toLowerCase();
          }).toList();

          historyList = List<Map<String, dynamic>>.from(filteredDonations);
          print("✅ Loaded ${historyList.length} donation(s) for this wallet");

          for (var donation in historyList) {
            try {
              dynamic endDate = donation['endDate'];
              int endDateMillis;

              if (endDate is DateTime) {
                endDateMillis = endDate.millisecondsSinceEpoch;
              } else if (endDate is String) {
                if (endDate.trim().isEmpty || endDate.toLowerCase() == 'n/a') {
                  endDateMillis = DateTime.now().millisecondsSinceEpoch;
                } else {
                  endDateMillis =
                      DateTime.parse(endDate).millisecondsSinceEpoch;
                }
              } else if (endDate is int) {
                endDateMillis = endDate;
              } else {
                endDateMillis = DateTime.now().millisecondsSinceEpoch;
              }

              donation['endDate'] = endDateMillis;

              final storedAmount = donation['donatedAmount'] ?? 0.0;
              donation['anonymousAmount'] = storedAmount;
              donation['nonAnonymousAmount'] = storedAmount;

              print("✅ Processed donation: ${donation['name']}");
            } catch (e) {
              print("❌ Error processing donation: $e");
            }
          }
        } catch (e) {
          print("❌ Error parsing donations JSON: $e");
          historyList = [];
        }
      } else {
        print("⚠️ No donations found for wallet: $address");
      }

      historyList
          .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
      print("📊 Final sorted donation history count: ${historyList.length}");

      if (!mounted) return;
      setState(() {
        donationHistory = historyList;
        isLoading = false;
      });
      print("🔵 Completed _loadWalletAndData successfully");
    } catch (e, stacktrace) {
      print("❌ Error in _loadWalletAndData: $e");
      print(stacktrace);
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load data. Please try again.';
      });
    }
  }

  Widget _buildVotingSection() {
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          errorMessage,
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Projects Awaiting Your Vote',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
        ),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (votingProjects.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No projects currently need your vote'),
          )
        else
          ...votingProjects.take(2).map((project) {
            final votingDeadline = project['votingDeadline'] ?? 'Unknown';
            final projectType = project['projectType'] ?? 'Unknown';

            return Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListTile(
                title: Text(
                  project['name'] ?? 'Unnamed Project',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Voting Deadline: $votingDeadline',
                      style: TextStyle(color: Colors.red[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Project Type: $projectType',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetails(
                        projectId: int.parse(project['id'].toString()),
                        projectName: project['name'] ?? 'Unnamed Project',
                        description: project['description'] ?? '',
                        totalAmount: project['totalAmount']?.toDouble() ?? 0.0,
                        projectType: projectType,
                        projectCreatorWallet:
                            project['projectCreatorWallet'] ?? '',
                        donatedAmount:
                            project['donatedAmount']?.toDouble() ?? 0.0,
                        progress: (project['totalAmount'] ?? 0) > 0
                            ? (project['donatedAmount'] ?? 0) /
                                (project['totalAmount'] ?? 1)
                            : 0.0,
                        deadline: project['endDate']?.toString() ?? '',
                        startDate: project['startDate']?.toString() ?? '',
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        if (votingProjects.length > 2)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VotingProjectsPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
                label: const Text(
                  'See All',
                  style: TextStyle(
                    color: Color.fromRGBO(24, 71, 137, 1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _getEligibleVotingProjects() async {
    if (walletAddress == null) return [];

    final donorServices = DonorServices();
    List<Map<String, dynamic>> eligibleProjects = [];

    for (var project in votingProjects) {
      try {
        final canVote = await donorServices.checkIfDonorCanVote(
          BigInt.from(project['id']),
          walletAddress!,
        );

        if (canVote) {
          // Check Firestore for 'votingInitiated' and ensure not ended
          final projectDoc = await FirebaseFirestore.instance
              .collection('projects')
              .doc(project['id'].toString())
              .get();

          if (projectDoc.exists) {
            final data = projectDoc.data()!;
            final isEnded = data['IsEnded'] ?? false;
            final votingInitiated = data['votingInitiated'] ?? false;

            if (votingInitiated && !isEnded) {
              // Only then add it
              project['votingDeadline'] = DateTime.fromMillisecondsSinceEpoch(
                project['endTime'] * 1000,
              ).toString();

              eligibleProjects.add(project);
            }
          }
        }
      } catch (e) {
        print("❌ Error in eligibility check: $e");
      }
    }

    return eligibleProjects;
  }

  Future<Map<String, dynamic>?> _fetchLatestProjectDetails(
      int projectId) async {
    try {
      final allProjects = await _blockchainService.fetchAllProjects();
      print(
          "🔍 Looking for project ID: $projectId in ${allProjects.length} projects");

      for (var project in allProjects) {
        if (project['id'] == projectId) {
          print("✅ Found project $projectId");
          return project;
        }
      }

      print("⚠️ Project $projectId not found in blockchain list");
      return null;
    } catch (e) {
      print("❌ Error fetching project $projectId details: $e");
      return null;
    }
  }

  Widget _buildDonationHistorySection() {
    if (hasError) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Donation History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900], // same as voting section
            ),
          ),
        ),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (donationHistory.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No donation history found'),
          )
        else
          ...donationHistory.take(2).map((donation) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _fetchLatestProjectDetails(
                  int.parse(donation['id'].toString())),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    margin:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: ListTile(title: Text('Loading...')),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: ListTile(
                      title: Text(donation['name'] ?? 'Error loading project'),
                      subtitle: const Text('Could not load latest details'),
                    ),
                  );
                }

                final latestProjectData = snapshot.data!;
                final totalAmount =
                    (latestProjectData['totalAmount'] ?? 0.0).toDouble();
                final donatedAmount =
                    (latestProjectData['donatedAmount'] ?? 0.0).toDouble();
                final progress = totalAmount > 0
                    ? (donatedAmount / totalAmount * 100).toStringAsFixed(1)
                    : '0.0';

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    title: Text(donation['name'] ?? 'Unnamed Project',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                            'Donated: ${donation['donatedAmount'].toStringAsFixed(5)} ETH',
                            style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                            'Total Goal: ${totalAmount.toStringAsFixed(5)} ETH',
                            style: TextStyle(color: Colors.blue[700])),
                        const SizedBox(height: 4),
                        Text('Progress: $progress%',
                            style: TextStyle(color: Colors.orange[700])),
                        Text(
                            'Project Type: ${donation['projectType'] ?? 'Unknown'}',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetails(
                            projectId: int.parse(donation['id'].toString()),
                            projectName: donation['name'] ?? 'Unnamed Project',
                            description: donation['description'] ?? '',
                            totalAmount: totalAmount,
                            projectType: donation['projectType'] ?? 'Unknown',
                            projectCreatorWallet:
                                donation['projectCreatorWallet'] ?? '',
                            donatedAmount: donatedAmount,
                            progress: totalAmount > 0
                                ? donatedAmount / totalAmount
                                : 0.0,
                            deadline: latestProjectData['endDate'].toString(),
                            startDate:
                                latestProjectData['startDate'].toString(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }).toList(),
        if (donationHistory.length > 2)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DonationHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color.fromRGBO(24, 71, 137, 1),
                ),
                label: const Text(
                  'See All',
                  style: TextStyle(
                    color: Color.fromRGBO(24, 71, 137, 1),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    padding: const EdgeInsets.only(top: 50),
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
                  Row(
                    children: [
                      SizedBox(
                        width: 120,
                        height: 90,
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
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadWalletAndData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildVotingSection(),
                const Divider(height: 32),
                _buildDonationHistorySection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
