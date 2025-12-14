import 'dart:async';
import 'package:firebase_app/admin/screens/vehicle_maintenance_screen.dart';

class MaintenanceService {
  static final MaintenanceService _instance = MaintenanceService._internal();
  Timer? _timer;

  factory MaintenanceService() {
    return _instance;
  }

  MaintenanceService._internal();

  void startPeriodicCheck() {
    // Check immediately when starting
    VehicleMaintenanceScreen.checkMaintenanceStatus();

    // Then check every hour
    _timer = Timer.periodic(const Duration(hours: 1), (timer) {
      VehicleMaintenanceScreen.checkMaintenanceStatus();
    });
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }
}
