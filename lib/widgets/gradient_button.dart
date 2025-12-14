import 'package:firebase_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final List<Color> gradient;
  final double? width;
  final double height;
  final bool isLoading;

  const GradientButton({
    required this.text,
    required this.onPressed,
    this.gradient = const [
      Color(0xFFE74C3C), // Primary red
      Color(0xFFC0392B), // Darker red
    ],
    this.width,
    this.height = 56,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1), // Changed to red shadow
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              Colors.transparent, // Make button transparent to show gradient
          foregroundColor: Colors.white, // Text color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
          elevation: 0, // Remove default button elevation
        ),
        child: Center(
          child:
              isLoading
                  ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(
                    text,
                    style: const TextStyle(
                      color:
                          Colors.white, // Fixed white color for better contrast
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
        ),
      ),
    );
  }
}
