import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_app/screens/success_screen.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String carName;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalPrice;
  final String bookingId;
  final String paymentId;

  const PaymentSuccessScreen({
    Key? key,
    required this.carName,
    this.startDate,
    this.endDate,
    required this.totalPrice,
    required this.bookingId,
    required this.paymentId,
  }) : super(key: key);

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Navigate to SuccessScreen when animation completes
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => SuccessScreen(
                  carName: widget.carName,
                  startDate: widget.startDate ?? DateTime.now(),
                  endDate:
                      widget.endDate ??
                      DateTime.now().add(const Duration(days: 1)),
                  totalPrice: widget.totalPrice,
                  message: 'Payment Successful!',
                  subMessage:
                      'Your booking has been confirmed. Check your email for details.',
                  bookingId: widget.bookingId,
                  paymentId: widget.paymentId,
                  onButtonPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/Animation.json',
          controller: _controller,
          onLoaded: (composition) {
            _controller.forward();
          },
          width: 300,
          height: 300,
        ),
      ),
    );
  }
}
