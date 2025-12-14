import 'package:flutter/material.dart';

class OurValuesPage extends StatelessWidget {
  const OurValuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Our Values"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onBackground),
        titleTextStyle: TextStyle(
          color: theme.colorScheme.onBackground,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          fontFamily: 'PoppinsRegular',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ValueTitle("Innovation"),
            SizedBox(height: 10),
            _ValueText(
              "We believe in constantly evolving and embracing new technologies to create smarter and more efficient solutions that make transportation more accessible and sustainable.",
            ),
            SizedBox(height: 20),

            _ValueTitle("Customer-Centric"),
            SizedBox(height: 10),
            _ValueText(
              "Our customers are at the heart of our business. We listen, understand, and anticipate their needs to deliver outstanding experiences.",
            ),
            SizedBox(height: 20),

            _ValueTitle("Sustainability"),
            SizedBox(height: 10),
            _ValueText(
              "We are committed to reducing our environmental impact through green technologies, sustainable practices, and promoting eco-friendly transportation options.",
            ),
            SizedBox(height: 20),

            _ValueTitle("Integrity & Transparency"),
            SizedBox(height: 10),
            _ValueText(
              "We act with honesty, openness, and fairness in every aspect of our business. Building long-term relationships based on trust is our top priority.",
            ),
            SizedBox(height: 20),

            _ValueTitle("Global Perspective"),
            SizedBox(height: 10),
            _ValueText(
              "We value diverse cultures, markets, and perspectives, and aim to make a positive impact on communities around the world.",
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ValueTitle extends StatelessWidget {
  final String text;
  const _ValueTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.onBackground,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'PoppinsRegular',
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  final String text;
  const _ValueText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.onBackground,
        fontSize: 16,
        height: 1.5,
        fontFamily: 'PoppinsRegular',
      ),
    );
  }
}
