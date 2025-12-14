import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class BrandCarsPage extends StatelessWidget {
  final String selectedBrand;

  const BrandCarsPage({super.key, required this.selectedBrand});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cars by $selectedBrand'),
        backgroundColor: AppColors.secondary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            selectedBrand == 'All'
                ? FirebaseFirestore.instance.collection('cars').snapshots()
                : FirebaseFirestore.instance
                    .collection('cars')
                    .where('brand', isEqualTo: selectedBrand)
                    .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No cars found.'));
          }

          final cars = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cars.length,
            itemBuilder: (context, index) {
              final car = cars[index];
              final carData = car.data() as Map<String, dynamic>;
              final price = carData['price']?.toDouble() ?? 0.0;
              final discountPercentage =
                  carData['discountPercentage']?.toDouble();
              final discountedPrice =
                  discountPercentage != null
                      ? (price * (100 - discountPercentage) / 100)
                      : null;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              CarDetailScreen(carId: car.id), // dinamik ID
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: carData['name'] ?? '',
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: Image.network(
                            carData['image'] ?? '',
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                          : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading image: $error');
                              print('Image URL: ${carData['image']}');
                              return Container(
                                height: 150,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 32,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${carData['brand']} ${carData['name']}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  PriceFormatter.formatPrice(
                                    discountedPrice ?? price,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (discountedPrice != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    PriceFormatter.formatPrice(price),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 8),
                                const Text(
                                  'per day',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
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
