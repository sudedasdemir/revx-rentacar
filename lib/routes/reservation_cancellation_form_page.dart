import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/services/notification_service.dart';

class ReservationCancellationFormPage extends StatefulWidget {
  const ReservationCancellationFormPage({super.key});

  @override
  _ReservationCancellationFormPageState createState() =>
      _ReservationCancellationFormPageState();
}

class _ReservationCancellationFormPageState
    extends State<ReservationCancellationFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _reservationNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cancellationReasonController =
      TextEditingController();

  final List<String> _cancellationReasons = [
    'Change of plans',
    'Better price found',
    'Emergency situation',
    'Travel dates changed',
    'Vehicle preference changed',
    'Other',
  ];
  String? _selectedReason;

  String? _bookingDetails;
  List<Map<String, dynamic>> _activeBookings = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadActiveBookings();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userData =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userData.exists) {
          setState(() {
            _firstNameController.text = userData.get('firstName') ?? '';
            _lastNameController.text = userData.get('lastName') ?? '';
            _emailController.text = user.email ?? '';
            _phoneController.text = userData.get('phone') ?? '';
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }

  Future<void> _loadActiveBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final now = DateTime.now();
      final bookingsSnapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'upcoming')
              .get();

      if (!mounted) return;

      // Get all payments for these bookings
      final bookingIds = bookingsSnapshot.docs.map((doc) => doc.id).toList();
      final paymentsSnapshot =
          await FirebaseFirestore.instance
              .collection('payments')
              .where('bookingId', whereIn: bookingIds)
              .get();

      // Create a map of bookingId to payment data
      final paymentMap = {
        for (var doc in paymentsSnapshot.docs)
          doc['bookingId'] as String: doc.data(),
      };

      setState(() {
        _activeBookings =
            bookingsSnapshot.docs
                .map((doc) {
                  final data = doc.data();
                  final startDate = (data['startDate'] as Timestamp).toDate();
                  final endDate = (data['endDate'] as Timestamp).toDate();
                  final isFuture = now.isBefore(startDate);
                  final isCancellable =
                      isFuture && startDate.difference(now).inHours >= 24;

                  // Get price from payment data if available
                  final paymentData = paymentMap[doc.id];
                  final totalPrice =
                      paymentData != null
                          ? (paymentData['amount'] as num?)?.toDouble() ?? 0.0
                          : (data['totalAmount'] as num?)?.toDouble() ?? 0.0;

                  final voucherAmount =
                      paymentData != null
                          ? (paymentData['voucherAmount'] as num?)
                                  ?.toDouble() ??
                              0.0
                          : (data['voucherAmount'] as num?)?.toDouble() ?? 0.0;

                  final finalAmount =
                      paymentData != null
                          ? (paymentData['finalAmount'] as num?)?.toDouble() ??
                              totalPrice
                          : (data['finalAmount'] as num?)?.toDouble() ??
                              totalPrice;

                  return {
                    'id': doc.id,
                    'carName': data['carName'] ?? 'Unknown Car',
                    'startDate': startDate,
                    'endDate': endDate,
                    'status': data['status'] ?? 'pending',
                    'isFuture': isFuture,
                    'isCancellable': isCancellable,
                    'totalPrice': totalPrice,
                    'voucherAmount': voucherAmount,
                    'finalAmount': finalAmount,
                  };
                })
                .where((booking) => booking['isCancellable'] == true)
                .toList();
      });
    } catch (e) {
      print('Error loading active bookings: $e');
    } finally {
      if (_reservationNumberController.text.isNotEmpty && mounted) {
        _loadingDetails(_reservationNumberController.text);
      }
    }
  }

  double _calculateRefundableAmount(double totalPrice) {
    // 20% cancellation fee
    return totalPrice * 0.8;
  }

  void _showActiveBookingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Upcoming Bookings',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cancellation Rules:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRuleItem(
                          'Only upcoming reservations can be canceled',
                        ),
                        _buildRuleItem(
                          'Cannot cancel if less than 24 hours before delivery',
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A 20% cancellation fee will be applied to all cancellations',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child:
                        _activeBookings.isEmpty
                            ? const Center(
                              child: Text(
                                'No active bookings found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                            : ListView.builder(
                              controller: scrollController,
                              itemCount: _activeBookings.length,
                              itemBuilder: (context, index) {
                                final booking = _activeBookings[index];
                                final isCancellable = _isBookingCancellable(
                                  booking['startDate'],
                                );
                                final isFuture = booking['isFuture'] as bool;
                                final totalPrice =
                                    (booking['totalPrice'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final voucherAmount =
                                    (booking['voucherAmount'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final finalAmount =
                                    (booking['finalAmount'] as num?)
                                        ?.toDouble() ??
                                    totalPrice;
                                final refundableAmount =
                                    _calculateRefundableAmount(finalAmount);
                                final retainedAmount =
                                    finalAmount - refundableAmount;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: InkWell(
                                    onTap:
                                        isCancellable
                                            ? () {
                                              setState(() {
                                                _reservationNumberController
                                                    .text = booking['id'];
                                                _bookingDetails =
                                                    'Rental Period: '
                                                    '${DateFormat('MMM dd, yyyy HH:mm').format(booking['startDate'])} - '
                                                    '${DateFormat('MMM dd, yyyy HH:mm').format(booking['endDate'])}\n'
                                                    'Vehicle: ${booking['carName'] ?? 'Unknown Car'}\n'
                                                    'Original Price: ₺${totalPrice.toStringAsFixed(2)}\n'
                                                    '${voucherAmount > 0 ? 'Voucher Applied: -₺${voucherAmount.toStringAsFixed(2)}\n' : ''}'
                                                    'Final Amount Paid: ₺${finalAmount.toStringAsFixed(2)}\n'
                                                    'Refundable Amount (80%): ₺${refundableAmount.toStringAsFixed(2)}\n'
                                                    'Cancellation Fee (20%): ₺${retainedAmount.toStringAsFixed(2)}';
                                              });
                                              Navigator.pop(context);
                                            }
                                            : null,
                                    child: Opacity(
                                      opacity: isCancellable ? 1.0 : 0.6,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    booking['carName'],
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (!isCancellable)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'Not Cancellable',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${DateFormat('MMM dd, yyyy').format(booking['startDate'])} - '
                                                  '${DateFormat('MMM dd, yyyy').format(booking['endDate'])}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.access_time,
                                                  size: 16,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '${DateFormat('HH:mm').format(booking['startDate'])} - '
                                                  '${DateFormat('HH:mm').format(booking['endDate'])}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        booking['status'] ==
                                                                'confirmed'
                                                            ? Colors.green
                                                                .withOpacity(
                                                                  0.1,
                                                                )
                                                            : Colors.blue
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    booking['status']
                                                        .toString()
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color:
                                                          booking['status'] ==
                                                                  'confirmed'
                                                              ? Colors.green
                                                              : Colors.blue,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (isFuture &&
                                                    booking['status'] !=
                                                        'upcoming') ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'UPCOMING',
                                                      style: TextStyle(
                                                        color: Colors.blue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Original Price:',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '₺${totalPrice.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (voucherAmount > 0) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text(
                                                    'Voucher Applied:',
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '-₺${voucherAmount.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Final Amount Paid:',
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '₺${finalAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Refundable:',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '₺${refundableAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                const Text(
                                                  'Fee:',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '₺${retainedAmount.toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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

  Widget _buildRuleItem(String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  bool _isBookingCancellable(DateTime startDate) {
    final now = DateTime.now();
    final difference = startDate.difference(now);
    return difference.inHours >= 24;
  }

  Future<void> _loadingDetails(String bookingId) async {
    // Don't search if booking ID is too short
    if (bookingId.length < 5) {
      setState(() => _bookingDetails = null);
      return;
    }

    try {
      setState(() => _bookingDetails = 'Searching...'); // Show loading state

      // First try to get the payment information
      final paymentQuery =
          await FirebaseFirestore.instance
              .collection('payments')
              .where('bookingId', isEqualTo: bookingId)
              .limit(1)
              .get();

      double totalPrice = 0.0;
      double voucherAmount = 0.0;
      double finalAmount = 0.0;
      String carName = 'Unknown Car';

      if (paymentQuery.docs.isNotEmpty) {
        final paymentData = paymentQuery.docs.first.data();
        totalPrice = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
        voucherAmount =
            (paymentData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
        finalAmount =
            (paymentData['finalAmount'] as num?)?.toDouble() ?? totalPrice;
        carName = paymentData['carName'] as String? ?? 'Unknown Car';
      }

      // If no payment found or amount is zero, try to get from booking
      if (totalPrice == 0.0) {
        final bookingDoc =
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get();

        if (!mounted) return;

        if (!bookingDoc.exists) {
          setState(() => _bookingDetails = 'Booking not found');
          return;
        }

        final data = bookingDoc.data() as Map<String, dynamic>;
        totalPrice = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        voucherAmount = (data['voucherAmount'] as num?)?.toDouble() ?? 0.0;
        finalAmount = (data['finalAmount'] as num?)?.toDouble() ?? totalPrice;
        carName = data['carName'] as String? ?? 'Unknown Car';
      }

      // Get booking dates from the booking document
      final bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

      if (!bookingDoc.exists) {
        setState(() => _bookingDetails = 'Booking not found');
        return;
      }

      final data = bookingDoc.data() as Map<String, dynamic>;
      final startDate = (data['startDate'] as Timestamp).toDate();
      final endDate = (data['endDate'] as Timestamp).toDate();

      // Calculate refundable amount based on the final amount paid
      final refundableAmount = _calculateRefundableAmount(finalAmount);
      final retainedAmount = finalAmount - refundableAmount;

      setState(() {
        _bookingDetails =
            'Rental Period: '
            '${DateFormat('MMM dd, yyyy HH:mm').format(startDate)} - '
            '${DateFormat('MMM dd, yyyy HH:mm').format(endDate)}\n'
            'Vehicle: $carName\n'
            'Original Price: ₺${totalPrice.toStringAsFixed(2)}\n'
            '${voucherAmount > 0 ? 'Voucher Applied: -₺${voucherAmount.toStringAsFixed(2)}\n' : ''}'
            'Final Amount Paid: ₺${finalAmount.toStringAsFixed(2)}\n'
            'Refundable Amount (80%): ₺${refundableAmount.toStringAsFixed(2)}\n'
            'Cancellation Fee (20%): ₺${retainedAmount.toStringAsFixed(2)}';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _bookingDetails = 'Error loading booking details');
      }
      print('Error loading booking details: $e');
    }
  }

  Future<bool> _validateCancellationEligibility(String bookingId) async {
    try {
      final bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final data = bookingDoc.data() as Map<String, dynamic>;
      final startDate = (data['startDate'] as Timestamp).toDate();
      final now = DateTime.now();

      // Check if the booking is upcoming
      if (data['status'] != 'upcoming') {
        _showIneligibleDialog(
          'Cancellation Not Allowed',
          'Only upcoming reservations can be canceled.',
        );
        return false;
      }

      // Check if less than 24 hours before rental starts
      final difference = startDate.difference(now);
      if (difference.inHours < 24) {
        _showIneligibleDialog(
          'Cancellation Time Limit',
          'Cancellations must be made at least 24 hours before the rental start time.',
        );
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking cancellation eligibility: $e');
      return false;
    }
  }

  void _showIneligibleDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 16),
                const Text(
                  'Please review our cancellation policy for more information.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pushNamed(context, '/return_cancel_terms');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Cancellation Policy'),
              ),
            ],
          ),
    );
  }

  Future<void> _submitCancellation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate cancellation eligibility
      final isEligible = await _validateCancellationEligibility(
        _reservationNumberController.text,
      );

      if (!isEligible) {
        setState(() => _isSubmitting = false);
        return;
      }

      // Get booking details for notification
      final bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(_reservationNumberController.text)
              .get();

      final bookingData = bookingDoc.data();
      final carName = bookingData?['carName'] as String? ?? 'the car';

      // Create cancellation request
      await FirebaseFirestore.instance.collection('cancellations').add({
        'userId': user.uid,
        'bookingId': _reservationNumberController.text,
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'reason': _selectedReason,
        'description': _cancellationReasonController.text,
        'status': 'pending',
        'requestDate': FieldValue.serverTimestamp(),
        'processed': false,
        'processedDate': null,
      });

      // Send notification to user
      await NotificationService().sendNotification(
        title: 'Cancellation Request Submitted',
        body:
            'Your cancellation request for $carName has been submitted and is being reviewed.',
        userId: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting cancellation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reservation Cancellation"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Cancellation Policy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please note that cancellation fees may apply depending on the timing of your cancellation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/return_cancel_terms',
                            );
                          },
                          icon: const Icon(Icons.policy_outlined),
                          label: const Text('View Full Cancellation Policy'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            textStyle: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (_bookingDetails == 'Booking not found' ||
                            _bookingDetails?.contains('Error') == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Please review our cancellation policy for eligibility criteria',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (!RegExp(r'^[a-zA-Z\s]*$').hasMatch(value!)) {
                              return 'Only letters are allowed';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (!RegExp(r'^[a-zA-Z\s]*$').hasMatch(value!)) {
                              return 'Only letters are allowed';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Booking Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _showActiveBookingsModal,
                              icon: const Icon(Icons.list_alt),
                              label: const Text('View cars'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reservationNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Reservation Number',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your booking reference',
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (_bookingDetails == 'Booking not found') {
                              return 'Please enter a valid booking number';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            Future.delayed(
                              const Duration(milliseconds: 500),
                              () {
                                if (_reservationNumberController.text ==
                                    value) {
                                  _loadingDetails(value);
                                }
                              },
                            );
                          },
                        ),
                        if (_bookingDetails != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Booking Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._bookingDetails!.split('\n').map((line) {
                                  if (line.startsWith('Rental Period:')) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              line,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (line.startsWith('Vehicle:')) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.directions_car,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              line,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (line.startsWith('Total Price:')) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.attach_money,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              line,
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (line.startsWith(
                                    'Refundable Amount',
                                  )) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.money_off,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              line,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (line.startsWith(
                                    'Cancellation Fee',
                                  )) {
                                    return Row(
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            line,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contact Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value!)) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                            prefixText: '+',
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 12,
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (!RegExp(r'^[0-9]*$').hasMatch(value!)) {
                              return 'Only numbers are allowed';
                            }
                            if (value.length != 12) {
                              return 'Phone number must be exactly 12 digits';
                            }
                            return null;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cancellation Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedReason,
                          decoration: const InputDecoration(
                            labelText: 'Reason for Cancellation',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _cancellationReasons
                                  .map(
                                    (reason) => DropdownMenuItem(
                                      value: reason,
                                      child: Text(reason),
                                    ),
                                  )
                                  .toList(),
                          validator:
                              (value) =>
                                  value == null
                                      ? 'Please select a reason'
                                      : null,
                          onChanged: (value) {
                            setState(() => _selectedReason = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _cancellationReasonController,
                          decoration: const InputDecoration(
                            labelText: 'Additional Comments',
                            border: OutlineInputBorder(),
                            hintText:
                                'Provide more details about your cancellation',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitCancellation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Submit Cancellation Request',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _reservationNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cancellationReasonController.dispose();
    super.dispose();
  }
}
