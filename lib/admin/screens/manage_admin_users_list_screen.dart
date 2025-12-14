import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/admin/screens/admin_user_detail_screen.dart';

class ManageAdminUsersListScreen extends StatelessWidget {
  const ManageAdminUsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: AppColors.secondary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final userData = user.data() as Map<String, dynamic>;

              final isAdmin = userData['isAdmin'] == true;
              final isBlocked = userData['isBlocked'] == true;

              return ListTile(
                title: Text(userData['email'] ?? 'No Email'),
                subtitle: Row(
                  children: [
                    Text(isAdmin ? 'Admin' : 'User'),
                    if (isBlocked) ...[
                      const SizedBox(width: 10),
                      const Chip(
                        label: Text(
                          'Blocked',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.id)
                        .delete();
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminUserDetailScreen(userId: user.id),
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
