import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_app/services/notification_service.dart';
import 'package:rxdart/rxdart.dart';

class CancellationManagementScreen extends StatefulWidget {
  final String? initialCancellationId;

  const CancellationManagementScreen({Key? key, this.initialCancellationId})
    : super(key: key);

  @override
  State<CancellationManagementScreen> createState() =>
      _CancellationManagementScreenState();
}

class _CancellationManagementScreenState
    extends State<CancellationManagementScreen> {
  final DateFormat dateFormat = DateFormat('MMM dd, yyyy');
  String _selectedStatus = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    if (widget.initialCancellationId != null) {
      _selectedStatus = 'all'; // Clear status filter if ID is provided
      _startDate = null; // Clear date filter if ID is provided
      _endDate = null; // Clear date filter if ID is provided
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancellation Management'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Statuses'),
                          ),
                          const DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          const DropdownMenuItem(
                            value: 'approved',
                            child: Text('Approved'),
                          ),
                          const DropdownMenuItem(
                            value: 'rejected',
                            child: Text('Rejected'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStatus = value;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final DateTimeRange? dateRange =
                              await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                initialDateRange:
                                    _startDate != null && _endDate != null
                                        ? DateTimeRange(
                                          start: _startDate!,
                                          end: _endDate!,
                                        )
                                        : null,
                              );
                          if (dateRange != null) {
                            setState(() {
                              _startDate = dateRange.start;
                              _endDate = dateRange.end;
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _startDate != null && _endDate != null
                              ? '${dateFormat.format(_startDate!)} - ${dateFormat.format(_endDate!)}'
                              : 'Select Date Range',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_startDate != null && _endDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear Date Filter'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No cancellation requests found'),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final requestDate =
                        (data['requestDate'] as Timestamp).toDate();
                    final status = data['status'] as String? ?? 'pending';
                    final reason =
                        data['reason'] as String? ?? 'No reason provided';
                    final bookingId = data['bookingId'] as String? ?? '';
                    final userId = data['userId'] as String? ?? '';
                    final firstName = data['firstName'] as String? ?? '';
                    final lastName = data['lastName'] as String? ?? '';
                    final email = data['email'] as String? ?? '';
                    final phone = data['phone'] as String? ?? '';
                    final description = data['description'] as String? ?? '';

                    // If bookingId is empty, show an error card
                    if (bookingId.isEmpty) {
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: const Text('Invalid Booking ID'),
                          subtitle: Text(
                            'Cancellation Request - ${dateFormat.format(requestDate)}',
                          ),
                          trailing: Text('Status: ${status.toUpperCase()}'),
                        ),
                      );
                    }

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getBookingAndPaymentData(bookingId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(
                                'Error loading booking: ${snapshot.error}',
                              ),
                              subtitle: Text('Booking ID: $bookingId'),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: const Text('Booking Not Found'),
                              subtitle: Text('Booking ID: $bookingId'),
                            ),
                          );
                        }

                        final data = snapshot.data!;
                        final carName = data['carName'] as String? ?? 'the car';
                        final totalAmount = data['totalAmount'] as double;
                        final voucherAmount = data['voucherAmount'] as double;
                        final finalAmount = data['finalAmount'] as double;

                        // Determine refund and retained amounts based on the reason
                        double displayRefundableAmount;
                        double displayRetainedAmount;

                        if (reason == 'Admin initiated 100% refund') {
                          displayRefundableAmount = finalAmount;
                          displayRetainedAmount = 0.0;
                        } else {
                          displayRefundableAmount =
                              finalAmount * 0.8; // Default 80% refund
                          displayRetainedAmount =
                              finalAmount * 0.2; // Default 20% retained
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ExpansionTile(
                            title: Text(
                              'Cancellation Request - ${dateFormat.format(requestDate)}',
                            ),
                            subtitle: Text('Status: ${status.toUpperCase()}'),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Booking ID: $bookingId'),
                                    const SizedBox(height: 8),
                                    Text('User: $firstName $lastName'),
                                    const SizedBox(height: 8),
                                    Text('Email: $email'),
                                    const SizedBox(height: 8),
                                    Text('Phone: $phone'),
                                    const SizedBox(height: 8),
                                    Text('Reason: $reason'),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text('Additional Comments: $description'),
                                    ],
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Payment Details',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Original Price:'),
                                              Text(
                                                PriceFormatter.formatPrice(
                                                  totalAmount,
                                                ),
                                                style: const TextStyle(
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
                                                const Text('Voucher Applied:'),
                                                Text(
                                                  PriceFormatter.formatPrice(
                                                    voucherAmount,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Final Amount Paid:'),
                                              Text(
                                                PriceFormatter.formatPrice(
                                                  finalAmount,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                reason ==
                                                        'Admin initiated 100% refund'
                                                    ? 'Refundable Amount (100%):'
                                                    : 'Refundable Amount (80%):',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                PriceFormatter.formatPrice(
                                                  displayRefundableAmount,
                                                ),
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
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                reason ==
                                                        'Admin initiated 100% refund'
                                                    ? 'Cancellation Fee (0%):'
                                                    : 'Cancellation Fee (20%):',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                              Text(
                                                PriceFormatter.formatPrice(
                                                  displayRetainedAmount,
                                                ),
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
                                    const SizedBox(height: 16),
                                    if (status == 'pending')
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton(
                                            onPressed:
                                                () => _updateStatus(
                                                  doc.id,
                                                  'approved',
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                          ElevatedButton(
                                            onPressed:
                                                () => _updateStatus(
                                                  doc.id,
                                                  'rejected',
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Reject'),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildQuery() {
    if (widget.initialCancellationId != null) {
      // Query directly by document ID using FieldPath.documentId
      return FirebaseFirestore.instance
          .collection('cancellations')
          .where(FieldPath.documentId, isEqualTo: widget.initialCancellationId!)
          .snapshots();
    } else {
      // Original query logic for filtering
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('cancellations')
          .orderBy('requestDate', descending: true);

      if (_selectedStatus != 'all') {
        query = query.where('status', isEqualTo: _selectedStatus);
      }

      if (_startDate != null && _endDate != null) {
        query = query.where(
          'requestDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!),
          isLessThanOrEqualTo: Timestamp.fromDate(_endDate!),
        );
      }
      return query.snapshots();
    }
  }

  Future<void> _updateStatus(String cancellationId, String newStatus) async {
    final BuildContext currentContext =
        context; // Capture context at the beginning
    try {
      // Get cancellation details
      final cancellationDoc =
          await FirebaseFirestore.instance
              .collection('cancellations')
              .doc(cancellationId)
              .get();

      if (!mounted)
        return; // Check mounted before any further async operations or context usage

      if (!cancellationDoc.exists) {
        throw Exception('Cancellation request not found');
      }

      final cancellationData = cancellationDoc.data()!;
      final bookingId = cancellationData['bookingId'] as String;
      final userId = cancellationData['userId'] as String;

      // Get booking details
      final bookingDoc =
          await FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .get();

      if (!mounted)
        return; // Check mounted again after potential async operation

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final bookingData = bookingDoc.data()!;
      final carName = bookingData['carName'] as String? ?? 'the car';

      // Get payment details
      final paymentId = bookingData['paymentId'] as String?;
      double totalAmount = 0.0;
      double voucherAmount = 0.0;
      double finalAmount = 0.0;

      if (paymentId != null && paymentId.isNotEmpty) {
        final paymentDoc =
            await FirebaseFirestore.instance
                .collection('payments')
                .doc(paymentId)
                .get();

        if (paymentDoc.exists) {
          final paymentData = paymentDoc.data()!;
          totalAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
          voucherAmount =
              (paymentData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
          finalAmount =
              (paymentData['finalAmount'] as num?)?.toDouble() ?? totalAmount;
        }
      } else {
        // Fallback to booking data if payment not found
        totalAmount = (bookingData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        voucherAmount =
            (bookingData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
        finalAmount =
            (bookingData['finalAmount'] as num?)?.toDouble() ?? totalAmount;
      }

      // Start a batch write
      final batch = FirebaseFirestore.instance.batch();

      if (newStatus == 'approved') {
        // Update booking status
        batch.update(
          FirebaseFirestore.instance.collection('bookings').doc(bookingId),
          {'status': 'cancelled'},
        );

        // Update or create payment record
        if (paymentId != null && paymentId.isNotEmpty) {
          batch.update(
            FirebaseFirestore.instance.collection('payments').doc(paymentId),
            {
              'status': 'cancelled',
              'cancellationDate': FieldValue.serverTimestamp(),
              'refundAmount': finalAmount * 0.8,
              'retainedAmount': finalAmount * 0.2,
              'originalAmount': totalAmount,
              'voucherAmount': voucherAmount,
              'finalAmount': finalAmount,
            },
          );
        } else {
          // Fallback: try to find payment by userId, carId, and date
          QuerySnapshot fallbackQuery =
              await FirebaseFirestore.instance
                  .collection('payments')
                  .where('userId', isEqualTo: bookingData['userId'])
                  .where('carId', isEqualTo: bookingData['carId'])
                  .where('startDate', isEqualTo: bookingData['startDate'])
                  .where('endDate', isEqualTo: bookingData['endDate'])
                  .get();

          if (!mounted) return;

          if (fallbackQuery.docs.isNotEmpty) {
            String paymentId = fallbackQuery.docs.first.id;
            batch.update(
              FirebaseFirestore.instance.collection('payments').doc(paymentId),
              {
                'status': 'cancelled',
                'cancellationDate': FieldValue.serverTimestamp(),
                'refundAmount': finalAmount * 0.8,
                'retainedAmount': finalAmount * 0.2,
                'originalAmount': totalAmount,
                'voucherAmount': voucherAmount,
                'finalAmount': finalAmount,
                'bookingId': bookingId,
              },
            );
          } else {
            // Create new payment record
            DocumentReference newPaymentRef =
                FirebaseFirestore.instance.collection('payments').doc();
            batch.set(newPaymentRef, {
              'status': 'cancelled',
              'cancellationDate': FieldValue.serverTimestamp(),
              'refundAmount': finalAmount * 0.8,
              'retainedAmount': finalAmount * 0.2,
              'originalAmount': totalAmount,
              'voucherAmount': voucherAmount,
              'finalAmount': finalAmount,
              'bookingId': bookingId,
              'userId': bookingData['userId'],
              'carId': bookingData['carId'],
              'startDate': bookingData['startDate'],
              'endDate': bookingData['endDate'],
              'carName': bookingData['carName'],
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        // Create a refund record
        batch.set(FirebaseFirestore.instance.collection('refunds').doc(), {
          'bookingId': bookingId,
          'userId': bookingData['userId'],
          'amount': totalAmount,
          'voucherAmount': voucherAmount,
          'finalAmount': finalAmount,
          'refundAmount': finalAmount * 0.8,
          'retainedAmount': finalAmount * 0.2,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'processed',
          'carName': bookingData['carName'],
        });
      }

      // Update cancellation status
      batch.update(
        FirebaseFirestore.instance
            .collection('cancellations')
            .doc(cancellationId),
        {
          'status': newStatus,
          'processedDate': FieldValue.serverTimestamp(),
          'totalAmount': totalAmount,
          'voucherAmount': voucherAmount,
          'finalAmount': finalAmount,
          'refundAmount': finalAmount * 0.8,
          'retainedAmount': finalAmount * 0.2,
        },
      );

      // Commit the batch
      await batch.commit();

      if (!mounted) return;

      // Send notification to user
      await NotificationService().sendNotification(
        title:
            newStatus == 'approved'
                ? 'Cancellation Approved'
                : 'Cancellation Rejected',
        body:
            newStatus == 'approved'
                ? 'Your cancellation request for $carName has been approved. You will receive a refund of ${PriceFormatter.formatPrice(finalAmount * 0.8)}.'
                : 'Your cancellation request for $carName has been rejected.',
        userId: userId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'approved'
                ? 'Cancellation approved. 20% (${PriceFormatter.formatPrice(finalAmount * 0.2)}) will be retained as cancellation fee.'
                : 'Cancellation request rejected',
          ),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted)
        return; // Check mounted before accessing context for error SnackBar
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _getBookingAndPaymentData(
    String bookingId,
  ) async {
    final bookingDoc =
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();

    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }

    final bookingData = bookingDoc.data()!;
    final carName = bookingData['carName'] as String? ?? 'the car';

    // Get payment details
    final paymentId = bookingData['paymentId'] as String?;
    double totalAmount = 0.0;
    double voucherAmount = 0.0;
    double finalAmount = 0.0;

    if (paymentId != null && paymentId.isNotEmpty) {
      final paymentDoc =
          await FirebaseFirestore.instance
              .collection('payments')
              .doc(paymentId)
              .get();

      if (paymentDoc.exists) {
        final paymentData = paymentDoc.data()!;
        totalAmount = (paymentData['amount'] as num?)?.toDouble() ?? 0.0;
        voucherAmount =
            (paymentData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
        finalAmount =
            (paymentData['finalAmount'] as num?)?.toDouble() ?? totalAmount;
      }
    } else {
      // Fallback to booking data if payment not found
      totalAmount = (bookingData['totalAmount'] as num?)?.toDouble() ?? 0.0;
      voucherAmount = (bookingData['voucherAmount'] as num?)?.toDouble() ?? 0.0;
      finalAmount =
          (bookingData['finalAmount'] as num?)?.toDouble() ?? totalAmount;
    }

    return {
      'carName': carName,
      'totalAmount': totalAmount,
      'voucherAmount': voucherAmount,
      'finalAmount': finalAmount,
    };
  }
}
