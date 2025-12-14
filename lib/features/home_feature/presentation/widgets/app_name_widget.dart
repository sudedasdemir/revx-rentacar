import 'package:firebase_app/theme/dimens.dart';
import 'package:flutter/material.dart';

class AppNameWidget extends StatelessWidget {
  const AppNameWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Dimens.padding,
      children: [const Text('  RevX  ')],
    );
  }
}
