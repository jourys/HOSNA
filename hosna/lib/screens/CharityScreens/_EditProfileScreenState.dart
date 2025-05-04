// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosna/screens/CharityScreens/ProfileScreenCharity.dart';
import 'package:hosna/screens/CharityScreens/CharityHomePage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:hosna/screens/CharityScreens/BlockchainService.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class EditProfileScreen extends StatefulWidget {
  final String organizationName;
  final String email;
  final String phone;
  final String licenseNumber;
  final String organizationCity;
  final String organizationURL;
  final String establishmentDate;
  final String description;

  EditProfileScreen({
    required this.organizationName,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.organizationCity,
    required this.organizationURL,
    required this.establishmentDate,
    required this.description,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late web3.Web3Client _web3Client;
  late String _charityAddress;
  Map<String, dynamic> profileData = {};
  File? _imageFile;
  String _profilePictureUrl = '';
  final ImagePicker _picker = ImagePicker();

  final String rpcUrl =
      'https://sepolia.infura.io/v3/8780cdefcee745ecabbe6e8d3a63e3ac';
  final String contractAddress = '0x25ef93ac312D387fdDeFD62CD852a29328c4B122';

  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController licenseController;
  late TextEditingController cityController;
  late TextEditingController websiteController;
  late TextEditingController dateController;
  late TextEditingController descriptionController;
  @override
  void initState() {
    super.initState();
    _initializeWeb3();
    _loadProfilePicture();
    nameController = TextEditingController(text: widget.organizationName);
    emailController = TextEditingController(text: widget.email);
    phoneController = TextEditingController(text: widget.phone);
    licenseController = TextEditingController(text: widget.licenseNumber);
    cityController = TextEditingController(text: widget.organizationCity);
    websiteController = TextEditingController(text: widget.organizationURL);
    dateController = TextEditingController(text: widget.establishmentDate);
    descriptionController = TextEditingController(text: widget.description);
  }

  Future<void> _initializeWeb3() async {
    _web3Client = web3.Web3Client(rpcUrl, Client());
    final prefs = await SharedPreferences.getInstance();

    // Retrieve stored wallet address
    String storedAddress = prefs.getString('walletAddress') ?? '';

    _charityAddress = prefs.getString('walletAddress') ?? '';
  }

  Future<web3.DeployedContract> _loadContract() async {
    final contractAbi = '''[
    {
      "inputs": [
        { "internalType": "address", "name": "_wallet", "type": "address" },
        { "internalType": "string", "name": "_name", "type": "string" },
        { "internalType": "string", "name": "_email", "type": "string" },
        { "internalType": "string", "name": "_phone", "type": "string" },
        { "internalType": "string", "name": "_licenseNumber", "type": "string" },
        { "internalType": "string", "name": "_city", "type": "string" },
        { "internalType": "string", "name": "_description", "type": "string" },
        { "internalType": "string", "name": "_website", "type": "string" },
        { "internalType": "string", "name": "_establishmentDate", "type": "string" }
      ],
      "name": "updateCharity",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    }
  ]''';
    final contract = web3.DeployedContract(
      web3.ContractAbi.fromJson(contractAbi, 'CharityRegistration'),
      web3.EthereumAddress.fromHex(contractAddress),
    );
    return contract;
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

  Future<void> estimateGasCost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final walletAddress = prefs.getString('walletAddress') ?? '';
      String privateKeyKey = 'privateKey_$walletAddress';
      String? privateKey = prefs.getString(privateKeyKey);

      if (privateKey == null || privateKey.isEmpty || walletAddress.isEmpty) {
        print("❌ Private Key or Wallet Address missing!");
        return;
      }

      final contract = await _loadContract();
      final function = contract.function('updateCharity');

      final estimatedGas = await _web3Client.estimateGas(
        sender: web3.EthereumAddress.fromHex(walletAddress),
        to: contract.address,
        data: function.encodeCall([
          web3.EthereumAddress.fromHex(walletAddress),
          nameController.text.toString(),
          emailController.text.toString(),
          phoneController.text.toString(),
          licenseController.text.toString(),
          cityController.text.toString(),
          descriptionController.text.toString(),
          websiteController.text.toString(),
          dateController.text.toString(),
        ]),
      );

      print("⛽ Estimated Gas Cost: ${estimatedGas.toString()} Wei");
      final estimatedGasEth = web3.EtherAmount.inWei(estimatedGas)
          .getValueInUnit(web3.EtherUnit.ether);

      print("⛽ Estimated Gas in ETH: $estimatedGasEth ETH");
    } catch (e) {
      print("❌ Error estimating gas: $e");
    }
  }

  Future<Map<String, dynamic>> fetchCharityData(String walletAddress) async {
    try {
      print("🔍 Fetching updated profile data for wallet: $walletAddress");

      if (walletAddress.isEmpty) {
        print("❌ Error: Wallet address is empty.");
        return {};
      }

      final contract = await _loadContract();
      print("✅ Contract loaded successfully.");

      final function = contract.function('getCharity');
      print("✅ Function 'getCharity' prepared.");

      final result = await _web3Client.call(
        contract: contract,
        function: function,
        params: [web3.EthereumAddress.fromHex(walletAddress)],
      );
      print("📌 Raw Result from Blockchain: $result");

      if (result.isEmpty) {
        print("❌ No data found for wallet: $walletAddress");
        return {};
      }

      Map<String, dynamic> data = {
        "name": result[0].toString(),
        "email": result[1].toString(),
        "phone": result[2].toString(),
        "license": result[3].toString(),
        "city": result[4].toString(),
        "description": result[5].toString(),
        "website": result[6].toString(),
        "date": result[7].toString(),
      };

      print("✅ Structured Data: $data");

      return data;
    } catch (e) {
      print("❌ Error fetching charity data: $e");
      return {};
    }
  }

  Future<void> _updateCharityData() async {
    print("🟢 _updateCharityData() called!");

    final prefs = await SharedPreferences.getInstance();
    final storedAddress = prefs.getString('walletAddress') ?? '';

    if (storedAddress.isEmpty) {
      print("❌ Error: Wallet Address not found in SharedPreferences.");
      return;
    }

    String privateKeyKey = 'privateKey_$storedAddress';
    String? privateKey = prefs.getString(privateKeyKey);

    if (privateKey == null || privateKey.isEmpty) {
      print("❌ No private key found!");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Private key not found! Log in again.')),
      );
      return;
    }

    final derivedAddress = web3.EthPrivateKey.fromHex(privateKey).address.hex;
    if (storedAddress != derivedAddress) {
      await prefs.setString('walletAddress', derivedAddress);
    }

    String name = nameController.text.trim();
    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String license = licenseController.text.trim();
    String city = cityController.text.trim();
    String date = dateController.text.trim();
    String website = websiteController.text.trim();
    String description = descriptionController.text.trim();

    if (name.isEmpty) {
      showError("Organization Name cannot be empty.");
      return;
    }
    if (email.isEmpty ||
        !RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(email)) {
      showError("Enter a valid email address.");
      return;
    }
    if (phone.isEmpty || phone.length != 10 || !phone.startsWith('05')) {
      showError("Phone number must be 10 digits and start with 05.");
      return;
    }
    if (license.isEmpty) {
      showError("License Number cannot be empty.");
      return;
    }
    if (city.isEmpty) {
      showError("City cannot be empty.");
      return;
    }
    if (date.isEmpty) {
      showError("Establishment Date cannot be empty.");
      return;
    }

    if (website.isNotEmpty &&
    !RegExp(r'^www\.[a-zA-Z0-9\-]+(\.[a-zA-Z]{2,})+$')
            .hasMatch(website)) {
      showError("Enter a valid website URL.");
      return;
    }

    if (description.length > 250) {
      showError("Description must be at most 250 characters.");
      return;
    }
    bool taken = await isPhoneNumberTaken(phone);
    if (taken) {
      showError(
          "This phone number is already registered with another account.");
      return;
    }

    print("🔹 Preparing transaction...");
    await estimateGasCost();

    final credentials = web3.EthPrivateKey.fromHex(privateKey);

    try {
      final contract = await _loadContract();
      final function = contract.function('updateCharity');

      await _web3Client.sendTransaction(
        credentials,
        web3.Transaction.callContract(
          contract: contract,
          function: function,
          parameters: [
            web3.EthereumAddress.fromHex(storedAddress),
            name,
            email,
            phone,
            license,
            city,
            description.isEmpty ? " " : description,
            website.isEmpty ? " " : website,
            date,
          ],
          gasPrice: web3.EtherAmount.inWei(BigInt.from(30000000000)),
          maxGas: 1000000,
        ),
        chainId: 11155111,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waiting for updating your profile...'),
          duration: Duration(seconds: 10),
        ),
      );
      print("✅ Transaction sent successfully!");
      await Future.delayed(Duration(seconds: 10));

      print("🔍 Fetching updated data...");
      final updatedData = await fetchCharityData(storedAddress);

      if (updatedData.isNotEmpty) {
        print("✅ Profile updated with new data: $updatedData");
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context, true);
      });
    } catch (e) {
      showError('Failed to update profile: $e');
    }
  }

  void showError(String message) {
    print("❌ Validation Error: $message");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  Future<void> _uploadImageToFirebase() async {
    if (_imageFile == null || _charityAddress.isEmpty) {
      print('⚠️ No image selected or charity address is empty.');
      return;
    }

    try {
      print('🔄 Starting image upload process...');
      FirebaseStorage storage = FirebaseStorage.instance;
      String filePath = 'user_profile_pictures/$_charityAddress.jpg';
      Reference storageRef = storage.ref(filePath);

      print('📂 Uploading image to Firebase Storage at: $filePath');

      UploadTask uploadTask = storageRef.putFile(_imageFile!);

      uploadTask.snapshotEvents.listen((taskSnapshot) {
        if (taskSnapshot.totalBytes > 0) {
          double progress =
              (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
          print('📡 Upload Progress: ${progress.toStringAsFixed(2)}%');
        }
      });

      TaskSnapshot snapshot = await uploadTask.whenComplete(() => null);

      if (snapshot.state == TaskState.success) {
        print('✅ Image successfully uploaded.');

        try {
          String downloadUrl = await storageRef.getDownloadURL();
          print('✅ Download URL: $downloadUrl');

          await FirebaseFirestore.instance
              .collection('users')
              .doc(_charityAddress)
              .set({'profilepicture': downloadUrl}, SetOptions(merge: true));

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
                          ? Icon(Icons.business, size: 100, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        iconSize: 32, // make the icon larger

                        icon: Icon(Icons.edit, color: Colors.blue[900]),
                        onPressed: () {
                          try {
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
                          } catch (e) {
                            print("❌ Error opening bottom sheet: $e");
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              _buildTextField(nameController, 'Organization Name'),
              _buildTextField(emailController, 'Email', readOnly: true),
              _buildTextField(phoneController, 'Phone', isPhone: true),
              // _buildTextField(licenseController, 'License Number'),
              _buildTextField(cityController, 'City'),
              _buildTextField(websiteController, 'Website'),
              // _buildTextField(dateController, 'Establishment Date'),
              _buildTextField(licenseController, 'License Number',
                  readOnly: true),
              _buildTextField(
                dateController,
                'Establishment Date',
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.tryParse(dateController.text) ??
                        DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      dateController.text =
                          pickedDate.toIso8601String().split('T')[0];
                    });
                  }
                },
              ),

              _buildTextField(descriptionController, 'Description',
                  maxLines: 3),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print("🟢 Save Changes Button Clicked!");
                  _updateCharityData(); // Wait for update to finish before navigating
                },
                child: Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color.fromRGBO(24, 71, 137, 1),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16), // Makes it bigger
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // Rounded corners
                  ),
                  textStyle: TextStyle(
                    fontSize: 18, // Optional: Make the text inside bigger too
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool isPhone = false,
    bool readOnly = false,
    bool? enabled,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          enabled: enabled ?? !readOnly,
          onTap: onTap,
          style: TextStyle(
            color: readOnly ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: readOnly ? Colors.grey : Color.fromRGBO(24, 71, 137, 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Color.fromRGBO(24, 71, 137, 1),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Color.fromRGBO(24, 71, 137, 1),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: isPhone ? TextInputType.number : TextInputType.text,
          inputFormatters: isPhone
              ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ]
              : [],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label cannot be empty';
            }
            if (label == 'Phone') {
              if (value.length != 10 || !value.startsWith('05')) {
                return 'Phone number must start with 05 and be 10 digits';
              }
            }

            if (label == 'City' &&
                !RegExp(r"^[a-zA-Z\s,.'-]{2,50}$").hasMatch(value)) {
              return 'Enter a valid city name';
            }
             if (label == 'Website' &&
    value!.isNotEmpty &&
    !RegExp(r'^www\.[a-zA-Z0-9\-]+(\.[a-zA-Z]{2,})+$')
        .hasMatch(value)) {
  return 'Enter a valid website URL';
            }

            if (label == 'Description' && value.length < 30) {
              return 'Description must be at least 30 characters';
            }

            return null;
          }),
    );
  }
}
