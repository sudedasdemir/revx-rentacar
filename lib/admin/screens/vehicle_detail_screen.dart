import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/admin/screens/edit_vehicle_screen.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class VehicleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> vehicleData;
  final String vehicleId;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleData,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context) {
    final features = vehicleData['features'] as List<dynamic>? ?? [];
    final specifications =
        vehicleData['specifications'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleData['name'] ?? 'Vehicle Detail'),
        backgroundColor: AppColors.secondary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (vehicleData['images'] != null &&
                (vehicleData['images'] as List).isNotEmpty)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: (vehicleData['images'] as List).length,
                  itemBuilder: (context, index) {
                    final imageUrl = vehicleData['images'][index];
                    return imageUrl.toString().startsWith('http')
                        ? Image.network(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error');
                            return const Icon(Icons.image_not_supported);
                          },
                        )
                        : Image.asset(
                          imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.image_not_supported),
                        );
                  },
                ),
              )
            else if (vehicleData['image'] != null &&
                vehicleData['image'].toString().isNotEmpty)
              vehicleData['image'].toString().startsWith('http')
                  ? Image.network(
                    vehicleData['image'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return const Icon(Icons.image_not_supported);
                    },
                  )
                  : Image.asset(
                    vehicleData['image'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.image_not_supported),
                  )
            else
              const SizedBox(height: 200, child: Placeholder()),

            const SizedBox(height: 16),

            // Name & Brand
            Text(
              '${vehicleData['brand']} ${vehicleData['name']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Category: ${vehicleData['category'] ?? 'N/A'}'),

            const SizedBox(height: 12),

            Text(
              'Price: ${PriceFormatter.formatPrice((vehicleData['price'] ?? 0) is int ? (vehicleData['price'] ?? 0).toDouble() : (vehicleData['price'] ?? 0) as double)}',
            ),
            Text('Rating: ${vehicleData['rating']}'),
            Text('Transmission: ${vehicleData['transmission']}'),
            Text('Fuel Type: ${vehicleData['fuelType']}'),
            Text('Top Speed: ${vehicleData['topSpeed']}'),
            Text(
              'Location: (${vehicleData['latitude']}, ${vehicleData['longitude']})',
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              'Description:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(vehicleData['description'] ?? ''),

            const SizedBox(height: 12),

            // Features
            if (features.isNotEmpty) ...[
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children:
                    features
                        .map((f) => Chip(label: Text(f.toString())))
                        .toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Specifications
            if (specifications.isNotEmpty) ...[
              const Text(
                'Specifications:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...specifications.entries.map((entry) {
                return Text('${entry.key}: ${entry.value}');
              }).toList(),
            ],

            const SizedBox(height: 24),

            // Edit Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => EditVehicleScreen(
                            vehicleId: vehicleId,
                            vehicleData: vehicleData,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Vehicle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
