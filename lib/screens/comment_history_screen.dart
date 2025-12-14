import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../features/home_feature/presentation/screens/add_comment_screen.dart';
import 'car_detail_screen.dart';

class CommentHistoryScreen extends StatelessWidget {
  const CommentHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Reviews')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('comments')
                .where('userId', isEqualTo: userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text('You have not made any reviews yet.'),
            );
          }

          // Sort the documents by createdAt in memory
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // Descending order
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('cars')
                        .doc(data['carId'])
                        .get(),
                builder: (context, carSnapshot) {
                  if (!carSnapshot.hasData) {
                    return const Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.comment, size: 40),
                        title: Text('Loading...'),
                      ),
                    );
                  }

                  final carData =
                      carSnapshot.data?.data() as Map<String, dynamic>?;
                  final carImage = carData?['image'] as String?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            final carId = data['carId'];
                            if (carId != null && carId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          CarDetailScreen(carId: carId),
                                ),
                              );
                            }
                          },
                          child:
                              carImage != null && carImage.isNotEmpty
                                  ? carImage.startsWith('http')
                                      ? Image.network(
                                        carImage,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.error),
                                      )
                                      : Image.asset(
                                        carImage,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) =>
                                                const Icon(Icons.error),
                                      )
                                  : const Icon(Icons.comment, size: 40),
                        ),
                      ),
                      title: Text(data['carName'] ?? 'Unknown Car'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < (data['rating'] ?? 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(data['text'] ?? ''),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => AddCommentScreen(
                                        bookingId: data['bookingId'],
                                        carName: data['carName'],
                                        carId: data['carId'],
                                        existingComment: {
                                          ...data,
                                          'id': docs[index].id,
                                        },
                                      ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('comments')
                                  .doc(docs[index].id)
                                  .delete();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Comment deleted'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
