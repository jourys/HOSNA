import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';

class DonorVoting extends StatefulWidget {
  final int projectId;
  final String walletAddress;
  final String projectName;

  const DonorVoting({
    Key? key,
    required this.projectId,
    required this.walletAddress,
    required this.projectName,
  }) : super(key: key);

  @override
  _DonorVotingState createState() => _DonorVotingState();
}

class _DonorVotingState extends State<DonorVoting> {
  final BlockchainService _blockchainService = BlockchainService();
  String? _selectedOption;
  List<String> _votingOptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVotingOptions();
  }

  Future<void> _fetchVotingOptions() async {
    setState(() => _isLoading = true);
    try {
      final options = await _blockchainService.getVotingOptions(widget.projectId);
      setState(() {
        _votingOptions = [...options, "Request a refund"];
      });
    } catch (e) {
      print("❌ Error fetching voting options: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading voting options: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitVote() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an option to vote')),
      );
      return;
    }

    try {
      // Check if donor has already voted
      final hasVoted = await _blockchainService.hasDonorVoted(
        widget.projectId,
        widget.walletAddress,
      );
      
      if (hasVoted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already voted for this project')),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Get the index of the selected option
      final optionIndex = _votingOptions.indexOf(_selectedOption!);
      
      // Submit vote to blockchain
      await _blockchainService.submitDonorVote(
        widget.projectId,
        _selectedOption!,
        widget.walletAddress,
      );

      // Close loading indicator
      Navigator.pop(context);

      // Show success message and go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote submitted successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      // Close loading indicator
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting vote: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF4A6DA7),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'project details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Text(
              widget.projectName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Select a project to which you\'d like your donation to be directed.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 20),
                    ..._votingOptions.map((option) => _buildVotingOption(option)),
                    SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitVote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF4A6DA7),
                          padding: EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'vote',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildVotingOption(String optionName) {
    bool isSelected = _selectedOption == optionName;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Color(0xFF4A6DA7) : Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: () {
          setState(() {
            _selectedOption = optionName;
          });
        },
        title: Text(
          optionName,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
        ),
        leading: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Color(0xFF4A6DA7) : Colors.grey[400]!,
              width: 2,
            ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4A6DA7),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
} 