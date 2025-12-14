import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class SuccessScreen extends StatelessWidget {
  final String carName;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final String message;
  final String subMessage;
  final String bookingId; // Add this
  final String paymentId; // Add this
  final VoidCallback onButtonPressed;

  const SuccessScreen({
    Key? key,
    required this.carName,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.message,
    required this.subMessage,
    required this.bookingId, // Add this
    required this.paymentId, // Add this
    required this.onButtonPressed,
  }) : super(key: key);

  String formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("Booking Confirmed"),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        // Add ScrollView
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Icon(Icons.check_circle_outline, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              Text(
                "Your Booking is Confirmed!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Updated booking details section
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDetailRow('Car', carName),
                      const Divider(height: 24),
                      _buildDetailRow('From', formatDate(startDate)),
                      _buildDetailRow('To', formatDate(endDate)),
                      const Divider(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Total Paid',
                            PriceFormatter.formatPrice(totalPrice),
                          ),
                          if (totalPrice < totalPrice) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                PriceFormatter.formatPrice(totalPrice),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Divider(height: 24),
                      _buildDetailRow('Booking ID', bookingId),
                      const SizedBox(height: 8),
                      _buildDetailRow('Payment ID', paymentId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40), // Replace Spacer with fixed height
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  "Return to Home",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24), // Add bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            // Changed to SelectableText for copy functionality
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

// Example function to navigate to SuccessScreen (call this from your widget logic)
void navigateToSuccessScreen(
  BuildContext context,
  DateTime startDate,
  DateTime endDate,
  double totalPrice,
) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder:
          (context) => SuccessScreen(
            carName: 'Car Name',
            startDate: startDate,
            endDate: endDate,
            totalPrice: totalPrice,
            message: 'Success',
            subMessage: 'Your booking is confirmed',
            bookingId: 'BOOK-123', // Add this
            paymentId: 'PAY-456', // Add this
            onButtonPressed: () {
              // Your button action
            },
          ),
    ),
  );
}
