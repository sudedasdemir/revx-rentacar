import 'package:flutter/material.dart';

class VisionMissionPage extends StatelessWidget {
  const VisionMissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vision & Mission")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Vision",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "To become the leading provider of intelligent mobility solutions, "
              "shaping the future of transportation through innovation, technology, "
              "and a customer-first mindset.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            SizedBox(height: 30),
            Text(
              "Mission",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "At RevX, our mission is to revolutionize urban mobility by delivering seamless, "
              "smart, and sustainable transportation experiences. We aim to empower individuals "
              "and businesses with flexible, secure, and efficient mobility services that adapt to "
              "the needs of tomorrow.",
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
