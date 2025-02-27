import 'package:flutter/material.dart';
import 'package:hosna/screens/CharityScreens/ProfileScreenCharity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharityEmployeeHomePage extends StatefulWidget {
  const CharityEmployeeHomePage({super.key});

  @override
  _CharityEmployeeHomePageState createState() =>
      _CharityEmployeeHomePageState();
}

class _CharityEmployeeHomePageState extends State<CharityEmployeeHomePage> {
  String _firstName = '';

  @override
  void initState() {
    super.initState();
    // _loadEmployeeData();
    printUserType();
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
  // Future<void> _loadEmployeeData() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   setState(() {
  //     _firstName = prefs.getString('employeeFirstName') ?? 'Employee';
  //   });
  // }

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
            padding: const EdgeInsets.only(left: 20, bottom: 20),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Good Day, !",
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
                      width: 120,
                      height: 80,
                      child: IconButton(
                        icon: const Icon(Icons.account_circle,
                            size: 85, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ProfileScreenCharity()),
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
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  '🏠 Charity Employee Dashboard',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
