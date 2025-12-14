import 'package:firebase_app/colors.dart';
import 'package:firebase_app/widgets/app_svg_viewer.dart';
import 'package:flutter/material.dart';

class AppBorderedIconButton extends StatelessWidget {
  const AppBorderedIconButton({
    super.key,
    required this.iconPath,
    this.onPressed,
    this.color = Colors.white,
  });

  final String iconPath;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? AppColors.darkGrayColor : AppColors.grayColor,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: IconButton(
        onPressed: onPressed ?? () {},
        icon: AppSvgViewer(
          iconPath,
          color: AppColors.primary, // Changed to use red primary color
        ),
        color: AppColors.primary, // Added red color for the icon button
      ),
    );
  }
}
