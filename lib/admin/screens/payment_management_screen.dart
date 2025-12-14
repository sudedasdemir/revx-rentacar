import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PaymentManagementScreen extends StatelessWidget {
  final CollectionReference paymentsRef = FirebaseFirestore.instance.collection(
    'payments',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Management'),
        centerTitle: true,
      ),
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

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text('Amount: \$${data['totalPrice']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Method: ${data['paymentMethod']}'),
                      Text('User: ${data['userName'] ?? 'N/A'}'),
                      Text('Status: ${data['status']}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // Ödeme detay sayfasına yönlendir
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
