import 'package:flutter/material.dart';

class PersonalDataProtectionPage extends StatelessWidget {
  const PersonalDataProtectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Personal Data Protection")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Personal Data Protection",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "At RevX, we recognize the importance of protecting personal data and are fully committed to safeguarding the privacy of our users, customers, partners, and employees. Our data protection policies are in strict compliance with global standards such as the GDPR (General Data Protection Regulation) and local regulations.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            SizedBox(height: 20),
            Text(
              "Our Principles of Data Protection:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "• Lawfulness, fairness, and transparency in data processing.\n"
              "• Collecting data only for specified, explicit, and legitimate purposes.\n"
              "• Ensuring data accuracy and keeping it up to date.\n"
              "• Limiting storage of personal data to the minimum period necessary.\n"
              "• Maintaining integrity and confidentiality through appropriate security measures.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            SizedBox(height: 20),
            Text(
              "We take a proactive approach to personal data protection by embedding privacy into our systems and processes, educating our employees, and continuously monitoring compliance.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),
            SizedBox(height: 20),
            Text(
              "Your trust is our priority, and we are dedicated to protecting your personal data at every level of our operations.",
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
