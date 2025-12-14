import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    this.carId,
  });

  final String id;
  final String imageUrl;
  final DateTime createdAt;
  final String? carId;

  factory BannerModel.fromFirestore(Map<String, dynamic> data, String id) {
    try {
      if (data['imageUrl'] == null || data['imageUrl'].toString().isEmpty) {
        throw Exception('Invalid image URL');
      }

      return BannerModel(
        id: id,
        imageUrl: data['imageUrl'] as String,
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        carId: data['carId'] as String?,
      );
    } catch (e) {
      print('Error creating BannerModel: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      if (carId != null) 'carId': carId,
    };
  }
}
