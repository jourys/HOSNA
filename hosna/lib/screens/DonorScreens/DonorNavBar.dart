import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:hosna/screens/DonorScreens/DonorNotificationsCenter.dart';
import 'package:hosna/screens/organizations.dart';
import 'package:hosna/screens/BrowseProjects.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatefulWidget {
  final String? walletAddress;

  const MainScreen({super.key, this.walletAddress});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String? walletAddress;
  String? firstName;
  bool isSuspended = false; // Track suspension status

  List<Widget> get _pages {
    return [
      HomePage(),
      BrowseProjects(walletAddress: walletAddress ?? ''),
      NotificationsPage(walletAddress: walletAddress ?? ''),
      OrganizationsPage(walletAddress: walletAddress ?? ''),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadWalletAddress();
  }

  Future<void> _loadWalletAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedWalletAddress = prefs.getString('walletAddress');

    setState(() {
      walletAddress = savedWalletAddress ?? widget.walletAddress;
      firstName = prefs.getString('firstName') ?? "User";
    });

    if (walletAddress != null) {
      _listenForSuspension(walletAddress!);
    }
  }

  void _listenForSuspension(String wallet) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(wallet)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        bool suspendStatus = snapshot['isSuspend'] ?? false;
        setState(() {
          isSuspended = suspendStatus;
        });
      }
    }, onError: (error) {
      print("❌ Error checking suspension: $error");
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Prevents resizing when the keyboard appears
      body: Stack(
        // Using Stack to place the button above all widgets
        children: [
          Column(
            children: [
              Expanded(child: _pages[_selectedIndex]), // Main page content

              if (isSuspended)
                Container(
                  color: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(vertical: 1, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Your account has been suspended. You cannot make any operation.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedIndex = 2; // Navigate to NotificationsPage
                          });
                        },
                        child: const Text(
                          "More",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          DraggableContactUsButton(), // Adding the draggable button here
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color.fromRGBO(24, 71, 137, 1),
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 38),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              _selectedIndex == 1
                  ? 'assets/BlueProjects.png'
                  : 'assets/Projects.png',
              width: 30,
              height: 30,
            ),
            label: 'Projects',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications, size: 35),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.apartment, size: 35),
            label: 'Organizations',
          ),
        ],
      ),
    );
  }
}

class DraggableContactUsButton extends StatefulWidget {
  const DraggableContactUsButton({Key? key}) : super(key: key);

  @override
  _DraggableContactUsButtonState createState() =>
      _DraggableContactUsButtonState();
}

class _DraggableContactUsButtonState extends State<DraggableContactUsButton> {
  double _top = 650; // Default position (adjust as needed)
  double _left = 350;

  void _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'Hosna@gmail.com', // Replace with actual support email
      queryParameters: {'subject': 'Support Request'},
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      debugPrint("Could not launch email");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: _top,
          left: _left,
          child: Draggable(
            feedback: FloatingActionButton(
              onPressed: _launchEmail,
              backgroundColor: const Color.fromARGB(
                  255, 255, 255, 255), // Remove background color
              // Add subtle shadow for elevation
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    50), // Circular button with no background
              ),
              // Keeps color during dragging
              elevation: 8,
              child: const Icon(Icons.mail,
                  color: Color.fromRGBO(24, 71, 137, 1), size: 32),
            ),
            childWhenDragging: const SizedBox(), // Hides original when dragging
            onDraggableCanceled: (velocity, offset) {
              setState(() {
                // Snap to the nearest edge
                double screenWidth = MediaQuery.of(context).size.width;
                double rightEdge = screenWidth - 56; // The width of the button

                // Determine whether to snap to the left or right edge
                if (offset.dx < screenWidth / 2) {
                  _left = 16; // Snap to left edge
                } else {
                  _left = rightEdge; // Snap to right edge
                }

                // Clamp the top value to ensure the button stays within the screen
                _top = offset.dy
                    .clamp(0.0, MediaQuery.of(context).size.height - 80);
              });
            },
            child: FloatingActionButton(
              onPressed: _launchEmail,
              backgroundColor: Colors.white,
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF0D1B2A),
                      Color(0xFF1B365D),
                      Color(0xFF4B9CD3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.mail,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
