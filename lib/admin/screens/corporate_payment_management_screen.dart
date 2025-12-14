import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:intl/intl.dart';

class CorporatePaymentManagementScreen extends StatefulWidget {
  const CorporatePaymentManagementScreen({super.key});

  @override
  State<CorporatePaymentManagementScreen> createState() =>
      _CorporatePaymentManagementScreenState();
}

class _CorporatePaymentManagementScreenState
    extends State<CorporatePaymentManagementScreen> {
  String selectedStatus = 'All';
  List<QueryDocumentSnapshot>? _payments;
  bool _isLoading = true;

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('payments')
              .where('isCorporate', isEqualTo: true)
              .get();

      setState(() {
        _payments = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading payments: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading payments: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corporate Payments'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPayments),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: selectedStatus,
              isExpanded: true,
              items:
                  ['All', 'pending', 'completed', 'failed', 'refunded']
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.toUpperCase()),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedStatus = value;
                  });
                }
              },
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _payments == null || _payments!.isEmpty
                    ? const Center(child: Text('No corporate payments found'))
                    : RefreshIndicator(
                      onRefresh: _loadPayments,
                      child: ListView.builder(
                        itemCount: _payments!.length,
                        itemBuilder: (context, index) {
                          final payment =
                              _payments![index].data() as Map<String, dynamic>;
                          final paymentId = _payments![index].id;

                          // Filter by status
                          if (selectedStatus != 'All' &&
                              payment['status'] != selectedStatus) {
                            return const SizedBox.shrink();
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              title: Text(payment['carName'] ?? 'Unknown Car'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Company: ${payment['companyName'] ?? 'N/A'}',
                                  ),
                                  Text(
                                    'Amount: ${payment['amount']?.toStringAsFixed(2) ?? 'N/A'} ₺',
                                  ),
                                  Text(
                                    'Date: ${DateFormat('MMM dd, yyyy').format((payment['timestamp'] as Timestamp).toDate())}',
                                  ),
                                  Text(
                                    'Status: ${payment['status']?.toUpperCase() ?? 'N/A'}',
                                  ),
                                  if (payment['paymentMethod'] != null)
                                    Text(
                                      'Payment Method: ${payment['paymentMethod']}',
                                    ),
                                ],
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'view',
                                        child: const Text('View Details'),
                                      ),
                                      if (payment['status'] == 'completed')
                                        PopupMenuItem(
                                          value: 'refund',
                                          child: const Text('Process Refund'),
                                        ),
                                      if (payment['status'] == 'pending')
                                        PopupMenuItem(
                                          value: 'complete',
                                          child: const Text(
                                            'Mark as Completed',
                                          ),
                                        ),
                                    ],
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'view':
                                      Navigator.pushNamed(
                                        context,
                                        '/payment_detail',
                                        arguments: paymentId,
                                      );
                                      break;
                                    case 'refund':
                                      final shouldRefund = await showDialog<
                                        bool
                                      >(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Process Refund',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to process a refund for this payment?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('No'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Yes'),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (shouldRefund == true) {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('payments')
                                              .doc(paymentId)
                                              .update({
                                                'status': 'refunded',
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          _loadPayments(); // Refresh the list
                                        } catch (e) {
                                          print('Error processing refund: $e');
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error processing refund: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      break;
                                    case 'complete':
                                      final shouldComplete = await showDialog<
                                        bool
                                      >(
                                        context: context,
                                        builder:
                                            (context) => AlertDialog(
                                              title: const Text(
                                                'Complete Payment',
                                              ),
                                              content: const Text(
                                                'Are you sure you want to mark this payment as completed?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('No'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text('Yes'),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (shouldComplete == true) {
                                        try {
                                          await FirebaseFirestore.instance
                                              .collection('payments')
                                              .doc(paymentId)
                                              .update({
                                                'status': 'completed',
                                                'updatedAt':
                                                    FieldValue.serverTimestamp(),
                                              });
                                          _loadPayments(); // Refresh the list
                                        } catch (e) {
                                          print('Error completing payment: $e');
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error completing payment: $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      break;
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
