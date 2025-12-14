import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  final String id;
  final String name;
  final String brand;
  final double price;
  final double? discountPercentage;
  final double? discountedPrice;
  final String image;
  final double rating;
  final String transmission;
  final String fuelType;
  final double latitude;
  final double longitude;
  final String description;
  final List<String> features;
  final Map<String, String> specifications;
  final String topSpeed;
  final String? category;
  final bool isInMaintenance; // Add maintenance status
  final int totalStock;
  final int availableStock;

  Car({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    this.discountPercentage,
    this.discountedPrice,
    required this.image,
    required this.rating,
    required this.transmission,
    required this.fuelType,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.features,
    required this.specifications,
    required this.topSpeed,
    this.category,
    this.isInMaintenance = false, // Default to false
    required this.totalStock,
    required this.availableStock,
  });

  factory Car.fromMap(Map<String, dynamic> map) {
    final double basePrice =
        map['price'] is num
            ? (map['price'] as num).toDouble()
            : double.tryParse(map['price'].toString()) ?? 0.0;

    final double? discountPercentage =
        map['discountPercentage'] is num
            ? (map['discountPercentage'] as num).toDouble()
            : double.tryParse(map['discountPercentage']?.toString() ?? '');

    final double? discountedPrice =
        discountPercentage != null && discountPercentage > 0
            ? (basePrice * (100 - discountPercentage) / 100)
            : null;

    return Car(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      price: basePrice,
      discountPercentage: discountPercentage,
      discountedPrice: discountedPrice,
      image: map['image'] ?? '',
      rating:
          map['rating'] is double
              ? map['rating']
              : double.tryParse(map['rating'].toString()) ??
                  0.0, // Convert to double
      transmission: map['transmission'] ?? '',
      fuelType: map['fuelType'] ?? '',
      latitude:
          map['latitude'] is double
              ? map['latitude']
              : double.tryParse(map['latitude'].toString()) ??
                  0.0, // Convert to double
      longitude:
          map['longitude'] is double
              ? map['longitude']
              : double.tryParse(map['longitude'].toString()) ??
                  0.0, // Convert to double
      description: map['description'] ?? '',
      features: List<String>.from(map['features'] ?? []),
      specifications: Map<String, String>.from(map['specifications'] ?? {}),
      topSpeed: map['topSpeed'] ?? '',
      category: map['category'] as String?,
      isInMaintenance: map['isInMaintenance'] ?? false,
      totalStock: map['totalStock'] ?? 0,
      availableStock: map['availableStock'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brand': brand,
      'price': price,
      'discountPercentage': discountPercentage,
      'discountedPrice': discountedPrice,
      'image': image,
      'rating': rating,
      'transmission': transmission,
      'fuelType': fuelType,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'features': features,
      'specifications': specifications,
      'topSpeed': topSpeed,
      'category': category,
      'isInMaintenance': isInMaintenance,
      'totalStock': totalStock,
      'availableStock': availableStock,
    };
  }

  factory Car.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final double basePrice =
        data['price'] is num
            ? (data['price'] as num).toDouble()
            : double.tryParse(data['price'].toString()) ?? 0.0;

    final double? discountPercentage =
        data['discountPercentage'] is num
            ? (data['discountPercentage'] as num).toDouble()
            : double.tryParse(data['discountPercentage']?.toString() ?? '');

    final double? discountedPrice =
        discountPercentage != null && discountPercentage > 0
            ? (basePrice * (100 - discountPercentage) / 100)
            : null;

    print('Car.fromFirestore: Processing document with ID: ${doc.id}');
    final int parsedStock = int.tryParse(data['stock']?.toString() ?? '') ?? 0;
    print('Car.fromFirestore: Parsed stock value: $parsedStock');

    return Car(
      id: doc.id,
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      price: basePrice,
      discountPercentage: discountPercentage,
      discountedPrice: discountedPrice,
      image: data['image'] ?? '',
      rating:
          data['rating'] is double
              ? data['rating']
              : double.tryParse(data['rating'].toString()) ?? 0.0,
      transmission: data['transmission'] ?? '',
      fuelType: data['fuelType'] ?? '',
      latitude:
          data['latitude'] is double
              ? data['latitude']
              : double.tryParse(data['latitude'].toString()) ?? 0.0,
      longitude:
          data['longitude'] is double
              ? data['longitude']
              : double.tryParse(data['longitude'].toString()) ?? 0.0,
      description: data['description'] ?? '',
      features: List<String>.from(data['features'] ?? []),
      specifications: Map<String, String>.from(data['specifications'] ?? {}),
      topSpeed: data['topSpeed'] ?? '',
      category: data['category'] as String?,
      isInMaintenance: data['isInMaintenance'] ?? false,
      totalStock: parsedStock,
      availableStock: parsedStock,
    );
  }
}
