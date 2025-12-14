import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class PaymentListScreen extends StatelessWidget {
  final CollectionReference paymentsRef = FirebaseFirestore.instance.collection(
    'payments',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment List')),
      body: StreamBuilder<QuerySnapshot>(
        stream: paymentsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text('Error loading payments.'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          final payments = snapshot.data!.docs;

          if (payments.isEmpty) {
            return const Center(child: Text('No payments found.'));
          }

          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              final data = payment.data() as Map<String, dynamic>;

              final finalAmount =
                  (data['finalAmount'] as num?)?.toDouble() ??
                  (data['amount'] as num?)?.toDouble() ??
                  0.0;

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text('Payment ID: ${payment.id}'),
                  subtitle: Text(
                    'Amount Paid: ${PriceFormatter.formatPrice(finalAmount)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/payment_detail',
                        arguments: payment.id,
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
