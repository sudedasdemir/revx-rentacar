import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';

class EBulletinPage extends StatefulWidget {
  const EBulletinPage({super.key});

  @override
  _EBulletinPageState createState() => _EBulletinPageState();
}

class _EBulletinPageState extends State<EBulletinPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailValid = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("E-Bulletin"),
        backgroundColor: AppColors.secondary, // AppBar color
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Page Header
            const Text(
              'Stay Updated with Our Latest Offers and News!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Subscribe to our newsletter to receive the latest updates.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Latest News Section with a card style
            const Text(
              'Latest News & Offers',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('e_bulletin')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No bulletins available at the moment.'),
                  );
                }

                return Column(
                  children:
                      snapshot.data!.docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _newsItem(
                          title: data['title'] ?? '',
                          content: data['content'] ?? '',
                          date: data['date'] ?? '',
                        );
                      }).toList(),
                );
              },
            ),

            // Subscription Section with better styling and validation
            const SizedBox(height: 24),
            const Text(
              'Subscribe to Our Newsletter',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get the latest updates directly in your inbox.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            _subscriptionForm(),
          ],
        ),
      ),
    );
  }

  // Widget for displaying individual news
  Widget _newsItem({
    required String title,
    required String content,
    required String date,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // News Title
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // News Content
            Text(content, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            // News Date
            Text(
              'Date: $date',
              style: const TextStyle(fontSize: 14, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }

  // Subscription form widget with email validation
  Widget _subscriptionForm() {
    return Column(
      children: [
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Enter Your Email',
            border: OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.secondary,
              ), // Blue border when focused
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey,
              ), // Grey border when not focused
            ),
            errorText:
                _isEmailValid ? null : 'Please enter a valid email address',
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            // Validate the email and show feedback
            String email = _emailController.text;
            setState(() {
              _isEmailValid = RegExp(
                r'^[^@]+@[^@]+\.[^@]+',
              ).hasMatch(email); // Email regex validation
            });

            if (_isEmailValid) {
              // Show success Snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You have successfully subscribed!'),
                ),
              );
            } else {
              // Show error Snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a valid email address.'),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.secondary, // Text color
          ),
          child: const Text('Subscribe Now'),
        ),
      ],
    );
  }
}
