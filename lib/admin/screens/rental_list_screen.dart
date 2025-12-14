import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class RentalListScreen extends StatelessWidget {
  const RentalListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rental Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rentals = snapshot.data?.docs ?? [];

          if (rentals.isEmpty) {
            return const Center(child: Text('No rentals found.'));
          }

          return ListView.builder(
            itemCount: rentals.length,
            itemBuilder: (context, index) {
              final rental = rentals[index];
              final data = rental.data() as Map<String, dynamic>;

              return ListTile(
                title: Text('Rental: ${rental.id}'),
                subtitle: Text(
                  'Status: ${data['status'] ?? 'unknown'}\nTotal: ${PriceFormatter.formatPrice(data['totalPrice'] ?? 0)}',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/rental_detail',
                    arguments: rental.id,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
