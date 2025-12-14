import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("About Us")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Welcome to RevX – where innovation drives mobility forward.",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                "At RevX, we are committed to redefining how the world experiences transportation. "
                "From seamless car rental solutions to advanced customer-focused technologies, "
                "our goal is to deliver efficiency, comfort, and sustainability at every journey’s start.\n\n"
                "Founded on the principles of trust, transparency, and innovation, RevX is more than a mobility service — "
                "it’s a smarter way to move. We prioritize user experience, data security, and a customer-first approach in all we do.\n\n"
                "Join thousands of users who choose RevX for their travel, business, and lifestyle needs. "
                "Because at RevX, it's not just about getting from point A to B — it's about how great the journey can be.\n\n"
                "RevX. Drive Forward.",
                style: TextStyle(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
