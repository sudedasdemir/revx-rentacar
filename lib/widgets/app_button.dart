import 'package:firebase_app/gen/fonts.gen.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/widgets/app_space.dart';
import 'package:firebase_app/widgets/app_svg_viewer.dart';
import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.title,
    required this.onPressed,
    this.color,
    this.width,
    this.iconPath,
    this.margin,
    this.borderRadius,
  });

  final String title;
  final GestureTapCallback? onPressed;
  final Color? color;
  final double? width;
  final String? iconPath;
  final EdgeInsets? margin;
  final double? borderRadius;

  @override
  Widget build(final BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Container(
      width: width ?? size.width,
      height: 54.0,
      margin: margin ?? const EdgeInsets.all(Dimens.largePadding),
      child: FilledButton(
        style: ButtonStyle(
          backgroundColor:
              color == null
                  ? WidgetStateProperty.resolveWith<Color>((
                    final Set<WidgetState> states,
                  ) {
                    if (states.contains(WidgetState.disabled)) {
                      return AppColors.secondary.withOpacity(0.3);
                    }
                    return Theme.of(context).brightness == Brightness.dark
                        ? AppColors.secondary
                        : AppColors.secondary;
                  })
                  : WidgetStateProperty.all<Color>(color!),
          shape: WidgetStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? Dimens.corners,
              ),
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconPath != null) ...[
              AppSvgViewer(iconPath ?? '', color: AppColors.whiteColor),
              const AppHSpace(),
            ],
            Text(
              title,
              style: const TextStyle(
                fontFamily: FontFamily.poppinsMedium,
                color: AppColors.whiteColor,
                fontSize: 16.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
