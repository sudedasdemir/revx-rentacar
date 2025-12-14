import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class PaymentDetailScreen extends StatefulWidget {
  final String paymentId;

  const PaymentDetailScreen({Key? key, required this.paymentId})
    : super(key: key);

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  DocumentSnapshot? paymentData;
  String selectedStatus = "";

  final List<String> statusOptions = ['paid', 'pending', 'cancelled'];

  @override
  void initState() {
    super.initState();
    fetchPaymentDetails();
  }

  // Ödeme detaylarını Firestore'dan çekme
  Future<void> fetchPaymentDetails() async {
    final paymentDoc =
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(widget.paymentId)
            .get();

    if (paymentDoc.exists) {
      setState(() {
        paymentData = paymentDoc;
        selectedStatus = paymentDoc['status'].toString().toLowerCase();
      });
    }
  }

  // Ödeme durumunu güncelleme
  Future<void> updatePaymentStatus() async {
    await FirebaseFirestore.instance
        .collection('payments')
        .doc(widget.paymentId)
        .update({'status': selectedStatus});

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Payment status updated.")));
  }

  @override
  Widget build(BuildContext context) {
    if (paymentData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Safely get payment data with null checks
    final paymentMap = paymentData!.data() as Map<String, dynamic>? ?? {};

    // Amount conversion with safe fallback
    final double totalAmount =
        (paymentMap['amount'] as num?)?.toDouble() ?? 0.0;
    final double voucherAmount =
        (paymentMap['voucherAmount'] as num?)?.toDouble() ?? 0.0;
    final double finalAmount =
        (paymentMap['finalAmount'] as num?)?.toDouble() ?? totalAmount;

    // Safely get other fields with fallbacks
    final String paymentMethod =
        paymentMap['paymentMethod']?.toString() ?? 'N/A';
    final String userName =
        paymentMap['userName']?.toString() ??
        paymentMap['userEmail']?.toString() ??
        paymentMap['userId']?.toString() ??
        'N/A';
    final String status = paymentMap['status']?.toString() ?? 'pending';

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Payment Information",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Original Price:",
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          PriceFormatter.formatPrice(totalAmount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (voucherAmount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Voucher Applied:",
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            PriceFormatter.formatPrice(voucherAmount),
                            style: const TextStyle(
                              fontSize: 16,
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
                        const Text(
                          "Final Amount Paid:",
                          style: TextStyle(fontSize: 16),
                        ),
                        Text(
                          PriceFormatter.formatPrice(finalAmount),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      "Payment Method: $paymentMethod",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "User: $userName",
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Current Status: ${status.toUpperCase()}",
                      style: const TextStyle(fontSize: 16),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value:
                          statusOptions.contains(selectedStatus)
                              ? selectedStatus
                              : statusOptions[0],
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
                      decoration: const InputDecoration(
                        labelText: "Update Payment Status",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          selectedStatus != status ? updatePaymentStatus : null,
                      child: const Text("Update Status"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
