import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/admin/screens/cancellation_management_screen.dart';
import 'package:firebase_app/admin/screens/manage_cars_screen.dart';
import 'package:flutter/services.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Stream<QuerySnapshot> _cancellationsStream;
  late Stream<QuerySnapshot> _lowStockCarsStream;
  late Stream<QuerySnapshot> _newBookingsStream;

  @override
  void initState() {
    super.initState();
    _cancellationsStream =
        FirebaseFirestore.instance
            .collection('cancellations')
            .where('status', isEqualTo: 'pending')
            .snapshots();

    _lowStockCarsStream =
        FirebaseFirestore.instance
            .collection('cars')
            .where('stock', isLessThan: 5)
            .snapshots();
    _newBookingsStream =
        FirebaseFirestore.instance
            .collection('bookings')
            .where('status', whereIn: ['upcoming', 'ongoing'])
            .orderBy('startDate', descending: false)
            .snapshots();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _dismissBooking(DocumentSnapshot doc) async {
    final bookingId = doc.id;
    final bookingData =
        doc.data() as Map<String, dynamic>; // Store data for potential undo

    try {
      // Perform immediate deletion from Firestore
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking ID $bookingId deleted.'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                // Restore the booking if UNDO is pressed
                await FirebaseFirestore.instance
                    .collection('bookings')
                    .doc(bookingId)
                    .set(bookingData); // Use set() to restore data
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking restored!')),
                  );
                }
              },
            ),
            duration: const Duration(
              seconds: 5,
            ), // Show undo option for 5 seconds
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationSection(
              title: 'Ongoing & Upcoming Bookings',
              icon: Icons.car_rental,
              color: Colors.green,
              stream: _newBookingsStream,
              itemBuilder: (doc) {
                final data = doc.data() as Map<String, dynamic>;
                final carName = data['carName'] ?? 'Unknown Car';
                final startDate = (data['startDate'] as Timestamp?)?.toDate();
                final endDate = (data['endDate'] as Timestamp?)?.toDate();
                String userName = data['userName'] ?? 'Unknown User';
                final String? userId =
                    data['userId']; // Assuming 'userId' field exists in booking document
                final status = data['status'] ?? 'unknown';
                final isCorporate = data['isCorporate'] ?? false;
                final companyName = data['companyName'] ?? 'N/A';

                Widget buildBookingDetails(String currentUserName) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isCorporate
                                        ? 'Company: $companyName'
                                        : 'User: $currentUserName', // Use currentUserName here
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: doc.id),
                                      );
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Booking ID ${doc.id} copied!',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(
                                      'Booking ID: ${doc.id}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    status == 'ongoing'
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color:
                                      status == 'ongoing'
                                          ? Colors.green
                                          : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (startDate != null && endDate != null)
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                }

                if (userName == 'Unknown User' && userId != null) {
                  return FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .get(),
                    builder: (context, userSnapshot) {
                      String displayedUserName = 'Unknown User';
                      if (userSnapshot.connectionState ==
                              ConnectionState.done &&
                          userSnapshot.hasData) {
                        final userData =
                            userSnapshot.data!.data() as Map<String, dynamic>?;
                        if (userData != null && userData.containsKey('email')) {
                          displayedUserName =
                              userData['email'] ?? 'Unknown User';
                        }
                      }
                      return buildBookingDetails(displayedUserName);
                    },
                  );
                } else {
                  return buildBookingDetails(userName);
                }
              },
              onTap: (docId) {
                print('Tapped booking ID: $docId');
                Navigator.pushNamed(
                  context,
                  '/admin/rentals',
                  arguments: {'initialBookingId': docId},
                );
              },
              onDismiss: _dismissBooking,
              showCloseButton: true,
            ),
            const SizedBox(height: 24),
            _buildNotificationSection(
              title: 'New Cancellations',
              icon: Icons.cancel_outlined,
              color: Colors.orange,
              stream: _cancellationsStream,
              itemBuilder: (doc) => Text('Cancellation ID: ${doc.id}'),
            ),
            const SizedBox(height: 24),
            _buildNotificationSection(
              title: 'Low Stock Cars',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              stream: _lowStockCarsStream,
              itemBuilder: (doc) {
                final data = doc.data() as Map<String, dynamic>;
                final make = data['make'] as String?;
                final model = data['model'] as String?;

                if (make != null &&
                    model != null &&
                    make.isNotEmpty &&
                    model.isNotEmpty) {
                  return Text('Car: $make $model');
                } else {
                  return Text('Car ID: ${doc.id}');
                }
              },
              onTap: (docId) {
                print('Tapped low stock car ID: $docId');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageCarsScreen(initialCarId: docId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection({
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
    required Widget Function(DocumentSnapshot) itemBuilder,
    Future<void> Function(DocumentSnapshot)? onDismiss,
    void Function(String)? onTap,
    bool showCloseButton = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      const Text('No new items.'),
                    ],
                  ),
                ),
              );
            }

            final items = snapshot.data!.docs;
            return Column(
              children:
                  items.map((doc) {
                    return Dismissible(
                      key: Key(doc.id), // Unique key for Dismissible
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        // This is called when the Dismissible is fully dismissed by swiping
                        // or programmatically. We call our _dismissBooking logic here.
                        _dismissBooking(
                          doc,
                        ); // Pass the entire DocumentSnapshot
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        child: Stack(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: color,
                                child: Icon(icon, color: Colors.white),
                              ),
                              title: itemBuilder(doc),
                              onTap: () {
                                if (onTap != null) {
                                  onTap(doc.id);
                                } else if (title == 'New Cancellations') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => CancellationManagementScreen(
                                            initialCancellationId: doc.id,
                                          ),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (showCloseButton && onDismiss != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    // Programmatically dismiss the item when 'X' is pressed
                                    // This will trigger the onDismissed callback as well
                                    // Find the Dismissible widget using a GlobalKey if direct call is needed.
                                    // For now, this will simply call _dismissBooking directly.
                                    _dismissBooking(
                                      doc,
                                    ); // Call _dismissBooking with the document
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }
}
