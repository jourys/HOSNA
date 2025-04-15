import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:typed_data';

class PostUpdate extends StatefulWidget {
  final int projectId;
  const PostUpdate({super.key, required this.projectId});

  @override
  State<PostUpdate> createState() => _PostUpdateState();
}

class _PostUpdateState extends State<PostUpdate> {
  File? _selectedImageFile;
  Uint8List? _webImageData;
  String? _imageName;

  final TextEditingController _postTextController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  bool _isPosting = false;

  void _updateButtonState() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _postTextController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _postTextController.removeListener(_updateButtonState);
    _postTextController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        final data = await pickedFile.readAsBytes();
        setState(() {
          _webImageData = data;
          _imageName = pickedFile.name;
        });
      } else {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    }
  }

  Future<void> _saveUpdateToFirebase() async {
    setState(() {
      _isPosting = true;
    });

    try {
      String? imageUrl;

      // Upload image (Web or Mobile)
      if (_selectedImageFile != null || _webImageData != null) {
        final fileName = const Uuid().v4();
        final ref = FirebaseStorage.instance
            .ref()
            .child('project_updates/$fileName.jpg');

        UploadTask uploadTask;
        if (kIsWeb) {
          uploadTask = ref.putData(_webImageData!);
        } else {
          uploadTask = ref.putFile(_selectedImageFile!);
        }

        final snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // Save update to Firestore
      await FirebaseFirestore.instance.collection('project_updates').add({
        'projectId': widget.projectId,
        'text': _postTextController.text.trim(),
        'imageUrl': imageUrl ?? '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to post update. Please try again.')),
      );
    } finally {
      setState(() {
        _isPosting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonEnabled =
        _postTextController.text.isNotEmpty && !_isPosting;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
      body: Column(
        children: [
          PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: AppBar(
              backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
              elevation: 0,
              leading: Container(),
              flexibleSpace: Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 20),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20, bottom: 10),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          "Post Update",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Image (Optional)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(24, 71, 137, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _webImageData != null
                            ? Image.memory(_webImageData!, fit: BoxFit.cover)
                            : _selectedImageFile != null
                                ? Image.file(_selectedImageFile!,
                                    fit: BoxFit.cover)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.add_photo_alternate,
                                          size: 50, color: Colors.grey),
                                      SizedBox(height: 10),
                                      Text('Tap to add an optional image',
                                          style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'How was the project progress?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(24, 71, 137, 1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _postTextController,
                      focusNode: _textFocusNode,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Write your update here (required)...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isButtonEnabled ? _saveUpdateToFirebase : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromRGBO(24, 71, 137, 1),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _isPosting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Post Update',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
