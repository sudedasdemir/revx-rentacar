// lib/classes/booking.dart
class Booking {
  final String carName;
  final String carBrand;
  final double carPrice;
  final DateTime startDate;
  final DateTime endDate;

  Booking({
    required this.carName,
    required this.carBrand,
    required this.carPrice,
    required this.startDate,
    required this.endDate,
  });
}
