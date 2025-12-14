import 'package:flutter/material.dart';

class QualityPolicyPage extends StatelessWidget {
  const QualityPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quality Policy")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Quality Policy",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "At RevX, quality is at the core of everything we do. Our Quality Policy is focused on delivering superior services that exceed customer expectations while continuously improving our processes and operations.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 20),
            Text(
              "We are committed to:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "• Ensuring customer satisfaction through reliable and innovative services.\n"
              "• Meeting all applicable legal, regulatory, and contractual requirements.\n"
              "• Enhancing employee competence and engagement.\n"
              "• Promoting a culture of continuous improvement.\n"
              "• Leveraging technology to ensure efficiency and sustainability.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
