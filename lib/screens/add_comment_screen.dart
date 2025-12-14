import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddCommentScreen extends StatefulWidget {
  final String vehicleId;

  const AddCommentScreen({required this.vehicleId, Key? key}) : super(key: key);

  @override
  State<AddCommentScreen> createState() => _AddCommentScreenState();
}

class _AddCommentScreenState extends State<AddCommentScreen> {
  final TextEditingController _commentController = TextEditingController();
  final double _rating = 5.0; // Fixed 5-star rating
  bool _isSubmitting = false;
  bool _showName = true;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please write a review')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Check if user has already reviewed this vehicle
      final carDoc =
          await FirebaseFirestore.instance
              .collection('cars')
              .doc(widget.vehicleId)
              .get();

      final comments = List<Map<String, dynamic>>.from(
        carDoc.data()?['comments'] ?? [],
      );

      final hasExistingComment = comments.any(
        (comment) => comment['userId'] == user.uid,
      );

      if (hasExistingComment) {
        throw Exception('You have already reviewed this vehicle');
      }

      // Add the new comment
      comments.add({
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous',
        'showName': _showName,
        'text': _commentController.text.trim(),
        'rating': _rating,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Calculate new average rating
      final total = comments.fold<double>(
        0,
        (sum, comment) => sum + (comment['rating'] ?? 0),
      );
      final averageRating = total / comments.length;

      await FirebaseFirestore.instance
          .collection('cars')
          .doc(widget.vehicleId)
          .update({'comments': comments, 'averageRating': averageRating});

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write a Review')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rating',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(
                5,
                (index) =>
                    const Icon(Icons.star, color: Colors.amber, size: 40),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Write your review',
                hintText: 'Share your experience with this vehicle',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Show my name with review'),
              subtitle: Text(
                _showName
                    ? 'Your name will be visible to others'
                    : 'Your review will be anonymous',
              ),
              value: _showName,
              onChanged: (value) => setState(() => _showName = value),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                child:
                    _isSubmitting
                        ? const CircularProgressIndicator()
                        : const Text('Submit Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
