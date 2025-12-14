import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RentalService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Checks if the current user has rented this vehicle
  static Future<bool> hasUserRentedVehicle(String vehicleId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final rentalsQuery =
          await _firestore
              .collection('rentals')
              .where('userId', isEqualTo: user.uid)
              .where('vehicleId', isEqualTo: vehicleId)
              .where('status', whereIn: ['completed', 'active'])
              .get();

      return rentalsQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking rental status: $e');
      return false;
    }
  }

  /// Gets all vehicles rented by the current user
  static Future<List<String>> getUserRentedVehicles() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final rentalsQuery =
          await _firestore
              .collection('rentals')
              .where('userId', isEqualTo: user.uid)
              .where('status', whereIn: ['completed', 'active'])
              .get();

      return rentalsQuery.docs
          .map((doc) => doc.data()['vehicleId'] as String)
          .toList();
    } catch (e) {
      print('Error getting user rentals: $e');
      return [];
    }
  }
}
