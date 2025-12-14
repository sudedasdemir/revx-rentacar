import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/features/home_feature/data/models/banner_model.dart';

class BannerRepository {
  final CollectionReference _bannersRef = FirebaseFirestore.instance.collection(
    'banners',
  );

  Stream<List<BannerModel>> getBanners() {
    try {
      return _bannersRef
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            final banners =
                snapshot.docs
                    .map((doc) {
                      try {
                        final data = doc.data() as Map<String, dynamic>;
                        return BannerModel.fromFirestore(data, doc.id);
                      } catch (e) {
                        print('Error parsing document ${doc.id}: $e');
                        return null;
                      }
                    })
                    .whereType<BannerModel>()
                    .toList();

            return banners;
          })
          .handleError((error) {
            print('Error in getBanners stream: $error');
            return <BannerModel>[];
          });
    } catch (e) {
      print('Error in getBanners: $e');
      return Stream.value([]);
    }
  }

  Future<void> addBanner(String imageUrl, {String? carId}) async {
    try {
      if (imageUrl.isEmpty) {
        throw Exception('Image URL cannot be empty');
      }

      final Map<String, dynamic> data = {
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        if (carId != null) 'carId': carId,
      };

      await _bannersRef.add(data);
    } catch (e) {
      print('Error adding banner: $e');
      rethrow;
    }
  }

  Future<void> deleteBanner(String id) async {
    try {
      final docSnapshot = await _bannersRef.doc(id).get();
      if (!docSnapshot.exists) {
        throw Exception('Banner not found');
      }

      await _bannersRef.doc(id).delete();
    } catch (e) {
      print('Error deleting banner: $e');
      rethrow;
    }
  }

  void dispose() {
    // No need to dispose anything as we're using Firestore's built-in stream management
  }
}
