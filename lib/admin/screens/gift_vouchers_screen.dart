import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';

class GiftVouchersScreen extends StatefulWidget {
  const GiftVouchersScreen({super.key});

  @override
  State<GiftVouchersScreen> createState() => _GiftVouchersScreenState();
}

class _GiftVouchersScreenState extends State<GiftVouchersScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateVoucherStatus(String voucherId, String status) async {
    try {
      final voucherDoc =
          await _firestore.collection('gift_vouchers').doc(voucherId).get();
      final voucherData = voucherDoc.data();

      if (voucherData == null) return;

      final amount = voucherData['amount'] ?? 0.0;
      final recipientEmail = voucherData['recipientEmail'];
      final senderId = voucherData['senderId'];

      if (status == 'approved') {
        // Update the voucher status
        await _firestore.collection('gift_vouchers').doc(voucherId).update({
          'status': 'approved',
          'isApproved': true,
          'approvedAt': FieldValue.serverTimestamp(),
        });

        // Add the voucher to the recipient's gift checks
        final recipientUser =
            await _firestore
                .collection('users')
                .where('email', isEqualTo: recipientEmail)
                .get();

        if (recipientUser.docs.isNotEmpty) {
          final recipientId = recipientUser.docs.first.id;
          final giftCheckRef = _firestore
              .collection('gift_checks')
              .doc(recipientId);

          await _firestore.runTransaction((transaction) async {
            final giftCheckDoc = await transaction.get(giftCheckRef);

            if (giftCheckDoc.exists) {
              transaction.update(giftCheckRef, {
                'amount': FieldValue.increment(amount),
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            } else {
              transaction.set(giftCheckRef, {
                'amount': amount,
                'createdAt': FieldValue.serverTimestamp(),
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            }
          });
        }

        // If it's a wallet-based voucher, deduct from sender's wallet
        if (voucherData['type'] == 'wallet') {
          final walletAmountUsed = voucherData['walletAmountUsed'] ?? 0.0;
          if (walletAmountUsed > 0) {
            await _firestore.collection('gift_checks').doc(senderId).update({
              'amount': FieldValue.increment(-walletAmountUsed),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        }
      } else if (status == 'rejected') {
        await _firestore.collection('gift_vouchers').doc(voucherId).update({
          'status': 'rejected',
          'isApproved': false,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voucher ${status} successfully'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating voucher status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final amount = voucher['amount'] ?? 0.0;
    final status = voucher['status'] ?? 'pending';
    final recipientEmail = voucher['recipientEmail'] ?? '';
    final senderEmail = voucher['senderEmail'] ?? '';
    final message = voucher['message'] ?? '';
    final createdAt =
        (voucher['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final isSelfUse = voucher['isSelfUse'] ?? false;
    final type = voucher['type'] ?? 'purchase';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${amount.toStringAsFixed(2)} ₺',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        status == 'approved'
                            ? Colors.green.withOpacity(0.2)
                            : status == 'pending'
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color:
                          status == 'approved'
                              ? Colors.green
                              : status == 'pending'
                              ? Colors.orange
                              : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Type: ${isSelfUse ? 'Self-Use' : 'Gift'} Voucher'),
            Text('Payment Type: ${type == 'wallet' ? 'Wallet' : 'Purchase'}'),
            const SizedBox(height: 8),
            Text('From: $senderEmail'),
            Text('To: $recipientEmail'),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Message: $message'),
            ],
            Text(
              'Created: ${createdAt.toString().split('.')[0]}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        () => _updateVoucherStatus(voucher['id'], 'rejected'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed:
                        () => _updateVoucherStatus(voucher['id'], 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Vouchers'),
        backgroundColor: AppColors.secondary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gift Vouchers'),
            Tab(text: 'Self-Use Checks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Gift Vouchers Tab
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('gift_vouchers')
                    .where('isSelfUse', isEqualTo: false)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('Error in gift vouchers stream: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vouchers = snapshot.data?.docs ?? [];

              // Sort vouchers by createdAt in memory
              vouchers.sort((a, b) {
                final aDate =
                    (a.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                final bDate =
                    (b.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                if (aDate == null || bDate == null) return 0;
                return bDate.compareTo(aDate); // Descending order
              });

              if (vouchers.isEmpty) {
                return const Center(child: Text('No gift vouchers found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
                  final voucher = {
                    ...vouchers[index].data() as Map<String, dynamic>,
                    'id': vouchers[index].id,
                  };
                  return _buildVoucherCard(voucher);
                },
              );
            },
          ),
          // Self-Use Checks Tab
          StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('gift_vouchers')
                    .where('isSelfUse', isEqualTo: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                print('Error in self-use checks stream: ${snapshot.error}');
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vouchers = snapshot.data?.docs ?? [];

              // Sort vouchers by createdAt in memory
              vouchers.sort((a, b) {
                final aDate =
                    (a.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                final bDate =
                    (b.data() as Map<String, dynamic>)['createdAt']
                        as Timestamp?;
                if (aDate == null || bDate == null) return 0;
                return bDate.compareTo(aDate); // Descending order
              });

              if (vouchers.isEmpty) {
                return const Center(child: Text('No self-use checks found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
                  final voucher = {
                    ...vouchers[index].data() as Map<String, dynamic>,
                    'id': vouchers[index].id,
                  };
                  return _buildVoucherCard(voucher);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
