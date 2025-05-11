import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/DonorScreens/DonorHomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:web3dart/web3dart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart'; // Make sure Firebase is initialized

import 'dart:io';

class EditDonorProfileScreen extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  EditDonorProfileScreen({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
  });

  @override
  _EditDonorProfileScreenState createState() => _EditDonorProfileScreenState();
}

class _EditDonorProfileScreenState extends State<EditDonorProfileScreen> {
  late Web3Client _web3Client;

  String _donorAddress = '';
  String _profilePictureUrl = '';
  final String rpcUrl =
      'https://sepolia.infura.io/v3/2b1a8905cb674dd3b2c0294a957355a1';
  final String contractAddress = '0xF565D5C3907aBA80e1e613030C250c6addea6443';

  final _formKey = GlobalKey<FormState>();

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  File? _imageFile;

  final ImagePicker _picker = ImagePicker(); // Initialize the image picker
  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    _loadProfilePicture();
    _web3Client = Web3Client(rpcUrl, Client());

    // ✅ Directly initialize controllers with provided values
    firstNameController = TextEditingController(text: widget.firstName);
    lastNameController = TextEditingController(text: widget.lastName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
  }

  Future<void> _initializeWeb3() async {
    _web3Client = Web3Client(rpcUrl, Client());
    final prefs = await SharedPreferences.getInstance();
    _donorAddress = prefs.getString('walletAddress') ?? '';
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImageToFirebase();
    }
  }

  Future<void> _takePicture() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImageToFirebase();
    }
  }

  Future<void> _loadProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    final walletAddress = prefs.getString('walletAddress') ?? '';

    if (walletAddress.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(walletAddress)
            .get();

        if (doc.exists && doc.data()?.containsKey('profile_picture') == true) {
          setState(() {
            _profilePictureUrl = doc.data()!['profile_picture'];
          });
        }
      } catch (e) {
        print('❌ Error loading profile picture: $e');
      }
    }
  }

  Future<bool> isPhoneNumberTaken(String phone) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();

      final prefs = await SharedPreferences.getInstance();
      String? myWallet = prefs.getString('walletAddress');

      // If the phone is used by someone else (not this user), return true
      return querySnapshot.docs.any((doc) => doc.id != myWallet);
    } catch (e) {
      print('❌ Error checking phone duplication: $e');
      return false;
    }
  }

  Future<void> _uploadImageToFirebase() async {
    if (_imageFile == null || _donorAddress.isEmpty) {
      print('⚠️ No image selected or donor address is empty.');
      return;
    }

    try {
      print('🔄 Starting image upload process...');
      FirebaseStorage storage = FirebaseStorage.instance;
      String filePath = 'profile_pictures/$_donorAddress.jpg';
      Reference storageRef = storage.ref(filePath);

      print('📂 Uploading image to Firebase Storage at: $filePath');

      UploadTask uploadTask = storageRef.putFile(_imageFile!);

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        if (taskSnapshot.totalBytes > 0) {
          double progress =
              (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
          print('📡 Upload Progress: ${progress.toStringAsFixed(2)}%');
        } else {
          print('⚠️ Upload progress unavailable.');
        }
      });

      // Wait for upload to complete and check for errors
      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        print('✅ Image successfully uploaded.');

        // Retrieve download URL
        try {
          String downloadUrl = await storageRef.getDownloadURL();
          print('✅ Download URL: $downloadUrl');

          // Save URL to Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_donorAddress)
              .set({'profile_picture': downloadUrl}, SetOptions(merge: true));

          print('✅ Profile image URL saved to Firestore.');

          setState(() {
            _profilePictureUrl = downloadUrl;
          });
        } catch (e) {
          print('❌ Error retrieving download URL: $e');
        }
      } else {
        print('❌ Upload failed with state: ${snapshot.state}');
      }
    } catch (e) {
      print('❌ Error uploading image: $e');
    }
  }

  Future<void> _getDonorData() async {
    if (_donorAddress.isEmpty) {
      print("⚠️ No donor wallet address found.");
      return;
    }

    try {
      final contract = await _loadContract();
      final function = contract.function('getDonor');

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [EthereumAddress.fromHex(_donorAddress)],
      );

      if (result.isNotEmpty) {
        setState(() {
          firstNameController.text = result[0] as String;
          lastNameController.text = result[1] as String;
          emailController.text = result[2] as String;
          phoneController.text = result[3] as String;
        });

        print("✅ Donor data retrieved successfully!");
      } else {
        print("⚠️ No donor data found for $_donorAddress");
      }
    } catch (e) {
      print("❌ Error fetching donor data: $e");
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
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_wallet", "type": "address"},
      {"name": "_firstName", "type": "string"},
      {"name": "_lastName", "type": "string"},
      {"name": "_email", "type": "string"},
      {"name": "_phone", "type": "string"}
    ],
    "name": "updateDonor",
    "outputs": [],
    "payable": false,
    "stateMutability": "nonpayable",
    "type": "function"
  }
]''';

    return DeployedContract(
      ContractAbi.fromJson(contractAbi, 'DonorRegistry'),
      EthereumAddress.fromHex(contractAddress),
    );
  }

  Future<void> _updateDonorData() async {
    if (!mounted) return; // ✅ Prevents running if widget is unmounted
    print("🔄 Starting donor profile update...");

    final prefs = await SharedPreferences.getInstance();
    String? walletAddress = prefs.getString('walletAddress');
    String? privateKey = prefs.getString('privateKey_$walletAddress');
    print("✅ Private key : $privateKey");
    if (privateKey == null || privateKey.isEmpty) {
      print("❌ Error: Private key not found for wallet: $walletAddress");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: Private key not found! Please re-login.")),
        );
      }
      return;
    }

    _donorAddress = walletAddress ?? '';

    // ✅ Validate Private Key Format
    privateKey = privateKey.replaceAll("0x", "").trim();
    if (privateKey.length != 64 ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey)) {
      print("❌ Error: Invalid private key format!");
      return;
    }

    if (_donorAddress.isEmpty) {
      print("❌ Error: Invalid wallet address - $_donorAddress");
      return;
    }

    String firstName = firstNameController.text.trim();
    if (firstName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(" First name cannot be empty")),
        );
      }
      return;
    }

    bool taken = await isPhoneNumberTaken(phoneController.text);
    if (taken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                " This phone number is already registered with another account.")),
      );

      return;
    }

    print("🟢 Fetching contract...");
    final contract = await _loadContract();
    final function = contract.function('updateDonor');

    try {
      final credentials = EthPrivateKey.fromHex(privateKey);

      // 📝 Send transaction and get the transaction hash
      String txHash = await _web3Client.sendTransaction(
        credentials,
        web3.Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [
            EthereumAddress.fromHex(_donorAddress),
            firstNameController.text,
            lastNameController.text,
            emailController.text,
            phoneController.text,
          ],
          gasPrice: web3.EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111,
      );

      print("✅ Transaction Hash: $txHash");
      print("Waiting for updating your profile...");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Waiting for updating your profile...')),
        );
      }

      // 🕒 Optionally, wait a few seconds before fetching updated data
      await Future.delayed(Duration(seconds: 10));

      print("✅ Profile update confirmed, navigating back!");

      if (mounted) _showSuccessDialog();
    } catch (e) {
      print("❌ Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating profile: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Edit Profile',
          style: TextStyle(color: const Color.fromRGBO(24, 71, 137, 1)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: const Color.fromRGBO(24, 71, 137, 1)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_profilePictureUrl.isNotEmpty
                              ? NetworkImage(_profilePictureUrl)
                              : null) as ImageProvider?,
                      child: _imageFile == null && _profilePictureUrl.isEmpty
                          ? Icon(Icons.account_circle,
                              size: 100, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue[900]),
                        iconSize: 40,
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.camera),
                                    title: Text('Take a Picture'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _takePicture();
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.photo_album),
                                    title: Text('Select from Gallery'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _pickImage();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 50),
              _buildTextField(firstNameController, 'First Name'),
              SizedBox(height: 10),
              _buildTextField(lastNameController, 'Last Name'),
              SizedBox(height: 10),
              _buildTextField(emailController, 'Email', isEmail: true),
              SizedBox(height: 10),
              _buildTextField(phoneController, 'Phone', isPhone: true),
              SizedBox(height: 150),
              ElevatedButton(
                onPressed: _updateDonorData,
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isEmail = false, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        style: TextStyle(
          color: isEmail ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isEmail ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(
              color: isEmail ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(
              color: isEmail ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
            borderSide: BorderSide(
              color: isEmail ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
              width: 2.0,
            ),
          ),
        ),
        readOnly: isEmail,
        enabled: !isEmail,
        keyboardType: isPhone ? TextInputType.number : TextInputType.text,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')), // Deny all spaces
          if (isPhone) ...[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ],
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Enter $label';
          }
          if (isPhone) {
            if (value.length != 10) {
              return 'Phone number must be exactly 10 digits';
            }
            if (!value.startsWith('05')) {
              return 'Phone number must start with 05';
            }
          }
          return null;
        },
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          content: SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Color.fromARGB(255, 54, 142, 57),
                  size: 50,
                ),
                SizedBox(height: 20),
                Text(
                  'Profile updated successfully!',
                  style: TextStyle(
                    color: Color.fromARGB(255, 54, 142, 57),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Auto close dialog and go back
    Future.delayed(Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      Navigator.pop(context, true); // return to previous screen
    });
  }
}
