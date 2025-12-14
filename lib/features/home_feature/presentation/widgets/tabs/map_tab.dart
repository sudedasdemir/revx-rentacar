import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class MapTab extends StatefulWidget {
  const MapTab({Key? key}) : super(key: key);

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  static const double MAX_DISTANCE_KM = 5.0;
  GoogleMapController? mapController;
  LatLng? _userLocation;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<Map<String, dynamic>> _nearbyCars = [];
  List<Map<String, dynamic>> _allCars = [];
  BitmapDescriptor? availableIcon;
  BitmapDescriptor? maintenanceIcon;
  BitmapDescriptor? unavailableIcon;
  bool showOilStations = false;
  bool showAirports = false;
  bool showParking = false;
  double _maxDistanceFilter = 10.0;
  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  bool _showAllVehicles = false;
  bool? _isCorporate;
  String? _selectedCarId;
  bool _isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _checkUserType();
    _initializeMap();
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      setState(() {
        _isCorporate = (doc.data()?['role'] ?? 'user') == 'corporate';
      });
    }
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isLoading = true;
        _isError = false;
        _errorMessage = null;
      });

      await _loadCustomIcons();
      await _fetchUserLocation();
      if (_userLocation != null) {
        await _fetchCarsFromFirestore();
      } else {
        setState(() {
          _isError = true;
          _errorMessage =
              'Unable to get your location. Please check location permissions.';
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCustomIcons() async {
    try {
      availableIcon = await BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
      maintenanceIcon = await BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueYellow,
      );
      unavailableIcon = await BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueRed,
      );
    } catch (e) {
      print('Error loading marker icons: $e');
      availableIcon = BitmapDescriptor.defaultMarker;
      maintenanceIcon = BitmapDescriptor.defaultMarker;
      unavailableIcon = BitmapDescriptor.defaultMarker;
    }
  }

  Future<void> _fetchUserLocation() async {
    try {
      final location = Location();
      bool _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      PermissionStatus _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      final userLocation = await location.getLocation();
      if (userLocation.latitude == null || userLocation.longitude == null) {
        throw Exception('Invalid location data received');
      }

      setState(() {
        _userLocation = LatLng(userLocation.latitude!, userLocation.longitude!);
      });
    } catch (e) {
      print('Error getting location: $e');
      rethrow;
    }
  }

  Future<void> _fetchCarsFromFirestore() async {
    try {
      setState(() {
        _markers.clear();
        _nearbyCars.clear();
        _allCars.clear();
      });

      if (_userLocation == null) {
        throw Exception('User location not available');
      }

      // Add user location marker
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
      );

      final snapshot =
          await FirebaseFirestore.instance.collection('cars').get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isError = true;
          _errorMessage = 'No vehicles found in the database.';
        });
        return;
      }

      double minLat = _userLocation!.latitude;
      double maxLat = _userLocation!.latitude;
      double minLng = _userLocation!.longitude;
      double maxLng = _userLocation!.longitude;

      // Get current date in UTC
      final now = DateTime.now().toUtc();
      final today = DateTime.utc(now.year, now.month, now.day);

      // Process each vehicle only once
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final isInMaintenance = data['isInMaintenance'] ?? false;
        final carLatitude = (data['latitude'] as num?)?.toDouble();
        final carLongitude = (data['longitude'] as num?)?.toDouble();

        if (carLatitude == null || carLongitude == null) {
          print('Skipping car ${doc.id} due to missing location data');
          continue;
        }

        // Check if car is rented for today
        final bookingsSnapshot =
            await FirebaseFirestore.instance
                .collection('bookings')
                .where('carId', isEqualTo: doc.id)
                .where(
                  'status',
                  whereIn: ['active', 'ongoing', 'upcoming', 'confirmed'],
                )
                .get();

        bool isRentedToday = false;
        for (var booking in bookingsSnapshot.docs) {
          final bookingData = booking.data();
          final startDate =
              (bookingData['startDate'] as Timestamp).toDate().toUtc();
          final endDate =
              (bookingData['endDate'] as Timestamp).toDate().toUtc();

          // Check if today falls within the booking period
          if (today.isAfter(startDate.subtract(const Duration(days: 1))) &&
              today.isBefore(endDate.add(const Duration(days: 1)))) {
            isRentedToday = true;
            break;
          }
        }

        final carPosition = LatLng(carLatitude, carLongitude);
        final distance = _calculateDistance(_userLocation!, carPosition);

        BitmapDescriptor? icon;
        String status;
        Color statusColor;
        if (isInMaintenance) {
          icon = maintenanceIcon;
          status = 'In Maintenance';
          statusColor = Colors.orange;
        } else if (isRentedToday) {
          icon = unavailableIcon;
          status = 'Rented Today';
          statusColor = Colors.red;
        } else {
          icon = availableIcon;
          status = 'Available';
          statusColor = Colors.green;
        }

        final carData = {
          'id': doc.id,
          ...data,
          'isInMaintenance': isInMaintenance,
          'isAvailable': !isRentedToday && !isInMaintenance,
          'distance': distance,
          'position': carPosition,
          'status': status,
          'statusColor': statusColor,
        };

        // Add to all cars list
        _allCars.add(carData);

        // Add marker for the vehicle
        _markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: carPosition,
            icon: icon ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: '${data['brand']} ${data['name']}',
              snippet:
                  '${distance.toStringAsFixed(1)} km away\n${PriceFormatter.formatPrice(data['discountedPrice']?.toDouble() ?? data['price']?.toDouble() ?? 0)}/day - $status',
            ),
            onTap: () => _showCarPreview(carData),
          ),
        );

        // Update bounds for map
        minLat = min(minLat, carLatitude);
        maxLat = max(maxLat, carLatitude);
        minLng = min(minLng, carLongitude);
        maxLng = max(maxLng, carLongitude);

        // Add to nearby cars if within distance filter
        if (distance <= _maxDistanceFilter) {
          _nearbyCars.add(carData);
        }
      }

      // Sort cars by distance
      _allCars.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );
      _nearbyCars.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      // Center map on user location with all markers visible
      if (mapController != null && _markers.isNotEmpty) {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );

        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 50.0),
        );
      }

      setState(() {});
    } catch (e) {
      print('Error fetching cars: $e');
      setState(() {
        _isError = true;
        _errorMessage = 'Error loading vehicles: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchRoute(LatLng origin, LatLng destination) async {
    if (_isLoadingRoute) return;

    setState(() {
      _isLoadingRoute = true;
      _polylines.clear();
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=walking&key=AIzaSyDtt--eBHELVUh7auRJTV28Ceb2XTSS1wM',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final points = _decodePolyline(
            data['routes'][0]['overview_polyline']['points'],
          );
          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          // Fit the map to show the entire route
          if (mapController != null) {
            final bounds = LatLngBounds(
              southwest: LatLng(
                min(origin.latitude, destination.latitude),
                min(origin.longitude, destination.longitude),
              ),
              northeast: LatLng(
                max(origin.latitude, destination.latitude),
                max(origin.longitude, destination.longitude),
              ),
            );
            mapController!.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 50.0),
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching route: $e');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final p = LatLng(lat / 1E5, lng / 1E5);
      poly.add(p);
    }
    return poly;
  }

  void _showCarPreview(Map<String, dynamic> carData) {
    if (_userLocation == null) return;

    setState(() {
      _selectedCarId = carData['id'];
    });

    // Fetch and show route
    _fetchRoute(_userLocation!, carData['position']);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          carData['image'],
                          height: 100,
                          width: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              width: 120,
                              color: Colors.grey[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red[400],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Image Error',
                                    style: TextStyle(
                                      color: Colors.red[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${carData['brand']} ${carData['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: GestureDetector(
                                onTap:
                                    () => _openDirections(carData['position']),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${carData['distance'].toStringAsFixed(1)} km (${_estimateWalkingMinutes(carData['distance'])} min)',
                                        style: TextStyle(
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${PriceFormatter.formatPrice((carData['discountedPrice'] ?? carData['price'] ?? 0) is int ? (carData['discountedPrice'] ?? carData['price'] ?? 0).toDouble() : (carData['discountedPrice'] ?? carData['price'] ?? 0) as double)}/day',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                if (carData['discountedPrice'] != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '${PriceFormatter.formatPrice((carData['price'] ?? 0) is int ? (carData['price'] ?? 0).toDouble() : (carData['price'] ?? 0) as double)}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.7),
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  carData['isInMaintenance']
                                      ? Icons.build
                                      : carData['isAvailable']
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 16,
                                  color: carData['statusColor'],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  carData['status'],
                                  style: TextStyle(
                                    color: carData['statusColor'],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToCarDetail(carData);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _navigateToCarDetail(Map<String, dynamic> carData) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CarDetailScreen(carId: carData['id'])),
    );
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const earthRadius = 6371; // Kilometers
    final dLat = _degreesToRadians(end.latitude - start.latitude);
    final dLng = _degreesToRadians(end.longitude - start.longitude);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(start.latitude)) *
            cos(_degreesToRadians(end.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  Future<void> _fetchNearbyPlaces(String type) async {
    if (_userLocation == null) return;

    try {
      final random = Random();
      for (int i = 0; i < 5; i++) {
        final latOffset = (random.nextDouble() - 0.5) * 0.02;
        final lngOffset = (random.nextDouble() - 0.5) * 0.02;
        final lat = _userLocation!.latitude + latOffset;
        final lng = _userLocation!.longitude + lngOffset;
        final position = LatLng(lat, lng);

        final distance = _calculateDistance(_userLocation!, position);
        if (distance <= MAX_DISTANCE_KM) {
          String title;
          String snippet;
          BitmapDescriptor icon;

          switch (type) {
            case 'oil':
              title = 'Gas Station ${i + 1}';
              snippet = 'Open 24/7';
              icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet,
              );
              break;
            case 'airport':
              title = 'Airport ${i + 1}';
              snippet = 'International Airport';
              icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              );
              break;
            case 'parking':
              title = 'Parking Lot ${i + 1}';
              snippet = 'Available Spaces: ${random.nextInt(50)}';
              icon = BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueCyan,
              );
              break;
            default:
              continue;
          }

          _markers.add(
            Marker(
              markerId: MarkerId('$type-$i'),
              position: position,
              icon: icon,
              infoWindow: InfoWindow(title: title, snippet: snippet),
            ),
          );
        }
      }
      setState(() {});
    } catch (e) {
      print('Error fetching nearby places: $e');
    }
  }

  void _togglePlaceType(String type) {
    setState(() {
      switch (type) {
        case 'oil':
          showOilStations = !showOilStations;
          break;
        case 'airport':
          showAirports = !showAirports;
          break;
        case 'parking':
          showParking = !showParking;
          break;
      }
    });

    _markers.removeWhere((marker) => marker.markerId.value.startsWith(type));

    if ((type == 'oil' && showOilStations) ||
        (type == 'airport' && showAirports) ||
        (type == 'parking' && showParking)) {
      _fetchNearbyPlaces(type);
    }
  }

  Widget _buildPlaceFilterButton(
    String label,
    IconData icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? Theme.of(context).primaryColor : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleShowAllVehicles() {
    setState(() {
      _showAllVehicles = !_showAllVehicles;
    });
  }

  int _estimateWalkingMinutes(double distanceKm) {
    // Assume 5 km/h walking speed
    return (distanceKm / 5 * 60).round();
  }

  void _openDirections(LatLng carPosition) async {
    if (_userLocation == null) return;
    final origin = '${_userLocation!.latitude},${_userLocation!.longitude}';
    final dest = '${carPosition.latitude},${carPosition.longitude}';
    final googleUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$dest&travelmode=walking';
    final appleUrl =
        'http://maps.apple.com/?saddr=$origin&daddr=$dest&dirflg=w';
    final url = await canLaunchUrl(Uri.parse(googleUrl)) ? googleUrl : appleUrl;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCorporate == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isCorporate == true) {
      return const Center(
        child: Text('Map is not available for corporate users.'),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Vehicles"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _polylines.clear();
                _selectedCarId = null;
              });
              _initializeMap();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_isError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'An error occurred',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red[400]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeMap,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_userLocation == null)
            const Center(
              child: Text(
                'Unable to get your location. Please check location permissions.',
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _userLocation!,
                zoom: 14.0,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                // Center map on user location with all markers visible
                if (_markers.isNotEmpty) {
                  double minLat = _userLocation!.latitude;
                  double maxLat = _userLocation!.latitude;
                  double minLng = _userLocation!.longitude;
                  double maxLng = _userLocation!.longitude;

                  for (var marker in _markers) {
                    minLat = min(minLat, marker.position.latitude);
                    maxLat = max(maxLat, marker.position.latitude);
                    minLng = min(minLng, marker.position.longitude);
                    maxLng = max(maxLng, marker.position.longitude);
                  }

                  final bounds = LatLngBounds(
                    southwest: LatLng(minLat, minLng),
                    northeast: LatLng(maxLat, maxLng),
                  );

                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, 50.0),
                  );
                }
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              mapToolbarEnabled: true,
            ),
          if (_isLoadingRoute)
            const Positioned(
              top: 16,
              left: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading route...'),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.radar, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${_maxDistanceFilter.toStringAsFixed(1)} km',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 150,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            activeTrackColor: Colors.blue[700],
                            inactiveTrackColor: Colors.blue[100],
                            thumbColor: Colors.blue[700],
                            overlayColor: Colors.blue[200]?.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _maxDistanceFilter,
                            min: 1,
                            max: 50,
                            divisions: 49,
                            label:
                                '${_maxDistanceFilter.toStringAsFixed(1)} km',
                            onChanged: (value) {
                              setState(() {
                                _maxDistanceFilter = value;
                              });
                              _fetchCarsFromFirestore();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehicle Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLegendItem('Available', Colors.green),
                      _buildLegendItem('In Maintenance', Colors.orange),
                      _buildLegendItem('Unavailable', Colors.red),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nearby Places',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPlaceFilterButton(
                        'Gas Stations',
                        Icons.local_gas_station,
                        showOilStations,
                        () => _togglePlaceType('oil'),
                      ),
                      _buildPlaceFilterButton(
                        'Airports',
                        Icons.flight,
                        showAirports,
                        () => _togglePlaceType('airport'),
                      ),
                      _buildPlaceFilterButton(
                        'Parking',
                        Icons.local_parking,
                        showParking,
                        () => _togglePlaceType('parking'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.7,
            builder: (context, scrollController) {
              // Get the filtered list of cars based on the current filter
              final displayedCars = _showAllVehicles ? _allCars : _nearbyCars;

              // Remove any potential duplicates based on car ID
              final uniqueCars =
                  displayedCars
                      .fold<Map<String, Map<String, dynamic>>>({}, (map, car) {
                        if (!map.containsKey(car['id'])) {
                          map[car['id']] = car;
                        }
                        return map;
                      })
                      .values
                      .toList();

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Nearby Vehicles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${uniqueCars.length} vehicles within ${_maxDistanceFilter.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _toggleShowAllVehicles,
                            icon: Icon(
                              _showAllVehicles
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            label: Text(
                              _showAllVehicles ? 'Show Nearby' : 'Show All',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: uniqueCars.length,
                        itemBuilder: (context, index) {
                          final car = uniqueCars[index];
                          return GestureDetector(
                            onTap: () => _showCarPreview(car),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                              left: Radius.circular(12),
                                            ),
                                        child: Image.network(
                                          car['image'],
                                          height: 100,
                                          width: 120,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                          ) {
                                            if (loadingProgress == null)
                                              return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value:
                                                    loadingProgress
                                                                .expectedTotalBytes !=
                                                            null
                                                        ? loadingProgress
                                                                .cumulativeBytesLoaded /
                                                            loadingProgress
                                                                .expectedTotalBytes!
                                                        : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                          ) {
                                            return Container(
                                              height: 100,
                                              width: 120,
                                              color: Colors.grey[300],
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.error_outline,
                                                    color: Colors.red[400],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Image Error',
                                                    style: TextStyle(
                                                      color: Colors.red[400],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${car['brand']} ${car['name']}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '${PriceFormatter.formatPrice((car['discountedPrice'] ?? car['price'] ?? 0) is int ? (car['discountedPrice'] ?? car['price'] ?? 0).toDouble() : (car['discountedPrice'] ?? car['price'] ?? 0) as double)}/day',
                                                    style: TextStyle(
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (car['discountedPrice'] !=
                                                      null) ...[
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${PriceFormatter.formatPrice((car['price'] ?? 0) is int ? (car['price'] ?? 0).toDouble() : (car['price'] ?? 0) as double)}',

                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .primaryColor
                                                            .withOpacity(0.7),
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    car['isInMaintenance']
                                                        ? Icons.build
                                                        : car['isAvailable']
                                                        ? Icons.check_circle
                                                        : Icons.cancel,
                                                    size: 14,
                                                    color: car['statusColor'],
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      car['status'],
                                                      style: TextStyle(
                                                        color:
                                                            car['statusColor'],
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              GestureDetector(
                                                onTap:
                                                    () => _openDirections(
                                                      car['position'],
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      size: 14,
                                                      color: Colors.blue[700],
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${car['distance'].toStringAsFixed(1)} km',
                                                      style: TextStyle(
                                                        color: Colors.blue[700],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '(${_estimateWalkingMinutes(car['distance'])} min)',
                                                      style: TextStyle(
                                                        color: Colors.blue[700],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    mapController?.dispose();
    super.dispose();
  }
}
