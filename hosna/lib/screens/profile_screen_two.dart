import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart'; // لاستخدام http requests
import 'package:flutter/services.dart';

class ProfileScreenTwo extends StatefulWidget {
  const ProfileScreenTwo({super.key});

  @override
  _ProfileScreenTwoState createState() => _ProfileScreenTwoState();
}

class _ProfileScreenTwoState extends State<ProfileScreenTwo> {
  late Web3Client _web3Client;  // لتهيئة الاتصال بالبلوكشين
  late String _donorAddress;    // عنوان المحفظة الخاصة بالمتبرع
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  
  // تغيير rpcUrl والعنوان الخاص بالعقد
  final String rpcUrl = 'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0x79FB556a6A12568B9DceA18EE474d05437Dc5987';

  @override
  void initState() {
    super.initState();
    _initializeWeb3();
  }

  // تهيئة الاتصال بالبلوكشين
  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());
    // هنا يمكن إضافة عنوان المحفظة الخاصة بك أو أي عنوان آخر
    _donorAddress = '0x6d910d38827AF569011b4a5AeCC0AC9a15Ff85A3';
    await _getDonorData();
  }

  // استرجاع بيانات المتبرع من العقد الذكي
  Future<void> _getDonorData() async {
    final contract = await _loadContract();
    final firstName = await _callGetDonorMethod(contract, 'firstName');
    final lastName = await _callGetDonorMethod(contract, 'lastName');
    final email = await _callGetDonorMethod(contract, 'email');
    final phone = await _callGetDonorMethod(contract, 'phone');

    setState(() {
      _firstName = firstName;
      _lastName = lastName;
      _email = email;
      _phone = phone;
    });
  }

  // تحميل العقد الذكي
  Future<DeployedContract> _loadContract() async {
    final abiJson = await rootBundle.loadString('assets/DonorRegistry.json');
    final abi = ContractAbi.fromJson(abiJson, 'DonorRegistry');
    return DeployedContract(abi, EthereumAddress.fromHex(contractAddress));
  }

  // استدعاء دالة من العقد الذكي للحصول على البيانات
  Future<String> _callGetDonorMethod(DeployedContract contract, String methodName) async {
    final function = contract.function(methodName);
    final result = await _web3Client.call(
      contract: contract,
      function: function,
      params: [EthereumAddress.fromHex(_donorAddress)],
    );
    return result[0] as String;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[900],
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        color: Colors.blue[900],
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.grey[200],
                child: Icon(
                  Icons.person_2_outlined,
                  size: 75,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '$_firstName $_lastName',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
              Text(
                _email,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 50),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      infoRow('Phone Number :', _phone),
                      infoRow('Email :', _email),
                      SizedBox(height: 200),
                      Center(
                        child: SizedBox(
                            height: MediaQuery.of(context).size.height * .066,
                            width: MediaQuery.of(context).size.width * .8,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Text(
                                'Log out',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue[900],
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.blue[900]!,
                                      ),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24)))),
                            )),
                      ),
                      SizedBox(height: 20),
                      Center(
                        child: SizedBox(
                            height: MediaQuery.of(context).size.height * .066,
                            width: MediaQuery.of(context).size.width * .8,
                            child: ElevatedButton(
                              onPressed: () {},
                              child: Text(
                                'Delete Account',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.red[900]!,
                                      ),
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24)))),
                            )),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w500, color: Colors.blue),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}