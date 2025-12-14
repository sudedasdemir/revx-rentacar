import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/car_model.dart';

class CarService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Firestore'dan araç verisini ID ile çekme
  Future<Car?> getCarById(String carId) async {
    try {
      // Fetch car data from Firestore using carId
      var carSnapshot =
          await FirebaseFirestore.instance.collection('cars').doc(carId).get();

      if (carSnapshot.exists) {
        return Car.fromFirestore(carSnapshot);
      } else {
        print("Car with ID $carId not found");
        return null;
      }
    } catch (e) {
      print("Error getting car by ID: $e");
      return null;
    }
  }
}
