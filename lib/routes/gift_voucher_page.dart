import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class GiftVoucherPage extends StatefulWidget {
  const GiftVoucherPage({super.key});

  @override
  State<GiftVoucherPage> createState() => _GiftVoucherPageState();
}

class _GiftVoucherPageState extends State<GiftVoucherPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _recipientEmailController =
      TextEditingController();
  final TextEditingController _recipientPhoneController =
      TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String? _selectedAmount;
  bool _acceptTerms = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _createdChecks = [];
  double _availableWalletAmount = 0;
  double _totalSpent = 0;

  @override
  void initState() {
    super.initState();
    _loadCreatedChecks();
    _loadWalletAmount();
    _setupVoucherListener();
  }

  @override
  void dispose() {
    _voucherSubscription?.cancel();
    _recipientNameController.dispose();
    _recipientEmailController.dispose();
    _recipientPhoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  StreamSubscription? _voucherSubscription;

  void _setupVoucherListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    _voucherSubscription = _firestore
        .collection('gift_vouchers')
        .where('senderId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) async {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified) {
              final newData = change.doc.data();
              final oldData =
                  change.oldIndex != -1
                      ? snapshot.docs[change.oldIndex].data()
                      : null;

              // Check if status changed to approved
              if (newData != null &&
                  oldData != null &&
                  newData['status'] == 'approved' &&
                  oldData['status'] != 'approved') {
                final amount = (newData['amount'] ?? 0.0).toDouble();
                final isSelfUse = newData['isSelfUse'] ?? false;

                try {
                  // Update both available discount and total spent in Firestore
                  await _firestore.collection('users').doc(user.uid).update({
                    'totalSpent': FieldValue.increment(-amount),
                  });

                  // Update the payments collection to reflect the deduction
                  await _firestore.collection('payments').add({
                    'userId': user.uid,
                    'amount': -amount,
                    'type': 'voucher_deduction',
                    'voucherId': change.doc.id,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // Update local state
                  if (mounted) {
                    setState(() {
                      _availableWalletAmount -= amount;
                      _totalSpent -= amount;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isSelfUse
                              ? 'Self-use voucher approved! ${amount.toStringAsFixed(2)} ₺ has been deducted from your available discount and total spent.'
                              : 'Gift voucher approved! ${amount.toStringAsFixed(2)} ₺ has been deducted from your available discount and total spent.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  print('Error updating amounts: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error updating amounts: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            }
          }
        });
  }

  Future<void> _loadWalletAmount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final paymentsSnapshot =
          await _firestore
              .collection('payments')
              .where('userId', isEqualTo: user.uid)
              .get();

      double spent = 0;
      for (var p in paymentsSnapshot.docs) {
        final data = p.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final status = data['status'] as String? ?? 'pending';

        // Only count completed payments
        if (status == 'completed') {
          spent += amount;
        }

        // Subtract refunded amounts for cancelled payments
        if (status == 'cancelled' || status == 'refunded') {
          final refundAmount = (data['refundAmount'] as num?)?.toDouble() ?? 0;
          spent -= refundAmount;
        }
      }

      // Load used vouchers to adjust the total spent
      final usedVouchers =
          await _firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user.uid)
              .where('isUsed', isEqualTo: true)
              .get();

      double usedVoucherAmount = 0;
      for (var voucher in usedVouchers.docs) {
        usedVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
      }

      // Load active vouchers
      final activeVouchers =
          await _firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'approved')
              .where('isUsed', isEqualTo: false)
              .get();

      double activeVoucherAmount = 0;
      for (var voucher in activeVouchers.docs) {
        activeVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
      }

      // Adjust total spent by subtracting used voucher amounts
      spent -= usedVoucherAmount;

      // Ensure spent amount is not negative
      spent = spent < 0 ? 0 : spent;

      if (mounted) {
        setState(() {
          _totalSpent = spent;
          _availableWalletAmount =
              (spent * 0.01) -
              activeVoucherAmount; // 1% of total spent minus active vouchers
          _availableWalletAmount =
              _availableWalletAmount < 0
                  ? 0
                  : _availableWalletAmount; // Ensure non-negative
        });
      }
    } catch (e) {
      print('Error loading wallet amount: $e');
    }
  }

  Future<void> _loadCreatedChecks() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final checksSnapshot =
          await _firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user.uid)
              .get();

      if (mounted) {
        final checks =
            checksSnapshot.docs
                .map((doc) => {'id': doc.id, ...doc.data()})
                .toList();

        checks.sort((a, b) {
          final aDate =
              (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final bDate =
              (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate);
        });

        setState(() {
          _createdChecks = checks;
        });
      }
    } catch (e) {
      print('Error loading created checks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Voucher'),
        backgroundColor: AppColors.secondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_availableWalletAmount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Available Wallet Discount: ${_availableWalletAmount.toStringAsFixed(2)} ₺',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can use this amount to create gift vouchers for others.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Gift Voucher Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_createdChecks.isEmpty)
                    const Text(
                      'No gift vouchers created yet.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: [
                        _buildStatusSummary(),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            Scrollable.ensureVisible(
                              context,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('View All Vouchers'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recipient Information',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _recipientNameController,
                    'Recipient\'s Full Name',
                    Icons.person,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _recipientEmailController,
                    'Recipient\'s Email',
                    Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _recipientPhoneController,
                    'Recipient\'s Phone Number',
                    Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Gift Voucher Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildAmountField(),
                  const SizedBox(height: 10),
                  _buildTextField(
                    _messageController,
                    'Personal Message (Optional)',
                    Icons.message,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _acceptTerms = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'I accept the Terms and Conditions.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child:
                        _isSubmitting
                            ? const CircularProgressIndicator()
                            : ElevatedButton.icon(
                              onPressed: _acceptTerms ? _submitForm : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                  vertical: 15,
                                ),
                              ),
                              icon: const Icon(Icons.card_giftcard),
                              label: const Text('Send Gift Voucher'),
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            if (_createdChecks.isNotEmpty)
              ExpansionTile(
                title: Row(
                  children: [
                    Icon(Icons.history, color: AppColors.secondary),
                    const SizedBox(width: 8),
                    const Text(
                      'Gift Voucher History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                children:
                    _createdChecks.map((check) {
                      return _buildCheckItem(check);
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    List<TextInputFormatter>? formatters;

    if (label.contains('Name')) {
      formatters = [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))];
    } else if (label.contains('Phone')) {
      formatters = [FilteringTextInputFormatter.digitsOnly];
    }

    return TextField(
      controller: controller,
      keyboardType:
          label.contains('Phone') ? TextInputType.number : keyboardType,
      maxLines: maxLines,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_availableWalletAmount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Available in wallet: ${_availableWalletAmount.toStringAsFixed(2)} ₺',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        TextField(
          controller: TextEditingController(text: _selectedAmount),
          decoration: InputDecoration(
            labelText: 'Voucher Amount (₺)',
            prefixIcon: const Icon(Icons.money),
            border: const OutlineInputBorder(),
            helperText:
                _availableWalletAmount > 0
                    ? 'Maximum amount: ${_availableWalletAmount.toStringAsFixed(2)} ₺'
                    : null,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (value.isEmpty) {
              setState(() {
                _selectedAmount = value;
              });
              return;
            }

            final amount = double.tryParse(value);
            if (amount != null) {
              if (_availableWalletAmount > 0 &&
                  amount > _availableWalletAmount) {
                setState(() {
                  _selectedAmount = _availableWalletAmount.toStringAsFixed(2);
                });
              } else {
                setState(() {
                  _selectedAmount = value;
                });
              }
            }
          },
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final amount = double.parse(_selectedAmount!);
      final user = _auth.currentUser;

      if (user == null) {
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      if (_availableWalletAmount > 0 && amount > _availableWalletAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Amount cannot exceed available wallet amount of ${_availableWalletAmount.toStringAsFixed(2)} ₺',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Deduct the amount from available discount immediately
      setState(() {
        _availableWalletAmount -= amount;
      });

      _firestore
          .collection('gift_vouchers')
          .add({
            'recipientName': _recipientNameController.text,
            'recipientEmail': _recipientEmailController.text,
            'recipientPhone': _recipientPhoneController.text,
            'amount': amount,
            'message': _messageController.text,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'senderId': user.uid,
            'senderEmail': user.email,
            'isSelfUse': false,
            'isApproved': false,
            'walletAmountUsed': amount,
            'totalSpent': _totalSpent,
          })
          .then((_) async {
            // Add a payment record for the deduction
            await _firestore.collection('payments').add({
              'userId': user.uid,
              'amount': -amount,
              'type': 'voucher_creation',
              'timestamp': FieldValue.serverTimestamp(),
            });

            if (mounted) {
              setState(() {
                _isSubmitting = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Gift Voucher request submitted successfully! Waiting for admin approval.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );

              _clearForm();
              _loadCreatedChecks();
              _loadWalletAmount();
            }
          })
          .catchError((error) {
            // If there's an error, add the amount back to available discount
            setState(() {
              _availableWalletAmount += amount;
              _isSubmitting = false;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error submitting voucher: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
    }
  }

  void _clearForm() {
    _recipientNameController.clear();
    _recipientEmailController.clear();
    _recipientPhoneController.clear();
    _messageController.clear();
    _selectedAmount = null;
    _acceptTerms = false;
    setState(() {});
  }

  Widget _buildStatusSummary() {
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    int used = 0;

    for (var check in _createdChecks) {
      final status = check['status'] ?? 'pending';
      final isUsed = check['isUsed'] ?? false;

      if (isUsed) {
        used++;
      } else {
        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'approved':
            approved++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatusItem('Pending', pending, Colors.orange),
        _buildStatusItem('Approved', approved, Colors.green),
        _buildStatusItem('Used', used, Colors.blue),
        _buildStatusItem('Rejected', rejected, Colors.red),
      ],
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildCheckItem(Map<String, dynamic> check) {
    final status = check['status'] ?? 'pending';
    final amount = check['amount'] ?? 0.0;
    final message = check['message'] ?? '';
    final createdAt =
        (check['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isUsed = check['isUsed'] ?? false;
    final isSelfUse = check['isSelfUse'] ?? false;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isUsed) {
      statusColor = Colors.blue;
      statusIcon = Icons.check_circle;
      statusText = 'Used';
    } else {
      switch (status) {
        case 'approved':
          statusColor = Colors.green;
          statusIcon = Icons.check_circle;
          statusText = 'Approved';
          break;
        case 'rejected':
          statusColor = Colors.red;
          statusIcon = Icons.cancel;
          statusText = 'Rejected';
          break;
        default:
          statusColor = Colors.orange;
          statusIcon = Icons.pending;
          statusText = 'Pending Approval';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${amount.toStringAsFixed(2)} ₺',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isSelfUse ? 'Self-use' : 'Gift',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]
                        : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Created: ${createdAt.toString().split('.')[0]}',
            style: TextStyle(
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
