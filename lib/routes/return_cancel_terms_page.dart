import 'package:flutter/material.dart';

class ReturnCancelTermsPage extends StatelessWidget {
  const ReturnCancelTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Return & Cancellation Terms")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Return & Cancellation Terms",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "At RevX, we prioritize flexibility and customer satisfaction in all our services. Please read our return and cancellation terms carefully before booking a vehicle.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "1. Cancellation Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Cancellations made more than 24 hours prior to the scheduled pickup time will be eligible for a full refund.\n"
              "- Cancellations made within 24 hours of the pickup time will incur a 20% cancellation fee.\n"
              "- No-shows or cancellations made after the pickup time are not eligible for a refund.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "2. Modification of Bookings",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Booking modifications (e.g. changes to pickup/drop-off time or vehicle type) are subject to availability.\n"
              "- No extra fee will be charged for modifications made more than 24 hours before pickup.\n"
              "- Changes requested within 24 hours may be charged an administrative fee.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "3. Early Return Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Returning the vehicle earlier than the scheduled drop-off time does not entitle the user to a refund for the unused rental period.\n"
              "- However, under exceptional circumstances, partial refunds may be considered at our discretion.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "4. Late Return Policy",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Delayed returns without prior notice will be charged an additional fee based on the hourly rate.\n"
              "- In the case of delays exceeding 2 hours, a full-day rate may apply.\n"
              "- Consistent late returns may result in account suspension.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "5. Exceptional Situations",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "In the event of emergencies, weather disruptions, or unforeseen travel restrictions, we encourage customers to contact our support team. We strive to be as accommodating as possible under such circumstances.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 30),
            Text(
              "By completing a reservation, you agree to the terms outlined above. For additional support, please contact our customer service team at any time.",
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
