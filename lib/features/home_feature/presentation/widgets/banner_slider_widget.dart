import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/utils/check_device_size.dart';
import 'package:firebase_app/features/home_feature/data/repositories/banner_repository.dart';
import 'package:firebase_app/features/home_feature/presentation/bloc/banner_slider_cubit.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class BannerSliderWidget extends StatelessWidget {
  const BannerSliderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BannerSliderCubit>(
      create: (context) => BannerSliderCubit(repository: BannerRepository()),
      child: const _BannerSliderWidget(),
    );
  }
}

class _BannerSliderWidget extends StatelessWidget {
  const _BannerSliderWidget();

  void _handleBannerTap(BuildContext context, String? carId) {
    if (carId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No car associated with this banner'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      Navigator.pushNamed(context, '/car-details', arguments: carId)
          .then((_) {
            // Optional: Add any cleanup or refresh logic here
          })
          .catchError((error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error navigating to car details: $error'),
                duration: const Duration(seconds: 2),
              ),
            );
          });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<BannerSliderCubit>();
    final read = context.read<BannerSliderCubit>();
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    if (watch.state.banners.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Center(
      child: SizedBox(
        width:
            checkDesktopSize(context)
                ? Dimens.largeDeviceBreakPoint
                : size.width,
        child: Column(
          children: [
            CarouselSlider(
              carouselController: watch.state.controller,
              items:
                  watch.state.banners.map((banner) {
                    return GestureDetector(
                      onTap: () => _handleBannerTap(context, banner.carId),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(
                                banner.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    child: const Center(
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 40,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              options: CarouselOptions(
                height: 180,
                viewportFraction: 0.9,
                autoPlay: true,
                enlargeCenterPage: true,
                aspectRatio: 16 / 9,
                onPageChanged: (final int index, reason) {
                  read.onPageChanged(index: index);
                },
              ),
            ),
            const SizedBox(height: 1),
            AnimatedSmoothIndicator(
              activeIndex: watch.state.currentIndex,
              count: watch.state.banners.length,
              effect: WormEffect(
                activeDotColor: theme.colorScheme.secondary,
                dotColor: theme.colorScheme.onBackground.withOpacity(0.4),
                dotHeight: 8,
                dotWidth: 8,
                type: WormType.thin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
