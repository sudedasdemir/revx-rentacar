import 'package:firebase_app/colors.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:flutter/material.dart';

class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.titleTextStyle,
    this.onTap,
    this.setDefaultIconColor,
    this.iconColor,
    this.setDefaultTrailingIconColor,
    this.hasBorder = false,
    this.borderRadius,
    this.trailingWidget,
    this.contentPadding,
    this.iconSize,
    this.leading,
    this.subtitleTextStyle,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleTextStyle;
  final GestureTapCallback? onTap;
  final bool? setDefaultIconColor;
  final Color? iconColor;
  final bool? setDefaultTrailingIconColor;
  final bool hasBorder;
  final BorderRadiusGeometry? borderRadius;
  final Widget? trailingWidget;
  final EdgeInsetsGeometry? contentPadding;
  final double? iconSize;
  final Widget? leading;
  final TextStyle? subtitleTextStyle;

  @override
  Widget build(final BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Dimens.corners),
      child: Container(
        height: 56.0,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(Dimens.corners),
          border:
              hasBorder
                  ? Border.all(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors
                                .darkBorderColor // Dark mode border color
                            : AppColors.borderColor, // Light mode border color
                  )
                  : null,
        ),
        child: Center(
          child: ListTile(
            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: Dimens.largePadding),
            title: Text(
              title,
              style:
                  titleTextStyle ??
                  TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppColors
                                .whiteColor // Dark mode title color
                            : AppColors.textPrimary, // Light mode title color
                  ),
            ),
            subtitle:
                subtitle == null
                    ? null
                    : Padding(
                      padding: const EdgeInsets.only(top: Dimens.padding),
                      child: Text(
                        subtitle ?? '',
                        style:
                            subtitleTextStyle ??
                            TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors
                                          .whiteColor // Dark mode subtitle color
                                      : AppColors
                                          .textSecondary, // Light mode subtitle color
                            ),
                      ),
                    ),
            leading: leading,
            trailing: trailingWidget,
          ),
        ),
      ),
    );
  }
}
