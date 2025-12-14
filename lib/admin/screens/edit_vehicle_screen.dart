import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditVehicleScreen extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicleData;

  const EditVehicleScreen({
    super.key,
    required this.vehicleId,
    required this.vehicleData,
  });

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedStatus;

  late TextEditingController nameController;
  late TextEditingController brandController;
  late TextEditingController priceController;
  late TextEditingController imageController;
  late TextEditingController ratingController;
  late TextEditingController transmissionController;
  late TextEditingController fuelTypeController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;
  late TextEditingController descriptionController;
  late TextEditingController featuresController;
  late TextEditingController topSpeedController;
  late TextEditingController categoryController;
  late TextEditingController stockController;

  Map<String, String> specifications = {};
  final specificationsKeyController = TextEditingController();
  final specificationsValueController = TextEditingController();

  @override
  void initState() {
    final v = widget.vehicleData;
    nameController = TextEditingController(text: v['name']);
    brandController = TextEditingController(text: v['brand']);
    priceController = TextEditingController(text: v['price'].toString());
    imageController = TextEditingController(text: v['image']);
    ratingController = TextEditingController(text: v['rating'].toString());
    transmissionController = TextEditingController(text: v['transmission']);
    fuelTypeController = TextEditingController(text: v['fuelType']);
    latitudeController = TextEditingController(text: v['latitude'].toString());
    longitudeController = TextEditingController(
      text: v['longitude'].toString(),
    );
    descriptionController = TextEditingController(text: v['description']);
    featuresController = TextEditingController(
      text: (v['features'] as List<dynamic>).whereType<String>().join(', '),
    );
    topSpeedController = TextEditingController(text: v['topSpeed']);
    categoryController = TextEditingController(text: v['category']);
    stockController = TextEditingController(
      text: v['stock']?.toString() ?? '0',
    );
    specifications = Map<String, String>.from(v['specifications'] ?? {});
    super.initState();
    selectedStatus = v['status'] ?? 'available';
  }

  void _addSpecification() {
    if (specificationsKeyController.text.isNotEmpty &&
        specificationsValueController.text.isNotEmpty) {
      setState(() {
        specifications[specificationsKeyController.text] =
            specificationsValueController.text;
        specificationsKeyController.clear();
        specificationsValueController.clear();
      });
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final stock = int.parse(stockController.text.trim());

        await FirebaseFirestore.instance
            .collection('cars')
            .doc(widget.vehicleId)
            .update({
              'name': nameController.text.trim(),
              'brand': brandController.text.trim(),
              'price': int.parse(priceController.text.trim()),
              'image': imageController.text.trim(),
              'rating': double.parse(ratingController.text.trim()),
              'transmission': transmissionController.text.trim(),
              'fuelType': fuelTypeController.text.trim(),
              'latitude': double.parse(latitudeController.text.trim()),
              'longitude': double.parse(longitudeController.text.trim()),
              'description': descriptionController.text.trim(),
              'features':
                  featuresController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList(),
              'specifications': specifications,
              'topSpeed': topSpeedController.text.trim(),
              'category': categoryController.text.trim(),
              'status': selectedStatus,
              'stock': stock,
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle updated successfully')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    brandController.dispose();
    priceController.dispose();
    imageController.dispose();
    ratingController.dispose();
    transmissionController.dispose();
    fuelTypeController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    descriptionController.dispose();
    featuresController.dispose();
    specificationsKeyController.dispose();
    specificationsValueController.dispose();
    topSpeedController.dispose();
    categoryController.dispose();
    stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Vehicle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              TextFormField(
                controller: brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
                validator: _required,
              ),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: imageController,
                decoration: const InputDecoration(labelText: 'Image Path'),
                validator: _required,
              ),
              TextFormField(
                controller: ratingController,
                decoration: const InputDecoration(labelText: 'Rating'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: transmissionController,
                decoration: const InputDecoration(labelText: 'Transmission'),
                validator: _required,
              ),
              TextFormField(
                controller: fuelTypeController,
                decoration: const InputDecoration(labelText: 'Fuel Type'),
                validator: _required,
              ),
              TextFormField(
                controller: latitudeController,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: TextInputType.number,
                validator: _required,
              ),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: _required,
              ),
              TextFormField(
                controller: featuresController,
                decoration: const InputDecoration(
                  labelText: 'Features (comma-separated)',
                ),
                validator: _required,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: specificationsKeyController,
                      decoration: const InputDecoration(labelText: 'Spec Key'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: specificationsValueController,
                      decoration: const InputDecoration(
                        labelText: 'Spec Value',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSpecification,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children:
                    specifications.entries.map((entry) {
                      return Chip(
                        label: Text('${entry.key}: ${entry.value}'),
                        onDeleted: () {
                          setState(() {
                            specifications.remove(entry.key);
                          });
                        },
                        deleteIcon: const Icon(Icons.close),
                        deleteIconColor: Colors.white,
                        backgroundColor: Colors.grey[800],
                        labelStyle: const TextStyle(color: Colors.white),
                      );
                    }).toList(),
              ),

              TextFormField(
                controller: topSpeedController,
                decoration: const InputDecoration(labelText: 'Top Speed'),
                validator: _required,
              ),
              TextFormField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: _required,
              ),
              TextFormField(
                controller: stockController,
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter stock';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'available',
                    child: Text('Available'),
                  ),
                  DropdownMenuItem(value: 'rented', child: Text('Rented')),
                  DropdownMenuItem(
                    value: 'under maintenance',
                    child: Text('Under Maintenance'),
                  ),
                  DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedStatus = value;
                  });
                },
                validator: _required,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Update Vehicle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required field' : null;
  }
}
