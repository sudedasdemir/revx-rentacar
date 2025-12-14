import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_app/services/notification_service.dart';

class RentalDetailScreen extends StatefulWidget {
  final String bookingId;

  const RentalDetailScreen({Key? key, required this.bookingId})
    : super(key: key);

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  // Define valid status options as a constant
  static const List<String> statusOptions = [
    'pending',
    'ongoing',
    'completed',
    'cancelled',
  ];

  DocumentSnapshot? bookingData;
  DocumentSnapshot? userData;
  DocumentSnapshot? carData;

  String selectedStatus = "";

  @override
  void initState() {
    super.initState();
    fetchBookingDetails();
  }

  Future<void> fetchBookingDetails() async {
    try {
      // Validate booking ID
      if (widget.bookingId.isEmpty) {
        print('Error: Booking ID is empty');
        return;
      }

      final bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .get();

      if (!bookingDoc.exists) {
        print('Error: Booking not found');
        return;
      }

      // Safely get the booking data
      final bookingMap = bookingDoc.data() as Map<String, dynamic>? ?? {};

      // Validate required fields
      final userId = bookingMap['userId'] as String?;
      final carId = bookingMap['carId'] as String?;

      if (userId == null || userId.isEmpty || carId == null || carId.isEmpty) {
        print('Error: Invalid user ID or car ID');
        return;
      }

      // Fetch user and car data
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

      final carDoc =
          await FirebaseFirestore.instance
              .collection('cars')
              .doc(carId.trim())
              .get();

      if (!carDoc.exists) {
        print('Error: Car not found with ID: $carId');
        return;
      }

      if (mounted) {
        setState(() {
          bookingData = bookingDoc;
          userData = userDoc;
          carData = carDoc;
          // Ensure the status is one of the valid options
          selectedStatus =
              statusOptions.contains(bookingMap['status'])
                  ? bookingMap['status']
                  : statusOptions[0]; // Default to 'pending' if invalid
        });
      }
    } catch (e) {
      print('Error fetching booking details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error loading rental details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> updateBookingStatus() async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({'status': selectedStatus});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Booking status updated.")));

    Navigator.pop(context); // Güncellemeden sonra geri dön
  }

  Future<void> _cancelBookingWithRefund(BuildContext context) async {
    try {
      final bookingRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId);
      final bookingDoc = await bookingRef.get();

      if (!bookingDoc.exists) {
        print('Error: Booking not found for cancellation');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Booking not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = bookingDoc.data()!;
      final paymentId = data['paymentId'] as String?;
      final userId = data['userId'] as String?;
      final carId = data['carId'] as String?;
      final carName = data['carName'] as String?;
      final quantity = data['quantity'] as int? ?? 1;
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

      // Fetch user data for cancellation record
      DocumentSnapshot? userDoc;
      if (userId != null && userId.isNotEmpty) {
        userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
      }
      final userMap = userDoc?.data() as Map<String, dynamic>? ?? {};

      // Extract first and last name from userMap['name']
      final userName = userMap['name'] as String? ?? '';
      String firstName = '';
      String lastName = '';
      if (userName.isNotEmpty) {
        final nameParts = userName.split(' ');
        firstName = nameParts.first;
        if (nameParts.length > 1) {
          lastName = nameParts.sublist(1).join(' ');
        }
      }

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update booking status to 'cancelled'
      batch.update(bookingRef, {'status': 'cancelled'});

      // 2. Update associated payment status to 'refunded' (if paymentId exists)
      if (paymentId != null && paymentId.isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('payments').doc(paymentId),
          {
            'status': 'refunded',
            'cancellationDate': FieldValue.serverTimestamp(),
            'refundAmount': totalAmount, // 100% refund
            'originalAmount': totalAmount,
            'retainedAmount': 0.0, // 0 retained for 100% refund
          },
        );
      }

      // 3. Add the car back to available stock
      if (carId != null && carId.isNotEmpty) {
        final carRef = FirebaseFirestore.instance.collection('cars').doc(carId);
        final carDoc = await carRef.get();
        if (carDoc.exists) {
          final carData = carDoc.data()!;
          int currentStock = carData['availableStock'] as int? ?? 0;
          batch.update(carRef, {'availableStock': currentStock + quantity});
        }
      }

      // 4. Create a new cancellation entry in the 'cancellations' collection
      batch.set(FirebaseFirestore.instance.collection('cancellations').doc(), {
        'bookingId': widget.bookingId,
        'userId': userId,
        'requestDate': FieldValue.serverTimestamp(),
        'status':
            'approved', // Admin initiated 100% refund is an approved cancellation
        'reason': 'Admin initiated 100% refund',
        'totalAmount': totalAmount,
        'refundAmount': totalAmount, // 100% refund
        'retainedAmount': 0.0, // 0 retained
        'carName': carName,
        'firstName': firstName,
        'lastName': lastName,
        'email': userMap['email'] ?? '',
        'phone': userMap['phone'] ?? '',
        'description': 'Cancellation processed by admin with 100% refund.',
        'processedDate': FieldValue.serverTimestamp(),
        'paymentId': paymentId, // Include paymentId for traceability
      });

      // Commit the batch
      await batch.commit();

      // 5. Send notification to the user
      if (userId != null && carName != null) {
        await NotificationService().sendNotification(
          title: 'Rental Cancelled & Refunded',
          body:
              'Your rental for $carName has been cancelled and a 100% refund has been issued.',
          userId: userId,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Booking cancelled and refunded successfully."),
        ),
      );
      // Navigate to CancellationManagementScreen after successful cancellation
      Navigator.pushReplacementNamed(context, '/cancellation_management');
    } catch (e) {
      print('Error cancelling booking with refund: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bookingData == null || userData == null || carData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Safely get the data maps
    final bookingMap = bookingData!.data() as Map<String, dynamic>? ?? {};
    final userMap = userData!.data() as Map<String, dynamic>? ?? {};
    final carMap = carData!.data() as Map<String, dynamic>? ?? {};

    // Safely access dates with null checking
    final startDate =
        (bookingMap['startDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final endDate =
        (bookingMap['endDate'] as Timestamp?)?.toDate() ?? DateTime.now();

    // Safely access other fields with null checking
    final customerName = userMap['name'] ?? userMap['email'] ?? 'Unknown';
    final carName = carMap['name'] ?? 'Unknown';
    final carBrand = carMap['brand'] ?? '';
    final paymentId = bookingMap['paymentId'] as String?;

    return Scaffold(
      appBar: AppBar(title: const Text('Rental Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<DocumentSnapshot?>(
          future:
              paymentId != null && paymentId.isNotEmpty
                  ? FirebaseFirestore.instance
                      .collection('payments')
                      .doc(paymentId)
                      .get()
                  : null,
          builder: (context, paymentSnapshot) {
            double totalAmount = 0.0;
            double voucherAmount = 0.0;
            double finalAmount = 0.0;

            if (paymentSnapshot.hasData &&
                paymentSnapshot.data?.exists == true) {
              final paymentData =
                  paymentSnapshot.data!.data() as Map<String, dynamic>;
              totalAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
              voucherAmount =
                  (paymentData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
              finalAmount =
                  (paymentData['finalAmount'] as num?)?.toDouble() ??
                  totalAmount;
            } else {
              // Fallback to booking data if payment not found
              totalAmount =
                  (bookingMap['totalAmount'] as num?)?.toDouble() ?? 0.0;
              voucherAmount =
                  (bookingMap['voucherAmount'] as num?)?.toDouble() ?? 0.0;
              finalAmount =
                  (bookingMap['finalAmount'] as num?)?.toDouble() ??
                  totalAmount;
            }

            return ListView(
              children: [
                Text(
                  "Customer: $customerName",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  "Car: $carName ($carBrand)",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text("Start Date: ${DateFormat.yMMMd().format(startDate)}"),
                Text("End Date: ${DateFormat.yMMMd().format(endDate)}"),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Original Price:"),
                          Text(
                            PriceFormatter.formatPrice(totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (voucherAmount > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Voucher Applied:"),
                            Text(
                              PriceFormatter.formatPrice(voucherAmount),
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Final Amount Paid:"),
                          Text(
                            PriceFormatter.formatPrice(finalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items:
                      statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedStatus = value);
                    }
                  },
                  decoration: const InputDecoration(labelText: "Rental Status"),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      selectedStatus != bookingMap['status']
                          ? updateBookingStatus
                          : null,
                  child: const Text("Update Status"),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _cancelBookingWithRefund(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Cancellation by Admin (100% Refund)"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
