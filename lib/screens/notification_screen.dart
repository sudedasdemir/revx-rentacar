import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/colors.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (user == null) return;

    try {
      final notificationsSnapshot =
          await firestore
              .collection('notifications')
              .where('userId', isEqualTo: user!.uid)
              .orderBy('timestamp', descending: true)
              .get();

      setState(() {
        notifications =
            notificationsSnapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
      ),
      body:
          isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final title = notification['title'] ?? '';
                  final body = notification['body'] ?? '';
                  final timestamp =
                      (notification['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now();
                  final isRead = notification['isRead'] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[850] : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor:
                            isRead ? Colors.grey : AppColors.primary,
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            body,
                            style: TextStyle(
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${timestamp.toString().split('.')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode
                                      ? Colors.grey[500]
                                      : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (!isRead) {
                          await firestore
                              .collection('notifications')
                              .doc(notification['id'])
                              .update({'isRead': true});
                          _loadNotifications();
                        }
                      },
                    ),
                  );
                },
              ),
    );
  }
}
