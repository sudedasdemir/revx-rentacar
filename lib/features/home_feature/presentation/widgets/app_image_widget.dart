import 'package:firebase_app/gen/assets.gen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:flutter/material.dart';

class AppImageWidget extends StatelessWidget {
  const AppImageWidget({super.key, this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.padding),
      child: SizedBox(
        width: width ?? 58.0,
        height: height ?? 58.0,
        child: CircleAvatar(
          backgroundColor:
              Colors.transparent, // Optional: Set a background color
          backgroundImage: AssetImage(
            Assets.icons.re,
          ), // Ensure the path is correct
        ),
      ),
    );
  }
}
