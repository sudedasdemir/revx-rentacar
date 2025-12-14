import 'package:flutter/material.dart';

class AppTitleText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;

  const AppTitleText(this.text, {super.key, this.fontSize = 18.0, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color ?? theme.textTheme.titleLarge?.color,
      ),
    );
  }
}
