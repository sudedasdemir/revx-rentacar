import 'package:flutter/material.dart';
import 'package:firebase_app/theme/theme.dart';

class SocialLoginButton extends StatelessWidget {
  final String text;
  final String iconPath;
  final bool isPassword;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;

  const SocialLoginButton({
    super.key,
    required this.text,
    required this.iconPath,
    required this.isPassword,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBackgroundColor
                : Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.textSecondary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconPath.startsWith('http')
                    ? Image.network(
                      iconPath,
                      height: 24,
                      width: 24,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Error loading image: $error');
                        return const Icon(Icons.image_not_supported);
                      },
                    )
                    : Image.asset(
                      iconPath,
                      height: 24,
                      width: 24,
                      errorBuilder:
                          (_, __, ___) => const Icon(Icons.image_not_supported),
                    ),
                SizedBox(width: 12),
                Text(
                  text,
                  style: TextStyle(
                    color:
                        textColor ??
                        (Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.textLight
                            : AppTheme.textPrimary),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
