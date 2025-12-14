import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Privacy Policy")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Privacy Policy",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "RevX is committed to protecting your privacy and personal information. This Privacy Policy outlines how we collect, use, disclose, and safeguard your data when you interact with our services and applications.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "1. Information We Collect",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "• Personal Identification Information (Name, Email, Phone Number, etc.)\n"
              "• Usage Data (app interactions, device information, crash reports)\n"
              "• Location Data (if permitted)\n"
              "• Cookies and Tracking Technologies",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "2. How We Use Your Information",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "• To provide and improve our services\n"
              "• To personalize user experience\n"
              "• To process transactions and provide customer support\n"
              "• To send updates, promotions, and important service information\n"
              "• To comply with legal obligations",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "3. Data Sharing and Disclosure",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "RevX does not sell, rent, or lease your personal information. We may share data only with:\n"
              "• Trusted third-party service providers (under strict confidentiality)\n"
              "• Legal authorities if required by law or court order\n"
              "• Business partners in the case of mergers or acquisitions (with notification to users)",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "4. Data Security",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "We employ industry-standard encryption, secure servers, and strict access controls to protect your data from unauthorized access, disclosure, alteration, or destruction.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "5. Your Privacy Rights",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "You have the right to:\n"
              "• Access and review your personal data\n"
              "• Correct or delete inaccurate data\n"
              "• Withdraw consent at any time\n"
              "• Request data portability or restriction of processing",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "6. Data Retention",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "We retain your data only for as long as necessary to fulfill the purposes outlined in this policy, unless a longer retention period is required by law.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "7. Changes to This Privacy Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "We may update this policy from time to time to reflect changes in laws, services, or user feedback. Significant changes will be communicated through our platform.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "8. Contact Us",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "If you have any questions or concerns about our privacy practices, please contact us at privacy@revx.com.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 30),
            Text(
              "We value your trust and are committed to protecting your privacy every step of the way.",
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
