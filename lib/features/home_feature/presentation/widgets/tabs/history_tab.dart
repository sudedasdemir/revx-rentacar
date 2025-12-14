import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/add_comment_screen.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:firebase_app/screens/payment_screen.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_app/services/notification_service.dart';

class HistoryTab extends StatefulWidget {
  final bool scrollToFavorites;
  final String? scrollToFavoriteCarId;
  const HistoryTab({
    super.key,
    this.scrollToFavorites = false,
    this.scrollToFavoriteCarId,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final Map<String, GlobalKey> _favoriteCarKeys = {};
  late ScaffoldMessengerState scaffoldMessenger;
  Map<String, dynamic>? _lastRemovedFavorite;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scaffoldMessenger = ScaffoldMessenger.of(context);
    if (widget.scrollToFavoriteCarId != null &&
        _favoriteCarKeys[widget.scrollToFavoriteCarId!] != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final key = _favoriteCarKeys[widget.scrollToFavoriteCarId!];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  // Update the favorite removal method
  Future<void> _removeFavorite(
    String favoriteDocId,
    BuildContext context,
  ) async {
    try {
      // Store the favorite data before removing
      final favoriteDoc =
          await FirebaseFirestore.instance
              .collection('favorites')
              .doc(favoriteDocId)
              .get();

      _lastRemovedFavorite = {
        'docId': favoriteDocId,
        'data': favoriteDoc.data(),
      };

      await FirebaseFirestore.instance
          .collection('favorites')
          .doc(favoriteDocId)
          .delete();

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Removed from favorites'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _restoreFavorite(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error removing favorite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this new method to restore the favorite
  Future<void> _restoreFavorite() async {
    if (_lastRemovedFavorite != null) {
      try {
        await FirebaseFirestore.instance
            .collection('favorites')
            .doc(_lastRemovedFavorite!['docId'])
            .set(_lastRemovedFavorite!['data']);

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Restored to favorites'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error restoring favorite: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      _lastRemovedFavorite = null;
    }
  }

  Future<void> _updateStatus(String cancellationId, String newStatus) async {
    try {
      // Start a batch write
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Get the cancellation document
      DocumentSnapshot cancellationDoc =
          await FirebaseFirestore.instance
              .collection('cancellations')
              .doc(cancellationId)
              .get();

      Map<String, dynamic> cancellationData =
          cancellationDoc.data() as Map<String, dynamic>;
      String bookingId = cancellationData['bookingId'] as String;
      String userId = cancellationData['userId'] as String;

      // Get the booking document to get payment information
      DocumentSnapshot bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

      Map<String, dynamic> bookingData =
          bookingDoc.data() as Map<String, dynamic>;

      if (newStatus == 'approved') {
        // Update booking status
        batch.update(
          FirebaseFirestore.instance.collection('bookings').doc(bookingId),
          {
            'status': 'cancelled',
            'cancellationDate': FieldValue.serverTimestamp(),
          },
        );

        // Find and update the corresponding payment document
        QuerySnapshot paymentQuery =
            await FirebaseFirestore.instance
                .collection('payments')
                .where('bookingId', isEqualTo: bookingId)
                .limit(1)
                .get();

        if (paymentQuery.docs.isNotEmpty) {
          batch.update(
            FirebaseFirestore.instance
                .collection('payments')
                .doc(paymentQuery.docs.first.id),
            {
              'status': 'cancelled',
              'cancellationDate': FieldValue.serverTimestamp(),
              'refundAmount': (bookingData['totalAmount'] as num) * 0.8,
            },
          );
        }
      }

      // Update cancellation status
      batch.update(
        FirebaseFirestore.instance
            .collection('cancellations')
            .doc(cancellationId),
        {'status': newStatus, 'processedDate': FieldValue.serverTimestamp()},
      );

      // Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'approved'
                  ? 'Cancellation approved. 20% of the booking amount will be retained as cancellation fee.'
                  : 'Cancellation request rejected',
            ),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add this method to check and update booking status
  Future<void> _checkAndUpdateBookingStatus(
    String bookingId,
    DateTime endDate,
  ) async {
    final now = DateTime.now();
    final bookingRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) return;

      final data = bookingDoc.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? 'pending';

      if (status == 'active' && now.isAfter(endDate)) {
        // Update status to completed
        await bookingRef.update({'status': 'completed'});

        // Send notification for completed booking
        await NotificationService().sendNotification(
          title: 'Rental Completed',
          body:
              'Your rental for ${data['carName']} has been completed. Thank you for choosing our service!',
          userId: user.uid,
        );
      } else if (status == 'upcoming' &&
          now.isAfter(data['startDate'].toDate())) {
        // Update status to active
        await bookingRef.update({'status': 'active'});

        // Send notification for active booking
        await NotificationService().sendNotification(
          title: 'Rental Started',
          body:
              'Your rental for ${data['carName']} has started. Enjoy your ride!',
          userId: user.uid,
        );
      }
    } catch (e) {
      print('Error updating booking status: $e');
    }
  }

  // Add notification for cancelled bookings
  Future<void> _handleBookingCancellation(
    String bookingId,
    String carName,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await NotificationService().sendNotification(
        title: 'Booking Cancelled',
        body: 'Your booking for $carName has been cancelled.',
        userId: user.uid,
      );
    } catch (e) {
      print('Error sending cancellation notification: $e');
    }
  }

  // Add notification for payment completion
  Future<void> _handlePaymentCompletion(String carName, double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await NotificationService().sendNotification(
        title: 'Payment Completed',
        body:
            'Your payment of ${PriceFormatter.formatPrice(amount)} for $carName has been completed successfully.',
        userId: user.uid,
      );
    } catch (e) {
      print('Error sending payment notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text("User not logged in."));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("Active Bookings"),
              _buildOngoingBookings(userId),
              _sectionTitle("Future Reservations"),
              _buildFutureReservations(userId),
              _sectionTitle("Completed Reservation"),
              _buildCompletedReservations(userId),
              _sectionTitle("Pending Payments"),
              _buildPendingPayments(userId),
              _sectionTitle("Cancelled Payments"),
              _buildPayments(userId, statusFilter: "cancelled"),
              _sectionTitle("Favorites"),
              KeyedSubtree(
                key: _favoriteCarKeys[widget.scrollToFavoriteCarId],
                child: _buildFavorites(userId),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Add this helper method to get price widget based on booking status
  Widget _buildBookingPriceWidget(
    dynamic amount,
    String status, {
    String? paymentId,
    String? carId,
    String? carName,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? data,
  }) {
    final double amountValue = (amount is num) ? amount.toDouble() : 0.0;
    // Get the final amount and voucher amount from the data
    final finalAmountValue = (data?['finalAmount'] as num?)?.toDouble();
    final voucherAmountValue = (data?['voucherAmount'] as num?)?.toDouble();

    if (status == 'cancelled') {
      final retainedAmount = amountValue * 0.2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${PriceFormatter.formatPrice(amountValue)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Text(
            "${PriceFormatter.formatPrice(amountValue * 0.8)} Refund",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cancellation Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          _buildRefundDetailRow('Original Amount', amountValue, Colors.grey),
          const SizedBox(height: 8),
          _buildRefundDetailRow(
            'Retained Amount (20%)',
            retainedAmount,
            Colors.red,
          ),
          const SizedBox(height: 8),
          _buildRefundDetailRow(
            'Refund Amount (80%)',
            amountValue * 0.8,
            Colors.green,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '20% of the total amount is retained as a cancellation fee according to our policy.',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (status == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'PENDING',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  if (paymentId == null ||
                      carId == null ||
                      carName == null ||
                      startDate == null ||
                      endDate == null ||
                      data == null) {
                    return;
                  }

                  // Fetch the payment document
                  final paymentDoc =
                      await FirebaseFirestore.instance
                          .collection('payments')
                          .doc(paymentId)
                          .get();
                  if (!paymentDoc.exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment record not found!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // Query for the booking with paymentId == paymentId
                  final bookingQuery =
                      await FirebaseFirestore.instance
                          .collection('bookings')
                          .where('paymentId', isEqualTo: paymentId)
                          .limit(1)
                          .get();
                  if (bookingQuery.docs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Related booking not found!'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  final bookingDoc = bookingQuery.docs.first;
                  final bookingData = bookingDoc.data() as Map<String, dynamic>;

                  // Use carImage from booking, payment, or fetch from cars collection if missing
                  String imageToUse =
                      bookingData['carImage'] ?? paymentDoc['carImage'] ?? '';
                  if (imageToUse.isEmpty) {
                    final carDoc =
                        await FirebaseFirestore.instance
                            .collection('cars')
                            .doc(carId)
                            .get();
                    if (carDoc.exists) {
                      final carData = carDoc.data();
                      if (carData != null && carData['image'] != null) {
                        imageToUse = carData['image'];
                      }
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PaymentScreen(
                            carName: carName,
                            carId: carId,
                            startDate: startDate,
                            endDate: endDate,
                            totalPrice: amountValue,
                            insurance: data['insurance'] ?? false,
                            childSeat: data['childSeat'] ?? false,
                            carImage: imageToUse,
                            pickupLocation:
                                data['pickupLocation'] ?? 'Not specified',
                            returnLocation:
                                data['returnLocation'] ?? 'Not specified',
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${PriceFormatter.formatPrice(amountValue)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.orange,
            ),
          ),
        ],
      );
    }

    // Get the car data to check for discounts
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('cars').doc(carId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final carData = snapshot.data!.data() as Map<String, dynamic>?;
          final discountPercentage =
              (carData?['discountPercentage'] as num?)?.toDouble();
          final discountedPrice =
              (carData?['discountedPrice'] as num?)?.toDouble();

          // If there's both a car discount and a voucher
          if (discountPercentage != null &&
              discountedPrice != null &&
              finalAmountValue != null &&
              voucherAmountValue != null &&
              voucherAmountValue > 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${PriceFormatter.formatPrice(amountValue)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  "${PriceFormatter.formatPrice(discountedPrice)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "${discountPercentage.toStringAsFixed(0)}% OFF",
                  style: const TextStyle(
                    fontSize: 6,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Voucher: -${PriceFormatter.formatPrice(voucherAmountValue)}",
                  style: const TextStyle(
                    fontSize: 6,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${PriceFormatter.formatPrice(finalAmountValue)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    color: Colors.green,
                  ),
                ),
              ],
            );
          }
          // If there's only a car discount
          else if (discountPercentage != null && discountedPrice != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${PriceFormatter.formatPrice(amountValue)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  "${PriceFormatter.formatPrice(discountedPrice)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  "${discountPercentage.toStringAsFixed(0)}% OFF",
                  style: const TextStyle(
                    fontSize: 6,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }
          // If there's only a voucher
          else if (finalAmountValue != null &&
              voucherAmountValue != null &&
              voucherAmountValue > 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "${PriceFormatter.formatPrice(amountValue)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                Text(
                  "${PriceFormatter.formatPrice(finalAmountValue)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 6,
                    color: Colors.green,
                  ),
                ),
                Text(
                  "Voucher: -${PriceFormatter.formatPrice(voucherAmountValue)}",
                  style: const TextStyle(
                    fontSize: 6,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          }
        }

        // If no discounts, show original price
        return Text(
          "${PriceFormatter.formatPrice(amountValue)}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            color: status == 'cancelled' ? Colors.red : Colors.green,
          ),
        );
      },
    );
  }

  // Update the _buildPaymentDisplay method
  Widget _buildPaymentDisplay(double amount, String status) {
    if (status == 'cancelled') {
      final refundAmount = amount * 0.8;
      final retainedAmount = amount * 0.2;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${PriceFormatter.formatPrice(amount)}",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              decoration: TextDecoration.lineThrough,
              color: Colors.red,
            ),
          ),
          Text(
            "${PriceFormatter.formatPrice(refundAmount)} Refunded",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          Text(
            "${PriceFormatter.formatPrice(retainedAmount)} Retained",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Get the discounted price if available
    final discountedPrice = amount * 0.8; // Assuming 20% discount

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          "${PriceFormatter.formatPrice(discountedPrice)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.green,
          ),
        ),
        Text(
          "${PriceFormatter.formatPrice(amount)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }

  // Only show bookings with status 'ongoing'
  Widget _buildOngoingBookings(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'ongoing')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No active bookings')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final start = (data['startDate'] as Timestamp).toDate();
            final end = (data['endDate'] as Timestamp).toDate();
            final totalAmount =
                (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final carName = data['carName'] as String? ?? 'Unknown Car';
            final carImage = data['carImage'] as String? ?? '';
            final status = data['status'] as String? ?? 'pending';

            // Check and update booking status if needed
            if (status != 'completed' && status != 'cancelled') {
              _checkAndUpdateBookingStatus(doc.id, end);
            }

            return GestureDetector(
              onTap: () {
                // Only open car detail if carId is available
                final carId = data['carId'] as String?;
                if (status == 'pending') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PaymentScreen(
                            carName: data['carName'] ?? 'Unknown Car',
                            carId: data['carId'] ?? '',
                            startDate: start,
                            endDate: end,
                            totalPrice: totalAmount,
                            insurance: data['insurance'] ?? false,
                            childSeat: data['childSeat'] ?? false,
                            carImage: data['carImage'] ?? '',
                            pickupLocation:
                                data['pickupLocation'] ?? 'Not specified',
                            returnLocation:
                                data['returnLocation'] ?? 'Not specified',
                          ),
                    ),
                  );
                } else if (carId != null && carId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CarDetailScreen(carId: carId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Car details not found!')),
                  );
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.green.shade200, width: 1),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            final carId = data['carId'] as String?;
                            if (carId != null && carId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          CarDetailScreen(carId: carId),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Car details not found!'),
                                ),
                              );
                            }
                          },
                          child:
                              carImage.startsWith('http') && carImage.isNotEmpty
                                  ? Image.network(
                                    carImage,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Error loading image: $error');
                                      return const Icon(
                                        Icons.image_not_supported,
                                      );
                                    },
                                  )
                                  : carImage.isNotEmpty
                                  ? Image.asset(
                                    carImage,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                  )
                                  : const Icon(
                                    Icons.image_not_supported,
                                    size: 60,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  carName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (data['isCorporate'] == true &&
                                    data['quantity'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(x${data['quantity']} vehicles)',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (data['isCorporate'] == true &&
                                data['quantity'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${data['quantity']} vehicles',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Always show the date range
                            Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "${_formatDateCompact(start)} → ${_formatDateCompact(end)}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (data['isCorporate'] == true) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Pickup: ${data['pickupLocation'] ?? 'Not specified'}",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Return: ${data['returnLocation'] ?? 'Not specified'}",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: _buildBookingPriceWidget(
                    totalAmount,
                    status,
                    paymentId: doc.id,
                    carId: data['carId'],
                    carName: carName,
                    startDate: start,
                    endDate: end,
                    data: data,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                "Booking ID:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  docs[index].id,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status == 'cancelled') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "This booking has been cancelled. 20% of the total amount has been retained as a cancellation fee.",
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Add Comment Section
                          if (status == 'completed') ...[
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('comments')
                                      .where('bookingId', isEqualTo: doc.id)
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final comments = snapshot.data!.docs;
                                if (comments.isEmpty) {
                                  return ElevatedButton.icon(
                                    onPressed:
                                        () => _navigateToAddComment(
                                          context,
                                          doc.id,
                                          carName,
                                        ),
                                    icon: const Icon(Icons.add_comment),
                                    label: const Text('Add Review'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  );
                                }

                                final comment =
                                    comments.first.data()
                                        as Map<String, dynamic>;
                                final userId =
                                    FirebaseAuth.instance.currentUser?.uid;
                                final isUserComment =
                                    comment['userId'] == userId;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(5, (index) {
                                          return Icon(
                                            index <
                                                    (comment['rating'] as num)
                                                        .toInt()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            comment['text'] as String,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (isUserComment) ...[
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => _navigateToAddComment(
                                                  context,
                                                  doc.id,
                                                  carName,
                                                  existingComment: {
                                                    ...comment,
                                                    'id': comments.first.id,
                                                  },
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => _deleteComment(
                                                  comments.first.id,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (comment['imageUrl'] != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          comment['imageUrl'] as String,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.error),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add new method for future reservations
  Widget _buildFutureReservations(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'upcoming')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final now = DateTime.now();
        final docs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final start = (data['startDate'] as Timestamp).toDate();
              // Only show future bookings
              return start.isAfter(now);
            }).toList();

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No future reservations')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final start = (data['startDate'] as Timestamp).toDate();
            final end = (data['endDate'] as Timestamp).toDate();
            final totalAmount =
                (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final carName = data['carName'] as String? ?? 'Unknown Car';
            final carImage = data['carImage'] as String? ?? '';
            final status = data['status'] as String? ?? 'ongoing';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade200, width: 1),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () {
                          final carId = data['carId'] as String?;
                          if (carId != null && carId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CarDetailScreen(carId: carId),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Car details not found!'),
                              ),
                            );
                          }
                        },
                        child:
                            carImage.startsWith('http') && carImage.isNotEmpty
                                ? Image.network(
                                  carImage,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image: $error');
                                    return const Icon(
                                      Icons.image_not_supported,
                                    );
                                  },
                                )
                                : carImage.isNotEmpty
                                ? Image.asset(
                                  carImage,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) =>
                                          const Icon(Icons.image_not_supported),
                                )
                                : const Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                carName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              if (data['isCorporate'] == true &&
                                  data['quantity'] != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(x${data['quantity']} vehicles)',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.date_range,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "${_formatDateCompact(start)} → ${_formatDateCompact(end)}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (data['isCorporate'] == true) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "Pickup: ${data['pickupLocation'] ?? 'Not specified'}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "Return: ${data['returnLocation'] ?? 'Not specified'}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: _buildBookingPriceWidget(
                  totalAmount,
                  status,
                  paymentId: doc.id,
                  carId: data['carId'],
                  carName: carName,
                  startDate: start,
                  endDate: end,
                  data: data,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              "Booking ID:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                docs[index].id,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (status == 'cancelled') ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "This booking has been cancelled. 20% of the total amount has been retained as a cancellation fee.",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Add Comment Section
                        if (status == 'completed') ...[
                          StreamBuilder<QuerySnapshot>(
                            stream:
                                FirebaseFirestore.instance
                                    .collection('comments')
                                    .where('bookingId', isEqualTo: doc.id)
                                    .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final comments = snapshot.data!.docs;
                              if (comments.isEmpty) {
                                return ElevatedButton.icon(
                                  onPressed:
                                      () => _navigateToAddComment(
                                        context,
                                        doc.id,
                                        carName,
                                      ),
                                  icon: const Icon(Icons.add_comment),
                                  label: const Text('Add Review'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                );
                              }

                              final comment =
                                  comments.first.data() as Map<String, dynamic>;
                              final userId =
                                  FirebaseAuth.instance.currentUser?.uid;
                              final isUserComment = comment['userId'] == userId;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        return Icon(
                                          index <
                                                  (comment['rating'] as num)
                                                      .toInt()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 20,
                                        );
                                      }),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          comment['text'] as String,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      if (isUserComment) ...[
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                          onPressed:
                                              () => _navigateToAddComment(
                                                context,
                                                doc.id,
                                                carName,
                                                existingComment: {
                                                  ...comment,
                                                  'id': comments.first.id,
                                                },
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                          ),
                                          onPressed:
                                              () => _deleteComment(
                                                comments.first.id,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (comment['imageUrl'] != null) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        comment['imageUrl'] as String,
                                        height: 100,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.error),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Only show bookings with status 'completed' and endDate before today
  Widget _buildCompletedReservations(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: 'completed')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: \\${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final end = (data['endDate'] as Timestamp).toDate();
              return end.isBefore(DateTime.now());
            }).toList();
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No completed reservations yet')),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final start = (data['startDate'] as Timestamp).toDate();
            final end = (data['endDate'] as Timestamp).toDate();
            final totalAmount =
                (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
            final carName = data['carName'] as String? ?? 'Unknown Car';
            final carImage = data['carImage'] as String? ?? '';
            final status = data['status'] as String? ?? 'pending';

            // Check and update booking status if needed
            if (status != 'completed' && status != 'cancelled') {
              _checkAndUpdateBookingStatus(doc.id, end);
            }

            return GestureDetector(
              onTap: () {
                // Only open car detail if carId is available
                final carId = data['carId'] as String?;
                if (status == 'pending') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => PaymentScreen(
                            carName: data['carName'] ?? 'Unknown Car',
                            carId: data['carId'] ?? '',
                            startDate: start,
                            endDate: end,
                            totalPrice: totalAmount,
                            insurance: data['insurance'] ?? false,
                            childSeat: data['childSeat'] ?? false,
                            carImage: data['carImage'] ?? '',
                            pickupLocation:
                                data['pickupLocation'] ?? 'Not specified',
                            returnLocation:
                                data['returnLocation'] ?? 'Not specified',
                          ),
                    ),
                  );
                } else if (carId != null && carId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CarDetailScreen(carId: carId),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Car details not found!')),
                  );
                }
              },
              child: Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade200, width: 1),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GestureDetector(
                          onTap: () {
                            final carId = data['carId'] as String?;
                            if (carId != null && carId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          CarDetailScreen(carId: carId),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Car details not found!'),
                                ),
                              );
                            }
                          },
                          child:
                              carImage.startsWith('http') && carImage.isNotEmpty
                                  ? Image.network(
                                    carImage,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Error loading image: $error');
                                      return const Icon(
                                        Icons.image_not_supported,
                                      );
                                    },
                                  )
                                  : carImage.isNotEmpty
                                  ? Image.asset(
                                    carImage,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(
                                          Icons.image_not_supported,
                                        ),
                                  )
                                  : const Icon(
                                    Icons.image_not_supported,
                                    size: 60,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  carName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                if (data['isCorporate'] == true &&
                                    data['quantity'] != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(x${data['quantity']} vehicles)',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (data['isCorporate'] == true &&
                                data['quantity'] != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${data['quantity']} vehicles',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.amber.shade900,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Always show the date range
                            Row(
                              children: [
                                Icon(
                                  Icons.date_range,
                                  size: 14,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    "${_formatDateCompact(start)} → ${_formatDateCompact(end)}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (data['isCorporate'] == true) ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Pickup: ${data['pickupLocation'] ?? 'Not specified'}",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      "Return: ${data['returnLocation'] ?? 'Not specified'}",
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  trailing: _buildBookingPriceWidget(
                    totalAmount,
                    status,
                    paymentId: doc.id,
                    carId: data['carId'],
                    carName: carName,
                    startDate: start,
                    endDate: end,
                    data: data,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16),
                              const SizedBox(width: 8),
                              const Text(
                                "Booking ID:",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  docs[index].id,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (status == 'cancelled') ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "This booking has been cancelled. 20% of the total amount has been retained as a cancellation fee.",
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Add Comment Section
                          if (status == 'completed') ...[
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('comments')
                                      .where('bookingId', isEqualTo: doc.id)
                                      .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final comments = snapshot.data!.docs;
                                if (comments.isEmpty) {
                                  return ElevatedButton.icon(
                                    onPressed:
                                        () => _navigateToAddComment(
                                          context,
                                          doc.id,
                                          carName,
                                        ),
                                    icon: const Icon(Icons.add_comment),
                                    label: const Text('Add Review'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  );
                                }

                                final comment =
                                    comments.first.data()
                                        as Map<String, dynamic>;
                                final userId =
                                    FirebaseAuth.instance.currentUser?.uid;
                                final isUserComment =
                                    comment['userId'] == userId;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        ...List.generate(5, (index) {
                                          return Icon(
                                            index <
                                                    (comment['rating'] as num)
                                                        .toInt()
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 20,
                                          );
                                        }),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            comment['text'] as String,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (isUserComment) ...[
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => _navigateToAddComment(
                                                  context,
                                                  doc.id,
                                                  carName,
                                                  existingComment: {
                                                    ...comment,
                                                    'id': comments.first.id,
                                                  },
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                            ),
                                            onPressed:
                                                () => _deleteComment(
                                                  comments.first.id,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (comment['imageUrl'] != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          comment['imageUrl'] as String,
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.error),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Only show payments with status 'pending' and show Pay Now button
  Widget _buildPendingPayments(String userId) {
    var query = FirebaseFirestore.instance
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending');
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "No pending payments found.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final carName = data['carName'] ?? 'Unknown Car';
            final carImage = data['carImage'] ?? '';
            final carId = data['carId'] ?? '';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final timestamp = data['timestamp']?.toDate();
            final startDate = data['startDate']?.toDate();
            final endDate = data['endDate']?.toDate();
            final status = data['status'] ?? 'unknown';
            final bookingId = data['bookingId'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _getStatusColor(status).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SizedBox(
                  width: 50,
                  height: 50,
                  child: GestureDetector(
                    onTap: () {
                      if (carId != null && carId.toString().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarDetailScreen(carId: carId),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Car details not found!'),
                          ),
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          carImage.toString().startsWith('http') &&
                                  carImage.toString().isNotEmpty
                              ? Image.network(
                                carImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading image: $error');
                                  return const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                  );
                                },
                              )
                              : carImage.toString().isNotEmpty
                              ? Image.asset(
                                carImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                              )
                              : const Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                ),
                title: Text(
                  carName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            (timestamp != null &&
                                    startDate != null &&
                                    endDate != null)
                                ? "Paid on " +
                                    _formatDateCompact(startDate) +
                                    " → " +
                                    _formatDateCompact(endDate)
                                : "Date not available",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (status == 'cancelled') ...[
                        Text(
                          "${PriceFormatter.formatPrice(amount)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.red,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${PriceFormatter.formatPrice(amount * 0.8)} Refund",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.green,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${PriceFormatter.formatPrice(amount * 0.2)} Retained",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('cars')
                                  .doc(carId)
                                  .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final carData =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final discountPercentage =
                                  (carData?['discountPercentage'] as num?)
                                      ?.toDouble();
                              final discountedPrice =
                                  (carData?['discountedPrice'] as num?)
                                      ?.toDouble();

                              if (discountPercentage != null &&
                                  discountedPrice != null) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${PriceFormatter.formatPrice(amount)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${PriceFormatter.formatPrice(discountedPrice)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${discountPercentage.toStringAsFixed(0)}% OFF",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );
                              }
                            }
                            return Text(
                              "${PriceFormatter.formatPrice(amount)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 20,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (carId == null ||
                                  carName == null ||
                                  startDate == null ||
                                  endDate == null) {
                                return;
                              }

                              final carDoc =
                                  await FirebaseFirestore.instance
                                      .collection('cars')
                                      .doc(carId)
                                      .get();
                              if (!carDoc.exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Car details not found!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final carData =
                                  carDoc.data() as Map<String, dynamic>;
                              final currentPrice =
                                  carData['discountedPrice'] ?? amount;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PaymentScreen(
                                        carName: carName,
                                        carId: carId,
                                        startDate: startDate,
                                        endDate: endDate,
                                        totalPrice: currentPrice,
                                        insurance: data['insurance'] ?? false,
                                        childSeat: data['childSeat'] ?? false,
                                        carImage: carImage,
                                        pickupLocation:
                                            data['pickupLocation'] ??
                                            'Not specified',
                                        returnLocation:
                                            data['returnLocation'] ??
                                            'Not specified',
                                      ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(0, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Booking ID:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bookingId?.toString() ?? '-',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRefundDetailRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        Text(
          PriceFormatter.formatPrice(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.payment;
    }
  }

  String _formatDateCompact(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString().substring(2)}";
  }

  // Add this method to delete comments
  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('comments')
          .doc(commentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting comment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Restore _navigateToAddComment
  void _navigateToAddComment(
    BuildContext context,
    String bookingId,
    String carName, {
    Map<String, dynamic>? existingComment,
  }) {
    // Get the carId from the booking data
    FirebaseFirestore.instance.collection('bookings').doc(bookingId).get().then(
      (bookingDoc) {
        if (bookingDoc.exists) {
          final bookingData = bookingDoc.data() as Map<String, dynamic>;
          final carId = bookingData['carId'] as String?;

          if (carId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => AddCommentScreen(
                      bookingId: bookingId,
                      carName: carName,
                      carId: carId,
                      existingComment: existingComment,
                    ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Car ID not found in booking data')),
            );
          }
        }
      },
    );
  }

  Widget _buildPayments(String userId, {String? statusFilter}) {
    var query = FirebaseFirestore.instance
        .collection('payments')
        .where('userId', isEqualTo: userId);
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter);
    }
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                "No payments found.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final carName = data['carName'] ?? 'Unknown Car';
            final carImage = data['carImage'] ?? '';
            final carId = data['carId'] ?? '';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final timestamp = data['timestamp']?.toDate();
            final startDate = data['startDate']?.toDate();
            final endDate = data['endDate']?.toDate();
            final status = data['status'] ?? 'unknown';
            final isCancelled = status == 'cancelled';
            final bookingId = data['bookingId'];
            final refundAmount = (data['refundAmount'] as num?)?.toDouble();
            final retainedAmount = (data['retainedAmount'] as num?)?.toDouble();

            // Calculate refund amounts if not provided
            final finalRefundAmount = refundAmount ?? (amount * 0.8);
            final finalRetainedAmount = retainedAmount ?? (amount * 0.2);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      isCancelled
                          ? Colors.red.withOpacity(0.3)
                          : _getStatusColor(status).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: SizedBox(
                  width: 60,
                  height: 60,
                  child: GestureDetector(
                    onTap: () {
                      if (carId != null && carId.toString().isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarDetailScreen(carId: carId),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Car details not found!'),
                          ),
                        );
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          carImage.toString().startsWith('http') &&
                                  carImage.toString().isNotEmpty
                              ? Image.network(
                                carImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                loadingBuilder: (
                                  context,
                                  child,
                                  loadingProgress,
                                ) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error loading image: $error');
                                  return const Icon(
                                    Icons.image_not_supported,
                                    size: 50,
                                  );
                                },
                              )
                              : carImage.toString().isNotEmpty
                              ? Image.asset(
                                carImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                    ),
                              )
                              : const Icon(Icons.image_not_supported, size: 50),
                    ),
                  ),
                ),
                title: Text(
                  carName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCancelled
                                ? Colors.red.withOpacity(0.1)
                                : _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isCancelled ? 'CANCELLED' : status.toUpperCase(),
                        style: TextStyle(
                          color:
                              isCancelled
                                  ? Colors.red
                                  : _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            (timestamp != null &&
                                    startDate != null &&
                                    endDate != null)
                                ? "Paid on " +
                                    _formatDateCompact(startDate) +
                                    " → " +
                                    _formatDateCompact(endDate)
                                : "Date not available",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isCancelled) ...[
                        Text(
                          "${PriceFormatter.formatPrice(amount)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.red,
                            decoration: TextDecoration.lineThrough,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${PriceFormatter.formatPrice(finalRefundAmount)} Refund",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.green,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${PriceFormatter.formatPrice(finalRetainedAmount)} Retained",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        FutureBuilder<DocumentSnapshot>(
                          future:
                              FirebaseFirestore.instance
                                  .collection('cars')
                                  .doc(carId)
                                  .get(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final carData =
                                  snapshot.data!.data()
                                      as Map<String, dynamic>?;
                              final discountPercentage =
                                  (carData?['discountPercentage'] as num?)
                                      ?.toDouble();
                              final discountedPrice =
                                  (carData?['discountedPrice'] as num?)
                                      ?.toDouble();

                              if (discountPercentage != null &&
                                  discountedPrice != null) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${PriceFormatter.formatPrice(amount)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.grey,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${PriceFormatter.formatPrice(discountedPrice)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Colors.orange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      "${discountPercentage.toStringAsFixed(0)}% OFF",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                );
                              }
                            }
                            return Text(
                              "${PriceFormatter.formatPrice(amount)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 20,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (carId == null ||
                                  carName == null ||
                                  startDate == null ||
                                  endDate == null) {
                                return;
                              }

                              final carDoc =
                                  await FirebaseFirestore.instance
                                      .collection('cars')
                                      .doc(carId)
                                      .get();
                              if (!carDoc.exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Car details not found!'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              final carData =
                                  carDoc.data() as Map<String, dynamic>;
                              final currentPrice =
                                  carData['discountedPrice'] ?? amount;

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PaymentScreen(
                                        carName: carName,
                                        carId: carId,
                                        startDate: startDate,
                                        endDate: endDate,
                                        totalPrice: currentPrice,
                                        insurance: data['insurance'] ?? false,
                                        childSeat: data['childSeat'] ?? false,
                                        carImage: carImage,
                                        pickupLocation:
                                            data['pickupLocation'] ??
                                            'Not specified',
                                        returnLocation:
                                            data['returnLocation'] ??
                                            'Not specified',
                                      ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(0, 20),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Pay Now',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Booking ID:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                bookingId?.toString() ?? '-',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isCancelled) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "This booking has been cancelled",
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "20% of the total amount has been retained as a cancellation fee according to our policy.",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildRefundDetailRow(
                                        'Original Amount',
                                        amount,
                                        Colors.grey,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildRefundDetailRow(
                                        'Retained Amount (20%)',
                                        finalRetainedAmount,
                                        Colors.red,
                                      ),
                                      const SizedBox(height: 6),
                                      _buildRefundDetailRow(
                                        'Refund Amount (80%)',
                                        finalRefundAmount,
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavorites(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('favorites')
              .where('userId', isEqualTo: userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().contains(
            'index is currently building',
          )) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading data...\nPlease wait a moment while we prepare your data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: Text('No favorites yet')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final favoriteDoc = docs[index];
            final carId = favoriteDoc.get('carId');
            _favoriteCarKeys[carId] = _favoriteCarKeys[carId] ?? GlobalKey();

            return StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('cars')
                      .doc(carId)
                      .snapshots(),
              builder: (context, carSnapshot) {
                if (!carSnapshot.hasData) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final carData =
                    carSnapshot.data!.data() as Map<String, dynamic>?;
                if (carData == null) {
                  return const SizedBox(
                    height: 80,
                    child: Center(child: Text('Car details not found')),
                  );
                }

                return Card(
                  key: _favoriteCarKeys[carId],
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            carData['image'] != null
                                ? carData['image'].toString().startsWith('http')
                                    ? Image.network(
                                      carData['image'],
                                      fit: BoxFit.cover,
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
                                        return const Icon(
                                          Icons.car_rental,
                                          size: 30,
                                        );
                                      },
                                    )
                                    : Image.asset(
                                      carData['image'],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => const Icon(
                                            Icons.car_rental,
                                            size: 30,
                                          ),
                                    )
                                : const Icon(Icons.car_rental, size: 30),
                      ),
                    ),
                    title: Text(
                      carData['name'] ?? 'Unknown Car',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: StatefulBuilder(
                      builder: (context, setState) {
                        return StreamBuilder<QuerySnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('bookings')
                                  .where('carId', isEqualTo: carId)
                                  .where('status', whereNotIn: ['cancelled'])
                                  .snapshots(),
                          builder: (context, bookingsSnapshot) {
                            if (!bookingsSnapshot.hasData) {
                              return Text(carData['brand'] ?? 'Unknown Brand');
                            }

                            bool isFullToday = false;
                            final today = DateTime.now();
                            for (var booking in bookingsSnapshot.data!.docs) {
                              final data =
                                  booking.data() as Map<String, dynamic>;
                              final start =
                                  (data['startDate'] as Timestamp).toDate();
                              final end =
                                  (data['endDate'] as Timestamp).toDate();
                              if (!today.isBefore(start) &&
                                  !today.isAfter(end)) {
                                isFullToday = true;
                                break;
                              }
                            }

                            return StreamBuilder<DocumentSnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(
                                        FirebaseAuth.instance.currentUser?.uid,
                                      )
                                      .snapshots(),
                              builder: (context, userSnapshot) {
                                final isCorporate =
                                    userSnapshot.hasData &&
                                    (userSnapshot.data?.data()
                                            as Map<
                                              String,
                                              dynamic
                                            >?)?['isCorporate'] ==
                                        true;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(carData['brand'] ?? 'Unknown Brand'),
                                    if (isFullToday && !isCorporate)
                                      Row(
                                        children: const [
                                          Icon(
                                            Icons.error,
                                            color: Colors.red,
                                            size: 16,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Vehicle is full today',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    trailing: StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('bookings')
                              .where('carId', isEqualTo: carId)
                              .where('status', whereNotIn: ['cancelled'])
                              .snapshots(),
                      builder: (context, bookingsSnapshot) {
                        bool isFullToday = false;
                        if (bookingsSnapshot.hasData) {
                          final today = DateTime.now();
                          for (var booking in bookingsSnapshot.data!.docs) {
                            final data = booking.data() as Map<String, dynamic>;
                            final start =
                                (data['startDate'] as Timestamp).toDate();
                            final end = (data['endDate'] as Timestamp).toDate();
                            if (!today.isBefore(start) && !today.isAfter(end)) {
                              isFullToday = true;
                              break;
                            }
                          }
                        }

                        return StreamBuilder<DocumentSnapshot>(
                          stream:
                              FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(FirebaseAuth.instance.currentUser?.uid)
                                  .snapshots(),
                          builder: (context, userSnapshot) {
                            final isCorporate =
                                userSnapshot.hasData &&
                                (userSnapshot.data?.data()
                                        as Map<
                                          String,
                                          dynamic
                                        >?)?['isCorporate'] ==
                                    true;

                            return IconButton(
                              icon: Icon(
                                Icons.favorite,
                                color:
                                    carData['isInMaintenance'] == true ||
                                            carData['isAvailable'] == false ||
                                            (isFullToday && !isCorporate)
                                        ? Colors.red.withOpacity(0.3)
                                        : Colors.red,
                              ),
                              onPressed:
                                  () =>
                                      _removeFavorite(favoriteDoc.id, context),
                            );
                          },
                        );
                      },
                    ),
                    onTap: () {
                      if (carId != null && carId is String) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CarDetailScreen(carId: carId),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Car details not found!'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
