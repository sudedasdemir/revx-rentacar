import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/colors.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  double totalSpent = 0;
  double totalGiftCheckAmount = 0;
  double availableDiscount = 0;
  List<Map<String, dynamic>> _receivedVouchers = [];
  List<Map<String, dynamic>> _createdChecks = [];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    if (user == null) return;

    try {
      // Load total spent including voucher deductions
      final payments =
          await firestore
              .collection('payments')
              .where('userId', isEqualTo: user!.uid)
              .get();

      double spent = 0;
      for (var p in payments.docs) {
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
          await firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user!.uid)
              .where('isUsed', isEqualTo: true)
              .get();

      double usedVoucherAmount = 0;
      for (var voucher in usedVouchers.docs) {
        usedVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
      }

      // Load pending and approved vouchers that haven't been used
      final activeVouchers =
          await firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user!.uid)
              .where('status', isEqualTo: 'approved')
              .where('isUsed', isEqualTo: false)
              .get();

      double activeVoucherAmount = 0;
      for (var voucher in activeVouchers.docs) {
        activeVoucherAmount += (voucher.data()['amount'] ?? 0).toDouble();
      }

      // Adjust total spent by subtracting used voucher amounts
      spent -= usedVoucherAmount;

      // Calculate available discount (1% of total spent minus active vouchers)
      availableDiscount = (spent * 0.01) - activeVoucherAmount;
      availableDiscount = availableDiscount < 0 ? 0 : availableDiscount;

      // Ensure spent amount is not negative
      spent = spent < 0 ? 0 : spent;

      // Load gift check amount
      final giftCheckDoc =
          await firestore.collection('gift_checks').doc(user!.uid).get();
      double giftAmount = 0;
      if (giftCheckDoc.exists) {
        giftAmount = (giftCheckDoc.data()?['amount'] ?? 0).toDouble();
      }

      // Load received vouchers
      final vouchersSnapshot =
          await firestore
              .collection('gift_vouchers')
              .where('recipientEmail', isEqualTo: user!.email)
              .where('status', isEqualTo: 'approved')
              .where('isSelfUse', isEqualTo: false)
              .get();

      // Load created checks
      final checksSnapshot =
          await firestore
              .collection('gift_vouchers')
              .where('senderId', isEqualTo: user!.uid)
              .orderBy('createdAt', descending: true)
              .get();

      if (mounted) {
        setState(() {
          totalSpent = spent;
          totalGiftCheckAmount = giftAmount;
          _receivedVouchers =
              vouchersSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
          _createdChecks =
              checksSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
        });
      }
    } catch (e) {
      print('Error loading wallet data: $e');
    }
  }

  void _createGiftVoucher() async {
    final availableAmount = totalSpent * 0.01;
    final amountController = TextEditingController();
    final messageController = TextEditingController();

    if (mounted) {
      await showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Create Gift Voucher'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Available Amount: ${availableAmount.toStringAsFixed(2)} ₺',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₺)',
                        hintText: 'Enter amount',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        hintText: 'Add a note for yourself',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null ||
                        amount <= 0 ||
                        amount > availableAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      // Create the voucher
                      await firestore.collection('gift_vouchers').add({
                        'senderId': user!.uid,
                        'senderEmail': user!.email,
                        'recipientEmail': user!.email,
                        'amount': amount,
                        'message': messageController.text,
                        'status': 'pending',
                        'createdAt': FieldValue.serverTimestamp(),
                        'type': 'wallet',
                        'isSelfUse': true,
                        'giftCheckAmount': amount,
                        'totalSpent': totalSpent,
                      });

                      // Add a payment record for the deduction
                      await firestore.collection('payments').add({
                        'userId': user!.uid,
                        'amount': -amount,
                        'type': 'voucher_creation',
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gift voucher created successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        _loadWalletData(); // Reload data after creating voucher
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating gift voucher: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher, bool isReceived) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final amount = voucher['amount'] ?? 0.0;
    final senderEmail = voucher['senderEmail'] ?? '';
    final message = voucher['message'] ?? '';
    final createdAt =
        (voucher['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final status = voucher['status'] ?? 'pending';
    final isSelfUse = voucher['isSelfUse'] ?? false;

    Color statusColor;
    IconData statusIcon;
    String statusText;
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
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
              Text(
                '${amount.toStringAsFixed(2)} ₺',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isSelfUse ? Icons.account_balance_wallet : Icons.card_giftcard,
                size: 16,
                color: isSelfUse ? Colors.blue : Colors.green,
              ),
              const SizedBox(width: 4),
              Text(
                isSelfUse ? 'Self-Use Check' : 'Gift Voucher',
                style: TextStyle(
                  color: isSelfUse ? Colors.blue : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (isReceived) ...[
            const SizedBox(height: 4),
            Text(
              'From: $senderEmail',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${isReceived ? 'Received' : 'Created'}: ${createdAt.toString().split('.')[0]}',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Discount',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${availableDiscount.toStringAsFixed(2)} ₺',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (totalGiftCheckAmount > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Gift Check Amount',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalGiftCheckAmount.toStringAsFixed(2)} ₺',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createGiftVoucher,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.card_giftcard),
              label: const Text('Create Gift Voucher'),
            ),
            if (_receivedVouchers.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Received Gift Vouchers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ..._receivedVouchers.map(
                (voucher) => _buildVoucherCard(voucher, true),
              ),
            ],
            if (_createdChecks.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Created Gift Vouchers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ..._createdChecks.map((check) => _buildVoucherCard(check, false)),
            ],
          ],
        ),
      ),
    );
  }
}
