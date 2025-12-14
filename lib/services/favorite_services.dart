import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoriteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addFavorite(String carId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('favorites').doc();
    await docRef.set({
      'userId': user.uid,
      'carId': carId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(String carId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final querySnapshot =
        await _firestore
            .collection('favorites')
            .where('userId', isEqualTo: user.uid)
            .where('carId', isEqualTo: carId)
            .get();

    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<bool> isFavorite(String carId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final querySnapshot =
        await _firestore
            .collection('favorites')
            .where('userId', isEqualTo: user.uid)
            .where('carId', isEqualTo: carId)
            .get();

    return querySnapshot.docs.isNotEmpty;
  }

  Stream<List<String>> getFavoriteCarIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => doc.data()['carId'] as String)
                  .toList(),
        );
  }
}
