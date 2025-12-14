import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageCommentsScreen extends StatelessWidget {
  const ManageCommentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Reviews')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('cars')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cars = snapshot.data!.docs;

          return ListView.builder(
            itemCount: cars.length,
            itemBuilder: (context, index) {
              final car = cars[index].data() as Map<String, dynamic>;
              final comments = List<Map<String, dynamic>>.from(
                car['comments'] ?? [],
              );

              if (comments.isEmpty) return const SizedBox.shrink();

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(car['name'] ?? 'Unknown Vehicle'),
                  subtitle: Text('${comments.length} reviews'),
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length,
                      itemBuilder: (context, commentIndex) {
                        final comment = comments[commentIndex];
                        return ListTile(
                          title: Row(
                            children: [
                              // Always show real name to admin
                              Text(comment['userName'] ?? 'Anonymous'),
                              if (!comment['showName'])
                                const Icon(
                                  Icons.visibility_off,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              const Spacer(),
                              Text(
                                DateTime.fromMillisecondsSinceEpoch(
                                  comment['timestamp'].millisecondsSinceEpoch,
                                ).toString().split('.')[0],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ...List.generate(
                                    5,
                                    (index) => Icon(
                                      index < (comment['rating'] ?? 0)
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'User ID: ${comment['userId']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(comment['text'] ?? ''),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed:
                                () => _deleteComment(
                                  context,
                                  cars[index].id,
                                  commentIndex,
                                  comments,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteComment(
    BuildContext context,
    String carId,
    int commentIndex,
    List<Map<String, dynamic>> comments,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Review'),
            content: const Text(
              'Are you sure you want to delete this review? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      comments.removeAt(commentIndex);

      // Recalculate average rating
      double averageRating = 0;
      if (comments.isNotEmpty) {
        final total = comments.fold<double>(
          0,
          (sum, comment) => sum + (comment['rating'] ?? 0),
        );
        averageRating = total / comments.length;
      }

      await FirebaseFirestore.instance.collection('cars').doc(carId).update({
        'comments': comments,
        'averageRating': averageRating,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting review: $e')));
    }
  }
}
