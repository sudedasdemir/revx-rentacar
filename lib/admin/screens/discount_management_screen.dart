import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../car_model.dart';
import 'package:intl/intl.dart';

class DiscountManagementScreen extends StatefulWidget {
  const DiscountManagementScreen({Key? key}) : super(key: key);

  @override
  _DiscountManagementScreenState createState() =>
      _DiscountManagementScreenState();
}

class _DiscountManagementScreenState extends State<DiscountManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(symbol: '\₺', decimalDigits: 2);
  final _percentFormat = NumberFormat.decimalPercentPattern(decimalDigits: 1);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateDiscount(String carId, double? discountPercentage) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final carDoc = await _firestore.collection('cars').doc(carId).get();
      final carData = carDoc.data();

      if (carData != null) {
        final double basePrice =
            carData['price'] is num
                ? (carData['price'] as num).toDouble()
                : double.tryParse(carData['price'].toString()) ?? 0.0;

        final double? discountedPrice =
            discountPercentage != null && discountPercentage > 0
                ? (basePrice * (100 - discountPercentage) / 100)
                : null;

        await _firestore.collection('cars').doc(carId).update({
          'discountPercentage': discountPercentage,
          'discountedPrice': discountedPrice,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              discountPercentage != null && discountPercentage > 0
                  ? 'Discount applied successfully!'
                  : 'Discount removed successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating discount: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _matchesSearch(Car car) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    return car.name.toLowerCase().contains(query) ||
        car.brand.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discount Management')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by car name or brand...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                        : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('cars').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cars =
                    snapshot.data!.docs
                        .map((doc) => Car.fromFirestore(doc))
                        .where(_matchesSearch)
                        .toList();

                if (cars.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'No cars found'
                          : 'No cars found matching "$_searchQuery"',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cars.length,
                  itemBuilder: (context, index) {
                    final car = cars[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (car.image.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      car.image,
                                      width: 140,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${car.brand} ${car.name}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Base Price: ${_currencyFormat.format(car.price)}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyLarge,
                                      ),
                                      if (car.discountPercentage != null &&
                                          car.discountPercentage! > 0) ...[
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(
                                              0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.green,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Discount: ${_percentFormat.format(car.discountPercentage! / 100)}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyLarge?.copyWith(
                                                  color: Colors.green,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed:
                                                    () => _updateDiscount(
                                                      car.id,
                                                      null,
                                                    ),
                                                tooltip: 'Remove Discount',
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        decoration: InputDecoration(
                                          labelText: 'New Discount Percentage',
                                          hintText: 'Enter discount (0-100)',
                                          border: const OutlineInputBorder(),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onSubmitted: (value) {
                                          final discount = double.tryParse(
                                            value,
                                          );
                                          if (discount != null &&
                                              discount >= 0 &&
                                              discount <= 100) {
                                            _updateDiscount(car.id, discount);
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Please enter a valid discount percentage (0-100)',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
