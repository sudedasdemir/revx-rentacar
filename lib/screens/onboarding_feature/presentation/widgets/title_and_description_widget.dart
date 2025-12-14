import 'package:animate_do/animate_do.dart';
import 'package:firebase_app/gen/fonts.gen.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/utils/check_device_size.dart';
import 'package:firebase_app/screens/onboarding_feature/data/local/sample_data.dart';
import 'package:firebase_app/screens/onboarding_feature/presentation/bloc/onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TitleAndDescriptionWidget extends StatelessWidget {
  const TitleAndDescriptionWidget({super.key, required Color textColor});

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<OnboardingCubit>();
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FadeInDown(
      delay: const Duration(milliseconds: 300),
      child: SizedBox(
        width:
            checkVerySmallDeviceSize(context)
                ? size.width
                : Dimens.smallDeviceBreakPoint,
        child: Column(
          children: [
            Text(
              titles[watch.state.position],
              style: TextStyle(
                fontSize: 30.0,
                fontFamily: FontFamily.poppinsBold,
                color: isDarkMode ? AppColors.whiteColor : AppColors.secondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Dimens.extraLargePadding),
            Text(
              descriptions[watch.state.position],
              style: TextStyle(
                fontSize: 20.0,
                fontFamily: FontFamily.poppinsRegular,
                color: isDarkMode ? AppColors.whiteColor : AppColors.blackColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
