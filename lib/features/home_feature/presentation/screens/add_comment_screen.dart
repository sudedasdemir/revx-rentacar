import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddCommentScreen extends StatefulWidget {
  final String bookingId;
  final String carName;
  final String carId;
  final Map<String, dynamic>? existingComment;

  const AddCommentScreen({
    Key? key,
    required this.bookingId,
    required this.carName,
    required this.carId,
    this.existingComment,
  }) : super(key: key);

  @override
  State<AddCommentScreen> createState() => _AddCommentScreenState();
}

class _AddCommentScreenState extends State<AddCommentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();
  double _rating = 0;
  bool _isLoading = false;
  bool _isUploading = false;
  File? selectedImage;
  String? uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    if (widget.existingComment != null) {
      _commentController.text = widget.existingComment!['text'] as String;
      _rating = (widget.existingComment!['rating'] as num).toDouble();
      uploadedImageUrl = widget.existingComment!['imageUrl'] as String?;
    }
  }

  Future<void> pickImageFromGallery() async {
    try {
      final pickedFile = await imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        print('Image picked from gallery: ${pickedFile.path}');
        setState(() {
          selectedImage = File(pickedFile.path);
          _isUploading = true;
        });
        await uploadImageToImgur(selectedImage!);
      } else {
        print('No image selected');
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> uploadImageToImgur(File imageFile) async {
    try {
      print('Starting image upload to Imgur...');
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID e97b7b6366d364f'},
        body: {'image': base64Image, 'type': 'base64'},
      );

      print('Imgur API Response Status: ${response.statusCode}');
      print('Imgur API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final imageUrl = responseData['data']['link'];
        print('Image uploaded successfully. URL: $imageUrl');

        setState(() {
          uploadedImageUrl = imageUrl;
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('Failed to upload image. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitComment() async {
    if (_formKey.currentState!.validate() && _rating > 0) {
      setState(() => _isLoading = true);

      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId == null) throw Exception('User not logged in');

        print('Submitting comment with image URL: $uploadedImageUrl');

        // Get user data from Firestore
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

        final userData = userDoc.data() as Map<String, dynamic>?;
        final userName =
            userData?['Name'] ??
            userData?['fullName'] ??
            userData?['displayName'] ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Anonymous User';

        final commentData = {
          'userId': userId,
          'userName': userName,
          'bookingId': widget.bookingId,
          'carId': widget.carId,
          'carName': widget.carName,
          'text': _commentController.text.trim(),
          'rating': _rating,
          'imageUrl': uploadedImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        print('Comment data to be saved: $commentData');

        if (widget.existingComment != null) {
          await FirebaseFirestore.instance
              .collection('comments')
              .doc(widget.existingComment!['id'])
              .update(commentData);
          print('Comment updated successfully');
        } else {
          commentData['createdAt'] = FieldValue.serverTimestamp();
          final docRef = await FirebaseFirestore.instance
              .collection('comments')
              .add(commentData);
          print('Comment added successfully with ID: ${docRef.id}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.existingComment != null
                    ? 'Comment updated successfully'
                    : 'Comment added successfully',
              ),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (_rating == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a rating')));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingComment != null ? 'Edit Review' : 'Add Review',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.carName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Rating',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Your Review',
                  hintText: 'Share your experience with this car...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your review';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Image upload section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Photo (Optional)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _isUploading ? null : pickImageFromGallery,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child:
                          _isUploading
                              ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 8),
                                    Text('Uploading image...'),
                                  ],
                                ),
                              )
                              : uploadedImageUrl != null
                              ? Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      uploadedImageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 200,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print('Error loading image: $error');
                                        return const Center(
                                          child: Icon(
                                            Icons.error_outline,
                                            size: 48,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            uploadedImageUrl = null;
                                            selectedImage = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              )
                              : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_photo_alternate, size: 50),
                                  SizedBox(height: 8),
                                  Text('Tap to add a photo'),
                                ],
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                            widget.existingComment != null
                                ? 'Update Review'
                                : 'Submit Review',
                            style: const TextStyle(fontSize: 16),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
