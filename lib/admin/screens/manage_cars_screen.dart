import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/admin/screens/add_vehicle_screen.dart';
import 'package:firebase_app/admin/screens/vehicle_detail_screen.dart';
import 'package:firebase_app/admin/screens/vehicle_maintenance_screen.dart';

import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';

class ManageCarsScreen extends StatefulWidget {
  final String? initialCarId;

  const ManageCarsScreen({super.key, this.initialCarId});

  @override
  _ManageCarsScreenState createState() => _ManageCarsScreenState();
}

class _ManageCarsScreenState extends State<ManageCarsScreen> {
  String query = '';
  String selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialCarId != null) {
      query = widget.initialCarId!;
      _searchController.text = widget.initialCarId!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Vehicles'),
        backgroundColor: AppColors.secondary,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Vehicle',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama alanı
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Search by name or brand...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Kategori filtreleme
          DropdownButton<String>(
            value: selectedCategory,
            onChanged: (String? newValue) {
              setState(() {
                selectedCategory = newValue!;
              });
            },
            items:
                <String>[
                  'All',
                  'Porsche',
                  'Maserati',
                  'BMW',
                  'Mercedes',
                  'Mercedes-Benz',
                  'Tesla',
                  'Honda',
                  'Toyota',
                  'Audi',
                  'Hyundai',
                  'Kia',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No vehicles found'));
                }

                // Filter cars based on both search query and category
                final cars =
                    snapshot.data!.docs.where((doc) {
                      final car = doc.data() as Map<String, dynamic>;
                      final brand =
                          (car['brand'] ?? '').toString().toLowerCase();
                      final name = (car['name'] ?? '').toString().toLowerCase();
                      final carId = doc.id.toLowerCase(); // Get car ID
                      final searchQuery = query.toLowerCase();

                      // Check if car matches search query or car ID
                      final matchesSearch =
                          query.isEmpty ||
                          brand.contains(searchQuery) ||
                          name.contains(searchQuery) ||
                          carId.contains(
                            searchQuery,
                          ); // Include carId in search

                      // Check if car matches selected category
                      final matchesCategory =
                          selectedCategory == 'All' ||
                          car['brand'] == selectedCategory;

                      return matchesSearch && matchesCategory;
                    }).toList();

                if (cars.isEmpty) {
                  return Center(
                    child: Text(
                      query.isNotEmpty
                          ? 'No vehicles match your search'
                          : selectedCategory != 'All'
                          ? 'No vehicles in this category'
                          : 'No vehicles available',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    final car = cars[index].data() as Map<String, dynamic>;
                    final vehicleId = cars[index].id;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading:
                            car['image'] != null
                                ? car['image'].toString().startsWith('http')
                                    ? Image.network(
                                      car['image'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const SizedBox(
                                          width: 60,
                                          height: 60,
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        print('Error loading image: $error');
                                        return const Icon(
                                          Icons.image_not_supported,
                                        );
                                      },
                                    )
                                    : Image.asset(
                                      car['image'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                          ),
                                    )
                                : const Icon(Icons.directions_car, size: 40),
                        title: Text(
                          '${car['brand']} ${car['name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Category: ${car['category'] ?? 'N/A'}\nFuel: ${car['fuelType'] ?? '-'} | Transmission: ${car['transmission'] ?? '-'}\nStock: ${car['stock'] ?? 0}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Stock management button
                            IconButton(
                              icon: const Icon(Icons.inventory),
                              tooltip: 'Manage Stock',
                              onPressed: () {
                                _showStockManagementDialog(
                                  context,
                                  vehicleId,
                                  car['stock'] ?? 0,
                                );
                              },
                            ),
                            // Maintenance button
                            IconButton(
                              icon: Icon(
                                Icons.build,
                                color:
                                    car['isInMaintenance'] == true
                                        ? Colors.red
                                        : Colors.grey,
                              ),
                              tooltip: 'Maintenance',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => VehicleMaintenanceScreen(
                                          carId: vehicleId,
                                        ),
                                  ),
                                );
                              },
                            ),
                            // Delete button
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () async {
                                // Show confirmation dialog
                                final shouldDelete = await showDialog<bool>(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Delete Vehicle'),
                                        content: const Text(
                                          'Are you sure you want to delete this vehicle?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                );

                                if (shouldDelete == true) {
                                  await FirebaseFirestore.instance
                                      .collection('cars')
                                      .doc(vehicleId)
                                      .delete();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vehicle deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => VehicleDetailScreen(
                                    vehicleId: vehicleId,
                                    vehicleData: car,
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStockManagementDialog(
    BuildContext context,
    String vehicleId,
    int currentStock,
  ) {
    final stockController = TextEditingController(
      text: currentStock.toString(),
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Manage Stock'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Available Stock',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newStock = int.tryParse(stockController.text);
                  if (newStock != null && newStock >= 0) {
                    await FirebaseFirestore.instance
                        .collection('cars')
                        .doc(vehicleId)
                        .update({'stock': newStock});
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Stock updated successfully'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }
}
