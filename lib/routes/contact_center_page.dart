import 'package:firebase_app/colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactCenterPage extends StatefulWidget {
  const ContactCenterPage({super.key});

  @override
  _ContactCenterPageState createState() => _ContactCenterPageState();
}

class _ContactCenterPageState extends State<ContactCenterPage> {
  // Helper function to call the phone number
  Future<void> _launchPhone(String phoneNumber) async {
    final Uri _url = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url);
    } else {
      throw 'Could not launch phone number: $phoneNumber';
    }
  }

  // Helper function to send an email
  Future<void> _launchEmail(String email) async {
    final Uri _url = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url);
    } else {
      throw 'Could not send email to: $email';
    }
  }

  // Helper function to open social media links
  Future<void> _launchUrl(String url) async {
    final Uri _url = Uri.parse(url);
    if (await canLaunchUrl(_url)) {
      await launchUrl(_url);
    } else {
      throw 'Could not open URL: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact Center"),
        backgroundColor: AppColors.secondary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'We are here to assist you. Feel free to contact us through any of the following channels:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Phone number
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.secondary),
              title: const Text("Call Us"),
              subtitle: const Text("444 4 937"),
              onTap: () {
                _launchPhone("4444937");
              },
            ),
            const Divider(),

            // Email address
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.secondary),
              title: const Text("Email Us"),
              subtitle: const Text("revx9876@gmail.com"),
              onTap: () {
                _launchEmail("revx9876@gmail.com");
              },
            ),
            const Divider(),

            // Address info with a map link
            ListTile(
              leading: const Icon(
                Icons.location_on,
                color: AppColors.secondary,
              ),
              title: const Text("Our Address"),
              subtitle: const Text(
                "RevX Rent a Car, Main Street, No: 123, Istanbul, Turkey",
              ),
              onTap: () {
                _launchUrl('https://www.google.com/maps?q=RevX+Rent+a+Car');
              },
            ),
            const Divider(),

            // Social media links
            const SizedBox(height: 16),
            const Text(
              "Follow Us On Social Media",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.facebook, color: AppColors.secondary),
                  onPressed: () {
                    _launchUrl('https://facebook.com/RevX');
                  },
                ),
                IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.twitter,
                    color: AppColors.secondary,
                  ),
                  onPressed: () {
                    _launchUrl('https://twitter.com/RevX');
                  },
                ),
                IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.instagram,
                    color: AppColors.secondary,
                  ),
                  onPressed: () {
                    _launchUrl('https://instagram.com/RevX');
                  },
                ),
                IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.youtube,
                    color: AppColors.secondary,
                  ),
                  onPressed: () {
                    _launchUrl('https://youtube.com/RevX');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
