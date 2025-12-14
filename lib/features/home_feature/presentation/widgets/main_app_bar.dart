import 'package:firebase_app/features/home_feature/presentation/widgets/app_name_widget.dart';
import 'package:firebase_app/gen/assets.gen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/widgets/app_bordered_icon_button.dart';
import 'package:firebase_app/widgets/app_subtitle_text.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/app_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MainAppBar({super.key, this.onMenuTap});

  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            backgroundColor: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            child: const AppImageWidget(),
          ),
        ),
      ],
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Rent A Car',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Find your dream car',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ],
      ),
      leading: IconButton(
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
        icon: Icon(Icons.menu, color: textColor, size: 24),
      ),
      leadingWidth: 56.0,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8.0);
}
