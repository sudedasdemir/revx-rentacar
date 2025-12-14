import 'package:firebase_app/colors.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_app/services/user_profile_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/car_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_app/car_service.dart';
import 'package:firebase_app/services/favorite_services.dart';
import 'package:firebase_app/services/user_profile_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'vehicle_comments_screen.dart';
import '../services/rental_service.dart';
import '../widgets/car_qa_section.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin, sin, pi;
import 'dart:async';

class CarDetailScreen extends StatefulWidget {
  final String carId;
  const CarDetailScreen({super.key, required this.carId});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  bool isFavorite = false;
  Car? car;
  bool isCorporateUser = false;
  final FavoriteService favoriteService = FavoriteService();
  final UserProfileService _userProfileService = UserProfileService();
  bool _isValidating = false;
  bool showFavoriteButton = false;

  // Map related variables
  bool _isLoading = true;
  CameraPosition? _initialCameraPosition;
  Set<Marker> _markers = {};
  final Completer<GoogleMapController> _mapController = Completer();

  @override
  void initState() {
    super.initState();
    _loadCarDetails();
    _checkUserType();
  }

  Future<void> _checkUserType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (mounted) {
        setState(() {
          isCorporateUser = userDoc.data()?['isCorporate'] ?? false;
        });
      }
    }
  }

  void _updateMapCamera() {
    if (car?.latitude == null || car?.longitude == null) {
      print('Car location data is missing:');
      print('Car ID: ${car?.id}');
      print('Car Name: ${car?.name}');
      print('Car Brand: ${car?.brand}');
      print('Latitude: ${car?.latitude}');
      print('Longitude: ${car?.longitude}');
      return;
    }

    print('Setting up map with car location:');
    print('Latitude: ${car!.latitude}');
    print('Longitude: ${car!.longitude}');

    final carLatLng = LatLng(car!.latitude!, car!.longitude!);
    _initialCameraPosition = CameraPosition(target: carLatLng, zoom: 14);

    _markers = {
      Marker(
        markerId: const MarkerId('car_location'),
        position: carLatLng,
        infoWindow: InfoWindow(title: car!.name, snippet: car!.brand),
      ),
    };

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCarDetails() async {
    final carService = CarService();
    if (widget.carId.isEmpty) return;

    Car? fetchedCar = await carService.getCarById(widget.carId);
    print('Loaded car details:');
    print('Car ID: ${fetchedCar?.id}');
    print('Car Name: ${fetchedCar?.name}');
    print('Car Brand: ${fetchedCar?.brand}');
    print('Car Location: ${fetchedCar?.latitude}, ${fetchedCar?.longitude}');

    setState(() {
      car = fetchedCar;
    });
    if (car != null) {
      _checkIfFavorite();
      _updateMapCamera();
    }
  }

  Future<void> _checkIfFavorite() async {
    try {
      final isFav = await favoriteService.isFavorite(widget.carId);
      if (mounted) {
        setState(() {
          isFavorite = isFav;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Widget _buildLocationSection() {
    if (car == null || car!.latitude == null || car!.longitude == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Location', Theme.of(context).textTheme),
          const SizedBox(height: 15),
          const Center(
            child: Text(
              'Location information not available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location', Theme.of(context).textTheme),
        const SizedBox(height: 15),
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(car!.latitude!, car!.longitude!),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('carLocation'),
                  position: LatLng(car!.latitude!, car!.longitude!),
                  infoWindow: InfoWindow(title: car!.name, snippet: car!.brand),
                ),
              },
              myLocationEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
              onMapCreated: (controller) {
                print('Map created successfully');
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarImage() {
    return Hero(
      tag: car!.name,
      child: Container(
        color: Colors.grey[200],
        child: CachedNetworkImage(
          imageUrl: car!.image,
          fit: BoxFit.contain,
          placeholder:
              (context, url) =>
                  const Center(child: CircularProgressIndicator()),
          errorWidget:
              (context, url, error) => Center(
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
          memCacheWidth: 800,
          memCacheHeight: 800,
          maxWidthDiskCache: 800,
          maxHeightDiskCache: 800,
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (car == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: AppColors.primary,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    children: [
                      Positioned.fill(child: _buildCarImage()),
                      // Add page indicator
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withOpacity(
                                  0.8,
                                ), // Changed to red gradient
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: AppColors.primary, // Changed to red
                      size: 20,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () async {
                      try {
                        setState(() {
                          isFavorite = !isFavorite;
                        });

                        if (isFavorite) {
                          await favoriteService.addFavorite(widget.carId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Added to favorites'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'Go to Favorites',
                                textColor: Colors.white,
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const HomeScreen(
                                            initialTab: 2,
                                            scrollToFavorites: true,
                                            skipRedirect: true,
                                          ),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          );
                        } else {
                          await favoriteService.removeFavorite(widget.carId);
                          final snackBar = SnackBar(
                            content: const Text('Removed from favorites'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                            action: SnackBarAction(
                              label: 'Undo',
                              textColor: Colors.white,
                              onPressed: () async {
                                await favoriteService.addFavorite(widget.carId);
                                if (mounted) {
                                  setState(() {
                                    isFavorite = true;
                                  });
                                }
                              },
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(snackBar);
                        }
                      } catch (e) {
                        setState(() {
                          isFavorite = !isFavorite; // Revert on error
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Error updating favorites'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: Offset(0, -30),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.background,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 25),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          car!.brand,
                                          style: textTheme.bodySmall,
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          car!.name,
                                          style: textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        SizedBox(height: 8),
                                        FutureBuilder<double>(
                                          future: _getLiveAverageRating(
                                            car!.id,
                                          ),
                                          builder: (context, snapshot) {
                                            final avgRating =
                                                snapshot.data ?? 0.0;
                                            return Row(
                                              children: [
                                                RatingBarIndicator(
                                                  rating: avgRating,
                                                  itemBuilder:
                                                      (context, _) => Icon(
                                                        Icons.star,
                                                        color: Colors.amber,
                                                      ),
                                                  itemCount: 5,
                                                  itemSize: 20,
                                                  direction: Axis.horizontal,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  avgRating.toStringAsFixed(1),
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                        color: Colors.grey[600],
                                                      ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        if (car!.isInMaintenance)
                                          Container(
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.build,
                                                  size: 16,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'In Maintenance',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          PriceFormatter.formatPrice(
                                            car!.discountedPrice ?? car!.price,
                                          ),
                                          style: textTheme.headlineSmall
                                              ?.copyWith(
                                                color: colorScheme.secondary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (car!.discountedPrice != null) ...[
                                          Text(
                                            PriceFormatter.formatPrice(
                                              car!.price,
                                            ),
                                            style: textTheme.bodySmall
                                                ?.copyWith(
                                                  decoration:
                                                      TextDecoration
                                                          .lineThrough,
                                                  color: Colors.grey,
                                                ),
                                          ),
                                        ],
                                        Text(
                                          'per day',
                                          style: textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(height: 30),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _buildInfoChip(
                                      Icons.speed,
                                      '${car!.topSpeed ?? "N/A"} km/h',
                                      colorScheme,
                                    ),
                                    _buildInfoChip(
                                      Icons.account_tree_outlined,
                                      car!.transmission ?? "N/A",
                                      colorScheme,
                                    ),
                                    _buildInfoChip(
                                      Icons.local_gas_station,
                                      car!.fuelType ?? "N/A",
                                      colorScheme,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 30),
                          _buildSectionTitle("Description", textTheme),
                          SizedBox(height: 15),
                          Text(
                            car!.description,
                            style: textTheme.bodyMedium?.copyWith(height: 1.5),
                          ),
                          SizedBox(height: 30),
                          // Only show location section for non-corporate users
                          if (!isCorporateUser) ...[_buildLocationSection()],
                          SizedBox(height: 30),
                          _buildSectionTitle('Reviews', textTheme),
                          _buildCommentsSection(context),
                          SizedBox(height: 30),
                          _buildSectionTitle('Questions & Answers', textTheme),
                          CarQASection(carId: widget.carId),
                          SizedBox(
                            height: 100,
                          ), // Add padding for the bottom button
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  PriceFormatter.formatPrice(
                    car!.discountedPrice ?? car!.price,
                  ),
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (car!.discountedPrice != null) ...[
                  Text(
                    PriceFormatter.formatPrice(car!.price),
                    style: textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                ],
                Text('per day', style: textTheme.bodySmall),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    car!.isInMaintenance ? Colors.grey : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed:
                  car!.isInMaintenance
                      ? null
                      : () async {
                        setState(() => _isValidating = true);
                        try {
                          // Check both user profile and license info
                          final userProfile =
                              await _userProfileService.getUserProfile();
                          final licenseInfo =
                              await _userProfileService.getLicenseInfo();

                          // Check if user profile is complete
                          if (userProfile == null ||
                              !userProfile.isProfileComplete) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text(
                                        'Complete Profile Required',
                                      ),
                                      content: const Text(
                                        'Please complete your profile information before booking.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        const HomeScreen(
                                                          initialTab: 3,
                                                        ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Go to Profile'),
                                        ),
                                      ],
                                    ),
                              );
                            }
                            return;
                          }

                          // Check if license info exists and is valid
                          if (licenseInfo == null || !licenseInfo.isValid) {
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Invalid License'),
                                      content: Text(
                                        licenseInfo == null
                                            ? 'Please add your driver\'s license information.'
                                            : 'Your driver\'s license must be at least 2 years old to rent a car.\n\n'
                                                'Please make sure your license issue date is correct.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (context) =>
                                                        const HomeScreen(
                                                          initialTab: 3,
                                                        ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text(
                                            'Update License Info',
                                          ),
                                        ),
                                      ],
                                    ),
                              );
                            }
                            return;
                          }

                          // Only proceed if both profile and license are valid
                          Navigator.pushNamed(
                            context,
                            '/booking',
                            arguments: car,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error checking profile: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isValidating = false);
                          }
                        }
                      },
              child:
                  _isValidating
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Book Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ColorScheme colorScheme) {
    return Chip(
      label: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary), // Changed to red
          SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSpecItem(
    String title,
    String value,
    IconData icon,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primary), // Changed to red
        SizedBox(height: 5),
        Text(title, style: textTheme.bodySmall),
        SizedBox(height: 5),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFeaturedChip(String feature, ColorScheme colorScheme) {
    return Chip(
      label: Text(
        feature,
        style: const TextStyle(
          color: Colors.black, // Always black in both modes
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.9) // Light background in dark mode
              : Colors.grey[200], // Light background in light mode
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  Widget _buildSectionTitle(String title, TextTheme textTheme) {
    return Text(
      title,
      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('comments')
              .where('carId', isEqualTo: car!.id)
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in comments stream: ${snapshot.error}');
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final comments = snapshot.data!.docs;
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No reviews yet.'),
          );
        }
        return Column(
          children:
              comments.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final reviewer = data['userName'] ?? 'User';
                final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
                final text = data['text'] ?? '';
                final imageUrl = data['imageUrl'] as String?;
                print('Comment image URL: $imageUrl'); // Debug print
                final date =
                    (data['createdAt'] ?? data['updatedAt']) != null
                        ? ((data['createdAt'] ?? data['updatedAt'])
                                as Timestamp)
                            .toDate()
                        : null;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            RatingBarIndicator(
                              rating: rating,
                              itemBuilder:
                                  (context, _) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                              itemCount: 5,
                              itemSize: 18,
                              direction: Axis.horizontal,
                            ),
                            const SizedBox(width: 8),
                            if (date != null)
                              Text(
                                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (reviewer.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 4.0,
                                  bottom: 2.0,
                                ),
                                child: Text(
                                  reviewer,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            Text(text),
                          ],
                        ),
                      ),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.contain,
                              width: 150,
                              height: 150,
                              placeholder: (context, url) {
                                print('Loading comment image from URL: $url');
                                return Container(
                                  height: 150,
                                  width: 150,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 8),
                                        Text('Loading image...'),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              errorWidget: (context, url, error) {
                                print(
                                  'Error loading comment image from URL: $url',
                                );
                                print('Error details: $error');
                                return Container(
                                  height: 150,
                                  width: 150,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 32,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  Future<double> _getLiveAverageRating(String carId) async {
    final query =
        await FirebaseFirestore.instance
            .collection('comments')
            .where('carId', isEqualTo: carId)
            .get();
    if (query.docs.isEmpty) return 0.0;
    final ratings =
        query.docs.map((doc) => (doc['rating'] as num).toDouble()).toList();
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }
}
