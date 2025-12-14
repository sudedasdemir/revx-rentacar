import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/theme.dart';

class CustomTextField extends StatelessWidget {
  final String label;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

  const CustomTextField({
    super.key,
    required this.label,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.controller,
    this.suffixIcon,
    this.errorText,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(
                errorText!,
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          TextFormField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            validator: validator,
            inputFormatters: inputFormatters,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 14,
              ),
              prefixIcon: Icon(prefixIcon, color: AppColors.primary),
              suffix:
                  suffixIcon ??
                  (isPassword
                      ? IconButton(
                        icon: Icon(Icons.visibility_outlined),
                        onPressed: () {},
                        color: AppColors.primary,
                      )
                      : null),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 20,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.error, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.error, width: 1),
              ),
              errorStyle: TextStyle(height: 0), // Hide the default error text
            ),
          ),
        ],
      ),
    );
  }
}
