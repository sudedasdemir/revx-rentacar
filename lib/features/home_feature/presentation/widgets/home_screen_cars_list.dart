import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/screens/booking_screen.dart';
import 'package:firebase_app/screens/see_all_cars_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/gen/assets.gen.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/widgets/app_button.dart';
import 'package:firebase_app/widgets/app_outlined_button.dart';
import 'package:firebase_app/widgets/app_space.dart';
import 'package:firebase_app/widgets/app_subtitle_text.dart';
import 'package:firebase_app/widgets/app_svg_viewer.dart';
import 'package:firebase_app/widgets/app_text_button.dart';
import 'package:firebase_app/widgets/app_title_text.dart';
import 'package:firebase_app/car_model.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:firebase_app/services/user_profile_service.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class HomeScreenCarsList extends StatefulWidget {
  const HomeScreenCarsList({super.key});

  @override
  _HomeScreenCarsListState createState() => _HomeScreenCarsListState();
}

class _HomeScreenCarsListState extends State<HomeScreenCarsList> {
  late Future<Map<String, List<Car>>> carsByCategory;
  final UserProfileService _userProfileService = UserProfileService();
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    carsByCategory = getCarsFromFirestoreGroupedByCategory();
  }

  Future<Map<String, List<Car>>> getCarsFromFirestoreGroupedByCategory() async {
    final snapshot = await FirebaseFirestore.instance.collection('cars').get();

    print('Fetched ${snapshot.docs.length} car documents from Firestore.');

    final List<Car> allCars =
        snapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();

    print('Converted ${allCars.length} car objects.');

    final Map<String, List<Car>> grouped = {};
    for (var car in allCars) {
      // Only include cars with available stock greater than 0
      if (car.availableStock > 0) {
        final category = car.category ?? 'Unknown';
        grouped.putIfAbsent(category, () => []).add(car);
      }
    }

    print('Grouped cars into ${grouped.keys.length} categories.');
    grouped.forEach((key, value) {
      print('Category "$key" has ${value.length} cars.');
    });

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, List<Car>>>(
      future: carsByCategory,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('No cars available.', style: theme.textTheme.bodyLarge),
          );
        }

        final data = snapshot.data!;

        return ListView.builder(
          itemCount: data.keys.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final categoryTitle = data.keys.elementAt(index);
            final currentCars = data[categoryTitle]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık + See all
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(Dimens.largePadding),
                      child: Text(
                        categoryTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ),
                    AppTextButton(
                      child: Row(
                        children: [
                          Text(
                            'See all',
                            style: TextStyle(color: AppColors.secondary),
                          ),
                          AppSvgViewer(
                            Assets.icons.arrowRight1,
                            color: AppColors.secondary,
                            width: 14.0,
                          ),
                        ],
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => SeeAllCarsPage(
                                  categoryTitle: categoryTitle,
                                  cars: currentCars,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                // Araç listesi
                SizedBox(
                  height: 160.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: currentCars.length,
                    itemBuilder: (context, carIndex) {
                      final car = currentCars[carIndex];

                      return Padding(
                        padding: const EdgeInsets.only(
                          left: Dimens.largePadding,
                        ),
                        child: Container(
                          width: 400,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(Dimens.corners),
                          ),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const AppHSpace(),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: Dimens.largePadding,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${car.brand} ${car.name}',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                          Row(
                                            children: [
                                              Text(
                                                PriceFormatter.formatPrice(
                                                  car.discountedPrice ??
                                                      car.price,
                                                ),
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                              if (car.discountedPrice !=
                                                  null) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  PriceFormatter.formatPrice(
                                                    car.price,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                        color: Colors.grey,
                                                      ),
                                                ),
                                              ],
                                              const SizedBox(width: 4),
                                              Text(
                                                'per day',
                                                style:
                                                    theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                          FutureBuilder<double>(
                                            future: _getAverageRating(car.id),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) {
                                                return const SizedBox(
                                                  height: 20,
                                                );
                                              }
                                              return Row(
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    snapshot.data!
                                                        .toStringAsFixed(1),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          if (car.isInMaintenance)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.build,
                                                  size: 14,
                                                  color: Colors.red,
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'In Maintenance',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: Dimens.padding,
                                    ),
                                    child: SizedBox(
                                      height: 64.0,
                                      child: Image.network(car.image),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: SizedBox(
                                      width: 140,
                                      height: 34.0,
                                      child: AppButton(
                                        margin: EdgeInsets.zero,
                                        borderRadius: Dimens.smallCorners,
                                        title:
                                            car.isInMaintenance
                                                ? 'Not book'
                                                : 'Book now',
                                        onPressed:
                                            car.isInMaintenance
                                                ? null
                                                : () async {
                                                  setState(
                                                    () => _isValidating = true,
                                                  );
                                                  try {
                                                    final userProfile =
                                                        await _userProfileService
                                                            .getUserProfile();
                                                    final licenseInfo =
                                                        await _userProfileService
                                                            .getLicenseInfo();

                                                    if (!mounted) return;

                                                    if (userProfile == null ||
                                                        !userProfile
                                                            .isProfileComplete) {
                                                      showDialog(
                                                        context: context,
                                                        builder:
                                                            (
                                                              context,
                                                            ) => AlertDialog(
                                                              title: const Text(
                                                                'Complete Profile Required',
                                                              ),
                                                              content: Text(
                                                                userProfile?.isCorporate ==
                                                                        true
                                                                    ? 'Please complete your corporate profile information (Company Name, Tax ID, Authorized Person, Firm Code, Company Sector, Phone, and Address) before booking.'
                                                                    : 'Please complete your profile information before booking.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                      context,
                                                                    );
                                                                    Navigator.pushNamed(
                                                                      context,
                                                                      '/profile',
                                                                    );
                                                                  },
                                                                  child: const Text(
                                                                    'Go to Profile',
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                      return;
                                                    }

                                                    if (licenseInfo == null ||
                                                        !licenseInfo.isValid) {
                                                      showDialog(
                                                        context: context,
                                                        builder:
                                                            (
                                                              context,
                                                            ) => AlertDialog(
                                                              title: const Text(
                                                                'Invalid License',
                                                              ),
                                                              content: Text(
                                                                licenseInfo ==
                                                                        null
                                                                    ? 'Please add your driver\'s license information.'
                                                                    : 'Your driver\'s license must be at least 2 years old to rent a car.\n\n'
                                                                        'Please make sure your license issue date is correct.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                ElevatedButton(
                                                                  onPressed: () {
                                                                    Navigator.pop(
                                                                      context,
                                                                    );
                                                                    Navigator.pushReplacement(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (
                                                                              context,
                                                                            ) => const HomeScreen(
                                                                              initialTab:
                                                                                  3,
                                                                            ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor:
                                                                        AppColors
                                                                            .primary,
                                                                    foregroundColor:
                                                                        Colors
                                                                            .white,
                                                                  ),
                                                                  child: const Text(
                                                                    'Update License Info',
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                      return;
                                                    }

                                                    // If all validations pass, proceed to booking
                                                    if (mounted) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (_) =>
                                                                  BookingScreen(
                                                                    car: car,
                                                                  ),
                                                        ),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error checking profile: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  } finally {
                                                    if (mounted) {
                                                      setState(
                                                        () =>
                                                            _isValidating =
                                                                false,
                                                      );
                                                    }
                                                  }
                                                },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: SizedBox(
                                      width: 140,
                                      height: 34.0,
                                      child: AppOutlinedButton(
                                        margin: EdgeInsets.zero,
                                        borderRadius: Dimens.smallCorners,
                                        title: 'Details',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => CarDetailScreen(
                                                    carId: car.id,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<double> _getAverageRating(String carId) async {
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
