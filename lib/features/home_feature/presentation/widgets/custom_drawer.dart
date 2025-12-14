import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  _CustomDrawerState createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  Map<String, bool> expandedItems = {
    'Corporate': false,
    'Customer Services': false,
    'Contact Us': false,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          gradient: LinearGradient(
            colors: [
              isDark ? Colors.grey[900]! : AppColors.primary.withOpacity(0.1),
              theme.scaffoldBackgroundColor,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.close, color: theme.colorScheme.onBackground),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icons/re.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'RevX',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            drawerItem(title: 'Corporate', hasSubItems: true),
            if (expandedItems['Corporate']!) ...[
              drawerSubItem(title: 'About Us', pageName: '/about_us'),
              drawerSubItem(
                title: 'Vision & Mission',
                pageName: '/vision_mission',
              ),
              drawerSubItem(title: 'Our Values', pageName: '/our_values'),
              drawerSubItem(
                title: 'Information Society Services',
                pageName: '/info_society_services',
              ),
              drawerSubItem(
                title: 'Personal Data Protection',
                pageName: '/personal_data_protection',
              ),
              drawerSubItem(
                title: 'Quality Policy',
                pageName: '/quality_policy',
              ),
            ],
            drawerItem(title: 'Customer Services', hasSubItems: true),
            if (expandedItems['Customer Services']!) ...[
              drawerSubItem(
                title: 'Privacy Policy',
                pageName: '/privacy_policy',
              ),
              drawerSubItem(title: 'Legal Warning', pageName: '/legal_warning'),
              drawerSubItem(
                title: 'Return/Cancel Terms',
                pageName: '/return_cancel_terms',
              ),
              drawerSubItem(
                title: 'Rental Agreement',
                pageName: '/rental_agreement',
              ),
              drawerSubItem(
                title: 'Frequently Asked Questions',
                pageName: '/faq',
              ),
            ],
            drawerItem(
              title: 'Reservation Cancellation Form',
              pageName: '/reservation_cancellation_form',
            ),
            drawerItem(title: 'Gift Voucher', pageName: '/gift_voucher'),
            drawerItem(title: 'Contact Us', hasSubItems: true),
            if (expandedItems['Contact Us']!) ...[
              drawerSubItem(
                title: 'Contact Center',
                pageName: '/contact_center',
              ),
              drawerSubItem(title: 'E-Bulletin', pageName: '/e_bulletin'),
            ],
            _buildSocialSection(),
          ],
        ),
      ),
    );
  }

  Widget drawerItem({
    required String title,
    bool hasSubItems = false,
    String? pageName,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onBackground,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          hasSubItems
              ? Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.onBackground,
              )
              : Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onBackground,
              ),
      onTap: () {
        if (pageName != null) {
          Navigator.pushNamed(context, pageName);
        } else {
          setState(() {
            expandedItems[title] = !expandedItems[title]!;
          });
        }
      },
    );
  }

  Widget drawerSubItem({required String title, required String pageName}) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 32.0),
      title: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onBackground.withOpacity(0.8),
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pushNamed(context, pageName);
      },
    );
  }

  Widget _buildSocialSection() {
    final theme = Theme.of(context);

    Future<void> _launchUrl(String url) async {
      try {
        final Uri uri = Uri.parse(url);
        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error launching URL: $e')));
        }
      }
    }

    Future<void> _launchEmail(String email) async {
      try {
        final Uri emailUri = Uri(scheme: 'mailto', path: email);
        if (!await launchUrl(
          emailUri,
          mode: LaunchMode.externalNonBrowserApplication,
        )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch email app')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error launching email app: $e')),
          );
        }
      }
    }

    Future<void> _launchPhone(String phoneNumber) async {
      try {
        // Remove any spaces or special characters from the phone number
        final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
        final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
        if (!await launchUrl(
          phoneUri,
          mode: LaunchMode.externalNonBrowserApplication,
        )) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not launch phone app')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error launching phone app: $e')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Text(
          "Get in Touch",
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _launchPhone('4444937'),
          child: Text(
            "444 4 937",
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _launchEmail('revx9876@gmail.com'),
          child: Text(
            "revx9876@gmail.com",
            style: TextStyle(color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Follow Us",
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.facebook,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () => _launchUrl('https://www.facebook.com/login'),
            ),
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.twitter,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed: () => _launchUrl('https://twitter.com/i/flow/login'),
            ),
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.instagram,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed:
                  () => _launchUrl('https://www.instagram.com/accounts/login'),
            ),
            IconButton(
              icon: FaIcon(
                FontAwesomeIcons.youtube,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              onPressed:
                  () => _launchUrl(
                    'https://accounts.google.com/ServiceLogin?service=youtube',
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
