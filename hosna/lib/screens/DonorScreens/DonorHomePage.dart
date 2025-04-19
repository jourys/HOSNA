import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:hosna/screens/CharityScreens/projectDetails.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:hosna/screens/DonorScreens/DonorVoting.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/DonorScreens/DonationHistoryPage.dart';

import 'DonorProfile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BlockchainService _blockchainService = BlockchainService();
  String? walletAddress;
  String _firstName = '';
  List<Map<String, dynamic>> votingProjects = [];
  List<Map<String, dynamic>> donationHistory = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  String _walletAddress = '';

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
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');
      final firstName = prefs.getString('firstName') ?? '';

      if (firstName.isNotEmpty) {
        setState(() {
          _firstName = firstName;
        });
      }
    } catch (e) {
      print("Error loading user name: $e");
    }
  }

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

    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString('walletAddress');

      if (address == null || address.isEmpty) {
        throw Exception('Wallet address not found');
      }

      setState(() {
        walletAddress = address;
      });

      await _loadUserName();

      // Get all projects
      final allProjects = await _blockchainService.fetchAllProjects();
      List<Map<String, dynamic>> eligibleVotingProjects = [];

      for (var project in allProjects) {
        // Check if project is failed or canceled
        final projectDoc = await FirebaseFirestore.instance
            .collection('projects')
            .doc(project['id'].toString())
            .get();

        if (projectDoc.exists) {
          final data = projectDoc.data() as Map<String, dynamic>;
          final isCanceled = data['isCanceled'] ?? false;
          final votingInitiated = data['votingInitiated'] ?? false;

          // Check if project is failed or canceled and has voting initiated
          if ((isCanceled || project['state'] == 4) && votingInitiated) {
            // Check if donor has donated to this project
            final hasDonated = await _blockchainService.hasDonatedToProject(
                project['id'], address);

            // Check if donor has already voted
            final hasVoted =
                await _blockchainService.hasDonorVoted(project['id'], address);

            // Only add if donor has donated but hasn't voted yet
            if (hasDonated && !hasVoted) {
              // Add project details
              project['votingId'] = project['id'];
              project['votingDeadline'] =
                  DateTime.fromMillisecondsSinceEpoch(project['endTime'] * 1000)
                      .toString();
              eligibleVotingProjects.add(project);
            }
          }
        }
      }

      setState(() {
        votingProjects = eligibleVotingProjects;
      });

      // Get donation history from SharedPreferences
      List<Map<String, dynamic>> historyList = [];
      final donationsKey = 'donations_${address}';
      final donationsJson = prefs.getString(donationsKey);

      print("📌 Attempting to load donations for wallet: $address");
      print("📌 Donations JSON: $donationsJson");

      if (donationsJson != null) {
        try {
          final List<dynamic> donations = json.decode(donationsJson);
          // Filter donations to only include those made by the current user
          final filteredDonations = donations.where((donation) {
            final donorWallet =
                donation['donorWallet']?.toString().toLowerCase();
            final isCurrentUserDonation = donorWallet == address.toLowerCase();
            print(
                "📌 Checking donation - Donor: $donorWallet, Current User: ${address.toLowerCase()}, Match: $isCurrentUserDonation");
            return isCurrentUserDonation;
          }).toList();

          historyList = List<Map<String, dynamic>>.from(filteredDonations);
          print(
              "✅ Successfully loaded ${historyList.length} donations from storage for current user");

          // Process each donation
          for (var donation in historyList) {
            try {
              print("📌 Processing donation: ${donation['name']}");

              // Handle endDate conversion
              dynamic endDate = donation['endDate'];
              int endDateMillis;

              if (endDate is DateTime) {
                endDateMillis = endDate.millisecondsSinceEpoch;
              } else if (endDate is String) {
                try {
                  if (endDate.trim().isEmpty ||
                      endDate.toLowerCase() == 'n/a') {
                    throw FormatException(
                        "Invalid date format string: $endDate");
                  }
                  endDateMillis =
                      DateTime.parse(endDate).millisecondsSinceEpoch;
                } catch (e) {
                  print("⚠️ Error parsing endDate string '$endDate': $e");
                  endDateMillis = DateTime.now().millisecondsSinceEpoch;
                }
              } else if (endDate is int) {
                endDateMillis = endDate;
              } else {
                endDateMillis = DateTime.now().millisecondsSinceEpoch;
              }

              // Update the donation with proper date format
              donation['endDate'] = endDateMillis;

              // Get current project status from Firestore

              // Use the stored donation amount
              final storedAmount = donation['donatedAmount'] ?? 0.0;
              donation['anonymousAmount'] = storedAmount;
              donation['nonAnonymousAmount'] = storedAmount;

              print("✅ Successfully processed donation: ${donation['name']}");
            } catch (e) {
              print("❌ Error processing donation: $e");
              continue;
            }
          }
        } catch (e) {
          print("❌ Error parsing donations JSON: $e");
          historyList = [];
        }
      } else {
        print("⚠️ No donations found for wallet: $address");
      }

      // Sort donations by timestamp in descending order (newest first)
      historyList
          .sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

      print("📊 Final history list length: ${historyList.length}");

      if (!mounted) return;
      setState(() {
        donationHistory = historyList;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading data: $e");
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
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: votingProjects.length,
            itemBuilder: (context, index) {
              final project = votingProjects[index];
              final progress = ((project['donatedAmount'] ?? 0.0) /
                      (project['totalAmount'] ?? 1.0) *
                      100)
                  .toStringAsFixed(1);

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  title: Text(project['name'] ?? 'Unnamed Project'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progress: $progress%'),
                      if (project['votingDeadline'] != null)
                        Text('Voting Deadline: ${project['votingDeadline']}'),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/donor_voting',
                        arguments: {
                          'projectId': project['id'],
                          'projectName': project['name'],
                        },
                      );
                    },
                    child: Text('Vote'),
                  ),
                ),
              );
            },
          ),
      ],
    );
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
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DonationHistoryPage(),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View Donation History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.blue[900],
                ),
              ],
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
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: donationHistory.length,
            itemBuilder: (context, index) {
              final donation = donationHistory[index];
              final totalAmount = (donation['totalAmount'] ?? 0.0).toDouble();
              final donatedAmount =
                  (donation['donatedAmount'] ?? 0.0).toDouble();
              final progress = totalAmount > 0
                  ? (donatedAmount / totalAmount * 100).toStringAsFixed(1)
                  : '0.0';

              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  title: Text(
                    donation['name'] ?? 'Unnamed Project',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        'Donated: ${donatedAmount.toStringAsFixed(5)} ETH',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Total Goal: ${totalAmount.toStringAsFixed(5)} ETH',
                        style: TextStyle(
                          color: Colors.blue[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Progress: $progress%',
                        style: TextStyle(
                          color: Colors.orange[700],
                        ),
                      ),
                      Text(
                        'Project Type: ${donation['projectType'] ?? 'Unknown'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
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
                          // deadline: '',
                          totalAmount: totalAmount,
                          projectType: donation['projectType'] ?? 'Unknown',
                          projectCreatorWallet:
                              donation['projectCreatorWallet'] ?? '',
                          donatedAmount: donatedAmount,
                          progress: totalAmount > 0
                              ? donatedAmount / totalAmount
                              : 0.0,
                          // startDate: '',
                          deadline: DateTime.now().toIso8601String(),
                          startDate: DateTime.now().toIso8601String(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
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
