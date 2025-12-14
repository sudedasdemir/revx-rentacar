import 'package:firebase_app/features/home_feature/data/data_source/local/sample_data.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/brands_cars_page.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/widgets/app_title_text.dart';
import 'package:flutter/material.dart';

final Map<String, String> brandLogos = {
  'BMW': 'assets/brand_logos/bmw.png',
  'Mercedes': 'assets/brand_logos/mercedes.png',
  'Audi': 'assets/brand_logos/audi.png',
  'Toyota': 'assets/brand_logos/toyota.png',
  'Honda': 'assets/brand_logos/honda.png',
  'All': 'assets/brand_logos/all.png',
  'Porsche': 'assets/brand_logos/porsche.png',
  'Maserati': 'assets/brand_logos/maseratilogo.png',
  'Tesla': 'assets/brand_logos/tesla.png',
  'Hyundai': 'assets/brand_logos/hyundai.png',
  'Kia': 'assets/brand_logos/kia.png',

  // Add more brands and their logo paths as needed
};

class TopBrandsWidget extends StatefulWidget {
  const TopBrandsWidget({super.key});

  @override
  State<TopBrandsWidget> createState() => _TopBrandsWidgetState();
}

class _TopBrandsWidgetState extends State<TopBrandsWidget> {
  String selectedBrand = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: Dimens.largePadding),
          child: AppTitleText('Top Brands', fontSize: 16.0),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80.0,
          child: ListView.builder(
            itemCount: topBrands.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final brand = topBrands[index];
              final isSelected =
                  selectedBrand.toLowerCase() == brand.toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(left: Dimens.largePadding),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedBrand = brand;
                    });

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => BrandCarsPage(selectedBrand: brand),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.colorScheme.secondary
                              : theme.cardColor,
                      borderRadius: BorderRadius.circular(Dimens.corners),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimens.smallPadding,
                      vertical: Dimens.smallPadding,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          brandLogos[brand] ?? 'assets/brand_logos/default.png',
                          height: 40,
                          width: 40,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Icon(Icons.image_not_supported),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          brand,
                          style: TextStyle(
                            color:
                                isSelected
                                    ? theme.colorScheme.onSecondary
                                    : theme.textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
