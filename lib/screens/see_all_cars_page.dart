import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/car_model.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class SeeAllCarsPage extends StatelessWidget {
  final String categoryTitle;
  final List<Car> cars;

  const SeeAllCarsPage({
    super.key,
    required this.categoryTitle,
    required this.cars,
  });

  @override
  Widget build(BuildContext context) {
    // Tema durumunu kontrol et
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryTitle),
        backgroundColor: isDarkMode ? AppColors.secondary : AppColors.primary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: cars.length,
        itemBuilder: (context, index) {
          final car = cars[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => CarDetailScreen(carId: car.id ?? 'unknown'),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color:
                    isDarkMode ? AppColors.cardColorDark : AppColors.cardColor,
                borderRadius: BorderRadius.circular(16),
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
                    tag: car.name,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.network(
                        car.image,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image_not_supported),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${car.brand} ${car.name}',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        Row(
                          children: [
                            Text(
                              PriceFormatter.formatPrice(
                                car.discountedPrice ?? car.price,
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    isDarkMode
                                        ? Colors.greenAccent
                                        : Colors.green,
                              ),
                            ),
                            if (car.discountedPrice != null) ...[
                              const SizedBox(width: 4),
                              Text(
                                PriceFormatter.formatPrice(car.price),
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              'per day',
                              style: TextStyle(color: Colors.grey),
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
      ),
    );
  }
}
