import 'package:flutter/material.dart';

class RentalAgreementPage extends StatelessWidget {
  const RentalAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rental Agreement")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: const [
            Text(
              "Rental Agreement",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "This Rental Agreement (“Agreement”) is entered into between the user (“Renter”) and RevX (“Company”), and outlines the terms and conditions of vehicle rental.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "1. Vehicle Use",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- The Renter agrees to use the vehicle solely for personal or business purposes.\n"
              "- Unauthorized commercial use, illegal activities, or sub-renting is strictly prohibited.\n"
              "- The Renter must comply with all traffic laws and regulations.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "2. Driver Requirements",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- The driver must be at least 21 years old and possess a valid driver’s license.\n"
              "- The license must be valid for the duration of the rental period.\n"
              "- Additional drivers must be registered and approved by the Company.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "3. Rental Period",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- The rental period begins at the designated pickup time and ends upon return of the vehicle.\n"
              "- Late returns may incur additional fees.\n"
              "- Early returns are not subject to refunds unless otherwise specified.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "4. Payment & Deposit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- Full payment must be made prior to vehicle pickup.\n"
              "- A security deposit may be required and will be refunded after inspection.\n"
              "- Additional charges may apply for fuel, tolls, or damages.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "5. Insurance & Damages",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- The vehicle is covered by standard insurance as per legal requirements.\n"
              "- The Renter is responsible for any damages not covered by insurance.\n"
              "- In case of an accident, the Renter must notify both the police and the Company immediately.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 20),
            Text(
              "6. Termination & Breach",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "- The Company reserves the right to terminate the agreement in case of violation of terms.\n"
              "- Any unlawful activity will result in immediate termination and legal action.\n"
              "- The Renter is liable for any losses incurred due to contract breach.",
              style: TextStyle(fontSize: 16, height: 1.6),
            ),

            SizedBox(height: 30),
            Text(
              "By renting a vehicle from RevX, the Renter acknowledges and agrees to all terms and conditions stated in this agreement.",
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
