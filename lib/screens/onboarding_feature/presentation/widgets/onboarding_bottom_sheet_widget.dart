import 'package:firebase_app/colors.dart';
import 'package:firebase_app/screens/signup_screen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/utils/app_navigator.dart';
import 'package:firebase_app/screens/onboarding_feature/presentation/bloc/onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingBottomSheetWidget extends StatelessWidget {
  const OnboardingBottomSheetWidget({
    super.key,
    required Color backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final watch = context.watch<OnboardingCubit>();
    final read = context.read<OnboardingCubit>();
    final theme = Theme.of(context); // Tema erişimi eklendi

    return Container(
      height: 80.0,
      padding: const EdgeInsets.symmetric(
        horizontal: Dimens.padding,
        vertical: Dimens.largePadding,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (watch.state.position == 0)
            const SizedBox(width: 90)
          else
            SizedBox(
              width: 100,
              child: TextButton(
                onPressed: () {
                  read.onPreviousPressed();
                },
                child: const Text('Previous'),
              ),
            ),
          SizedBox(
            height: 12.0,
            child: ListView.builder(
              itemCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemBuilder: (final context, final index) {
                return InkWell(
                  onTap: () {
                    read.goToSpecificPosition(index);
                  },
                  borderRadius: BorderRadius.circular(Dimens.corners),
                  child: Container(
                    margin: const EdgeInsets.all(Dimens.smallPadding),
                    child: Ink(
                      width: 24.0,
                      height: 4.0,
                      decoration: BoxDecoration(
                        color:
                            index <= watch.state.position
                                ? AppColors.secondary
                                : theme
                                    .colorScheme
                                    .onBackground, // Tema destekli
                        borderRadius: BorderRadius.circular(Dimens.corners),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          TextButton(
            onPressed: () {
              if (watch.state.position == 3) {
                push(context, const SignupScreen());
                return;
              }
              read.onNextPressed();
            },
            child: Text(watch.state.position == 3 ? 'Enter' : 'Next'),
          ),
        ],
      ),
    );
  }
}
