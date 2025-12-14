import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import

class InfoSocietyServicesPage extends StatelessWidget {
  const InfoSocietyServicesPage({super.key});

  // Helper function to launch URLs
  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Print error if URL can't be launched
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Information Society Services")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            const Text(
              "Information Society Services",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              "We provide services in compliance with national and international regulations governing information society services. Our goal is to offer digital solutions that are secure, accessible, and efficient.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text(
              "These services include electronic communication, data processing, and online customer support tools that enable a seamless digital experience for our users.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),
            const Text(
              "Follow Us",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.facebook, color: Colors.blue),
                  onPressed: () => _launchURL('https://facebook.com'),
                  tooltip: 'Facebook',
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.purple),
                  onPressed: () => _launchURL('https://instagram.com'),
                  tooltip: 'Instagram',
                ),
                IconButton(
                  icon: const Icon(Icons.alternate_email, color: Colors.black),
                  onPressed: () => _launchURL('https://x.com'),
                  tooltip: 'X',
                ),
                IconButton(
                  icon: const Icon(Icons.ondemand_video, color: Colors.red),
                  onPressed: () => _launchURL('https://youtube.com'),
                  tooltip: 'YouTube',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
