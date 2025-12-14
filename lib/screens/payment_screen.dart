import 'package:flutter/material.dart';
import 'package:firebase_app/colors.dart';
import 'package:firebase_app/screens/success_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app/services/email_service.dart';
import 'package:flutter/services.dart';
import 'package:firebase_app/utils/price_formatter.dart';
import 'package:firebase_app/services/notification_service.dart';
import 'package:firebase_app/screens/payment_success_screen.dart';

Future<void> updateUserTier(String userId, double totalSpent) async {
  String newTier = 'silver';

  if (totalSpent >= 1000000) {
    newTier = 'premium';
  } else if (totalSpent >= 500000) {
    newTier = 'gold';
  }

  await FirebaseFirestore.instance.collection('users').doc(userId).update({
    'userTier': newTier,
  });
}

class PaymentScreen extends StatefulWidget {
  final String carName;
  final String carId;
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalPrice;
  final bool insurance;
  final bool childSeat;
  final String carImage;
  final String pickupLocation;
  final String returnLocation;
  final int? quantity;

  const PaymentScreen({
    Key? key,
    required this.carName,
    required this.carId,
    this.startDate,
    this.endDate,
    required this.totalPrice,
    required this.insurance,
    required this.childSeat,
    required this.carImage,
    required this.pickupLocation,
    required this.returnLocation,
    this.quantity,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();
  bool _isProcessing = false;
  List<Map<String, dynamic>> _availableVouchers = [];
  bool _showVoucherSelection = false;
  String? _selectedVoucherId;
  double _voucherAmount = 0;
  bool _termsAccepted = false;
  bool _isTermsExpanded = false;

  // Add focus nodes
  final _cardNumberFocus = FocusNode();
  final _expiryDateFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _cardHolderFocus = FocusNode();

  // Error states for live validation
  String? _cardHolderError;
  String? _cardNumberError;
  String? _expiryDateError;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_formatCardNumber);
    _cardHolderController.addListener(_validateCardHolderLive);
    _expiryDateController.addListener(_validateExpiryDateLive);

    // Add focus listeners
    _cardNumberFocus.addListener(() {
      if (!_cardNumberFocus.hasFocus) {
        _validateCardNumber(_cardNumberController.text);
      }
    });

    _expiryDateFocus.addListener(() {
      if (!_expiryDateFocus.hasFocus) {
        _validateExpiryDate(_expiryDateController.text);
      }
    });

    _cvvFocus.addListener(() {
      if (!_cvvFocus.hasFocus) {
        _validateCVV(_cvvController.text);
      }
    });

    _loadAvailableVouchers();
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_formatCardNumber);
    _cardHolderController.removeListener(_validateCardHolderLive);
    _expiryDateController.removeListener(_validateExpiryDateLive);

    // Dispose focus nodes
    _cardNumberFocus.dispose();
    _expiryDateFocus.dispose();
    _cvvFocus.dispose();
    _cardHolderFocus.dispose();

    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  void _formatCardNumber() {
    var text = _cardNumberController.text.replaceAll(' ', '');
    if (text.length > 16) {
      text = text.substring(0, 16);
    }

    var formattedText = '';
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formattedText += ' ';
      }
      formattedText += text[i];
    }

    if (formattedText != _cardNumberController.text) {
      _cardNumberController.text = formattedText;
      _cardNumberController.selection = TextSelection.fromPosition(
        TextPosition(offset: formattedText.length),
      );
    }
  }

  void _validateCardHolderLive() {
    final value = _cardHolderController.text;
    if (value.isEmpty) {
      setState(() => _cardHolderError = null);
    } else if (RegExp(r'[0-9]|[^a-zA-Z\s]').hasMatch(value)) {
      setState(() => _cardHolderError = "Enter the correct name");
    } else {
      setState(() => _cardHolderError = null);
    }
  }

  void _validateExpiryDateLive() {
    final value = _expiryDateController.text;
    if (value.isEmpty) {
      setState(() => _expiryDateError = null);
      return;
    }
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      setState(() => _expiryDateError = "Enter the correct date");
      return;
    }
    final parts = value.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) {
      setState(() => _expiryDateError = "Enter the correct date");
      return;
    }
    if (year == null || year < 25 || year > 36) {
      setState(() => _expiryDateError = "Enter the correct date");
      return;
    }
    setState(() => _expiryDateError = null);
  }

  void _validateCardNumber(String value) {
    final digitsOnly = value.replaceAll(' ', '');
    if (digitsOnly.isEmpty) {
      setState(() => _cardNumberError = "Please enter card number");
    } else if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
      setState(() => _cardNumberError = "Enter the number correctly");
    } else if (digitsOnly.length < 16) {
      setState(
        () => _cardNumberError = "Please enter the card number correctly",
      );
    } else {
      setState(() => _cardNumberError = null);
    }
  }

  void _validateExpiryDate(String value) {
    if (value.isEmpty) {
      setState(() => _expiryDateError = "Required");
    } else if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
      setState(() => _expiryDateError = "Enter the correct date");
    } else {
      final parts = value.split('/');
      final month = int.tryParse(parts[0]);
      final year = int.tryParse(parts[1]);
      if (month == null || month < 1 || month > 12) {
        setState(() => _expiryDateError = "Enter the correct date");
      } else if (year == null || year < 25 || year > 36) {
        setState(() => _expiryDateError = "Enter the correct date");
      } else {
        setState(() => _expiryDateError = null);
      }
    }
  }

  void _validateCVV(String value) {
    if (value.length != 3) {
      setState(() {
        // You might want to add a CVV error state variable
      });
    }
  }

  Future<void> _loadAvailableVouchers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final vouchersSnapshot =
          await FirebaseFirestore.instance
              .collection('gift_vouchers')
              .where('recipientEmail', isEqualTo: user.email)
              .where('status', isEqualTo: 'approved')
              .get();

      if (mounted) {
        setState(() {
          _availableVouchers =
              vouchersSnapshot.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
        });
      }
    } catch (e) {
      print('Error loading vouchers: $e');
    }
  }

  double get _finalPrice {
    return widget.totalPrice - _voucherAmount;
  }

  void _processPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions to proceed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // First check if the car is available and has enough stock
      final carDoc =
          await FirebaseFirestore.instance
              .collection('cars')
              .doc(widget.carId)
              .get();

      if (!carDoc.exists) {
        throw Exception('Car not found');
      }

      final carData = carDoc.data()!;
      final availableStock = carData['stock'] as int? ?? 0;
      final quantity = widget.quantity ?? 1;

      // Check if there's enough stock available
      if (availableStock < quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough vehicles available in stock. Available: $availableStock',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }

      // Check for date conflicts
      final bookingsSnapshot =
          await FirebaseFirestore.instance
              .collection('bookings')
              .where('carId', isEqualTo: widget.carId)
              .where('status', whereIn: ['active', 'ongoing', 'upcoming'])
              .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final bookedStart = (data['startDate'] as Timestamp?)?.toDate();
        final bookedEnd = (data['endDate'] as Timestamp?)?.toDate();

        if (bookedStart != null &&
            bookedEnd != null &&
            widget.startDate?.isBefore(bookedEnd) == true &&
            widget.endDate?.isAfter(bookedStart) == true) {
          throw Exception('Car is not available for the selected dates');
        }
      }

      // Save payment and booking details
      final ids = await _savePaymentAndBooking();
      final bookingId = ids['bookingId'] ?? '';
      final paymentId = ids['paymentId'] ?? '';

      if (!mounted) return;

      // Update available stock
      await FirebaseFirestore.instance
          .collection('cars')
          .doc(widget.carId)
          .update({'stock': availableStock - quantity});

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String userId = user.uid;
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
        final totalSpent = (userDoc.data()?['totalSpent'] ?? 0).toDouble();
        await updateUserTier(userId, totalSpent);

        // Send notification to user
        await NotificationService().sendNotification(
          title: 'Car Rental Confirmed',
          body:
              'Your rental for ${widget.carName} has been confirmed. Pickup: ${widget.startDate?.toString().split('.')[0]}',
          userId: user.uid,
        );

        // Send notification to all admins
        final adminDocs =
            await FirebaseFirestore.instance
                .collection('users')
                .where('isAdmin', isEqualTo: true)
                .get();

        for (var adminDoc in adminDocs.docs) {
          final adminId = adminDoc.id;
          await NotificationService().sendNotification(
            title: 'New Rental Booking',
            body:
                'New rental booking for ${widget.carName} by ${userDoc.data()?['name'] ?? 'User'}. Booking ID: $bookingId',
            userId: adminId,
          );
        }
      }

      // Show success message and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Payment successful! You will receive a confirmation email shortly.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to success screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => PaymentSuccessScreen(
                carName: widget.carName,
                startDate: widget.startDate,
                endDate: widget.endDate,
                totalPrice: _finalPrice,
                bookingId: bookingId,
                paymentId: paymentId,
              ),
        ),
      );
    } catch (e) {
      print('Payment error: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<Map<String, String>> _savePaymentAndBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    String bookingId = '';
    String paymentId = '';

    // Run transaction for atomic writes
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final firestore = FirebaseFirestore.instance;

      final carRef = firestore.collection('cars').doc(widget.carId.trim());
      final carDoc = await transaction.get(carRef);

      if (!carDoc.exists) {
        throw Exception('Car not found');
      }

      // Get user data to check if corporate
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      final isCorporate = userDoc.data()?['isCorporate'] ?? false;
      final companyName = userDoc.data()?['companyName'];
      final userName = userDoc.data()?['name'] ?? 'N/A';

      // Check if there's an existing pending booking for this car and user
      final existingBookingQuery =
          await firestore
              .collection('bookings')
              .where('userId', isEqualTo: user.uid)
              .where('carId', isEqualTo: widget.carId.trim())
              .where('status', isEqualTo: 'pending')
              .get();

      if (existingBookingQuery.docs.isNotEmpty) {
        // Update existing booking and payment
        final existingBooking = existingBookingQuery.docs.first;
        bookingId = existingBooking.id;

        final existingPaymentQuery =
            await firestore
                .collection('payments')
                .where('bookingId', isEqualTo: bookingId)
                .get();

        if (existingPaymentQuery.docs.isNotEmpty) {
          paymentId = existingPaymentQuery.docs.first.id;

          // Update existing payment
          transaction.update(firestore.collection('payments').doc(paymentId), {
            'status': 'completed',
            'timestamp': FieldValue.serverTimestamp(),
            'isCorporate': isCorporate,
            if (isCorporate) 'companyName': companyName,
            'userName': userName,
            'voucherAmount': _voucherAmount,
            'finalAmount': _finalPrice,
          });
        }

        // Update existing booking
        final now = DateTime.now();
        final bookingStatus =
            widget.startDate?.isAfter(now) == true ? 'upcoming' : 'active';

        transaction.update(firestore.collection('bookings').doc(bookingId), {
          'status': bookingStatus,
          'updatedAt': FieldValue.serverTimestamp(),
          'isCorporate': isCorporate,
          if (isCorporate) 'companyName': companyName,
          'userName': userName,
          'voucherAmount': _voucherAmount,
          'finalAmount': _finalPrice,
          'quantity': widget.quantity ?? 1,
        });
      } else {
        // Create new payment and booking
        final paymentRef = firestore.collection('payments').doc();
        final bookingRef = firestore.collection('bookings').doc();

        bookingId = bookingRef.id;
        paymentId = paymentRef.id;

        final now = DateTime.now();
        final bookingStatus =
            widget.startDate?.isAfter(now) == true ? 'upcoming' : 'active';

        final paymentData = {
          'userId': user.uid,
          'carId': widget.carId.trim(),
          'carName': widget.carName,
          'carImage': widget.carImage,
          'amount': widget.totalPrice,
          'voucherAmount': _voucherAmount,
          'finalAmount': _finalPrice,
          'timestamp': FieldValue.serverTimestamp(),
          'startDate': Timestamp.fromDate(widget.startDate ?? DateTime.now()),
          'endDate': Timestamp.fromDate(widget.endDate ?? DateTime.now()),
          'status': 'completed',
          'bookingId': bookingId,
          'isCorporate': isCorporate,
          if (isCorporate) 'companyName': companyName,
          'userName': userName,
        };

        final bookingData = {
          'userId': user.uid,
          'carId': widget.carId.trim(),
          'carName': widget.carName,
          'carImage': widget.carImage,
          'startDate': Timestamp.fromDate(widget.startDate ?? DateTime.now()),
          'endDate': Timestamp.fromDate(widget.endDate ?? DateTime.now()),
          'totalAmount': widget.totalPrice,
          'voucherAmount': _voucherAmount,
          'finalAmount': _finalPrice,
          'status': bookingStatus,
          'createdAt': FieldValue.serverTimestamp(),
          'paymentId': paymentId,
          'insurance': widget.insurance,
          'childSeat': widget.childSeat,
          'isCorporate': isCorporate,
          if (isCorporate) 'companyName': companyName,
          'userName': userName,
          'pickupLocation': widget.pickupLocation,
          'returnLocation': widget.returnLocation,
          'quantity': widget.quantity ?? 1,
        };

        final availabilityRef = firestore
            .collection('car_availability')
            .doc('${widget.carId}_${bookingId}');

        final availabilityData = {
          'carId': widget.carId.trim(),
          'bookingId': bookingId,
          'startDate': Timestamp.fromDate(widget.startDate ?? DateTime.now()),
          'endDate': Timestamp.fromDate(widget.endDate ?? DateTime.now()),
          'status': 'booked',
          'createdAt': FieldValue.serverTimestamp(),
        };

        final carUpdateData = {
          'lastBookingId': bookingId,
          'lastBookingDate': FieldValue.serverTimestamp(),
          'bookingCount': FieldValue.increment(1),
        };

        transaction.set(paymentRef, paymentData);
        transaction.set(bookingRef, bookingData);
        transaction.set(availabilityRef, availabilityData);
        transaction.update(carRef, carUpdateData);

        // If a voucher was used, mark it as used
        if (_selectedVoucherId != null) {
          final voucherRef = firestore
              .collection('gift_vouchers')
              .doc(_selectedVoucherId);
          transaction.update(voucherRef, {
            'status': 'used',
            'usedAt': FieldValue.serverTimestamp(),
            'usedInBookingId': bookingId,
          });
        }
      }
    });

    print('Saved payment and booking for car: ${widget.carId}');
    return {'bookingId': bookingId, 'paymentId': paymentId};
  }

  void _showVoucherSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Gift Certificate'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  _availableVouchers.isEmpty
                      ? const Center(child: Text('No available certificates'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableVouchers.length,
                        itemBuilder: (context, index) {
                          final voucher = _availableVouchers[index];
                          final amount = voucher['amount'] ?? 0.0;
                          final isSelfUse = voucher['isSelfUse'] ?? false;
                          final message = voucher['message'] ?? '';
                          final createdAt =
                              (voucher['createdAt'] as Timestamp?)?.toDate() ??
                              DateTime.now();

                          return Card(
                            child: ListTile(
                              title: Text(
                                '${amount.toStringAsFixed(2)} ₺',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSelfUse
                                        ? 'Self-Use Certificate'
                                        : 'Gift Certificate',
                                    style: TextStyle(
                                      color:
                                          isSelfUse
                                              ? Colors.blue
                                              : Colors.green,
                                    ),
                                  ),
                                  if (message.isNotEmpty) Text(message),
                                  Text(
                                    'Created: ${createdAt.toString().split('.')[0]}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Radio<String>(
                                value: voucher['id'],
                                groupValue: _selectedVoucherId,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedVoucherId = value;
                                    _voucherAmount =
                                        (voucher['amount'] ?? 0).toDouble();
                                  });
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedVoucherId = null;
                    _voucherAmount = 0;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Clear Selection'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Payment Details",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 0),
              ],
            ),
            child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter your payment details",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                controller: _cardHolderController,
                label: "Cardholder Name",
                focusNode: _cardHolderFocus,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                validator: (value) {
                  if (value?.isEmpty ?? true) return null;
                  if (RegExp(r'[0-9]|[^a-zA-Z\s]').hasMatch(value!)) {
                    return "Enter the correct name";
                  }
                  return null;
                },
                errorText: _cardHolderError,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _cardNumberController,
                label: "Card Number",
                focusNode: _cardNumberFocus,
                keyboardType: TextInputType.number,
                maxLength: 19,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                  LengthLimitingTextInputFormatter(19),
                ],
                validator: (value) {
                  final digitsOnly = value?.replaceAll(' ', '') ?? '';
                  if (digitsOnly.isEmpty) return "Please enter card number";
                  if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
                    return "Enter the number correctly";
                  }
                  if (digitsOnly.length < 16) {
                    return "Please enter the card number correctly";
                  }
                  return null;
                },
                errorText: _cardNumberError,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildExpiryDateField()),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _cvvController,
                      label: "CVV",
                      focusNode: _cvvFocus,
                      keyboardType: TextInputType.number,
                      maxLength: 3,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator:
                          (value) => value?.length != 3 ? "Invalid CVV" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      isDarkMode
                          ? AppColors.primary.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "${PriceFormatter.formatPrice(widget.totalPrice)}",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (widget.totalPrice < widget.totalPrice) ...[
                              Text(
                                "${PriceFormatter.formatPrice(widget.totalPrice)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_availableVouchers.isNotEmpty)
                      ElevatedButton.icon(
                        onPressed: _showVoucherSelectionDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.card_giftcard),
                        label: Text(
                          _selectedVoucherId != null
                              ? 'Change Gift Certificate'
                              : 'Apply Gift Certificate',
                        ),
                      ),
                    if (_voucherAmount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Gift Certificate Applied",
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            "-${PriceFormatter.formatPrice(_voucherAmount)}",
                            style: TextStyle(fontSize: 16, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Final Amount",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            "${PriceFormatter.formatPrice(_finalPrice)}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (value) {
                            setState(() {
                              _termsAccepted = value ?? false;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _isTermsExpanded = !_isTermsExpanded;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      _isTermsExpanded
                                          ? 'View Less'
                                          : 'View Terms and Conditions',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      _isTermsExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isTermsExpanded) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                isDarkMode
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Approval and Commitment',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'I pay for car reservations and payment transactions that I have made through the RevX application;',
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildBulletPoint(
                              'That I realized it of my own free will and in a free way,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That I have read and accepted the rental conditions, vehicle usage conditions and pay policy,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That I have been clearly informed about the rental period, total pay, payment method, cancellation/refund conditions and insurance coverage,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That I have completed the transactions without any deception, pressure or direction,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That the details of the vehicle I have chosen and the rental period have been approved by me,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That all my personal information is accurate and complete,',
                              isDarkMode,
                            ),
                            _buildBulletPoint(
                              'That I accept the provisions of the Car Rental and Pay Contract offered by RevX,',
                              isDarkMode,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'I clearly declare and commit.',
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  // Show confirmation dialog
                  final shouldCancel = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Cancel Payment'),
                          content: const Text(
                            'Are you sure you want to cancel this payment? The booking will be marked as pending.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('No, Continue'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Yes, Cancel'),
                            ),
                          ],
                        ),
                  );

                  if (shouldCancel == true && mounted) {
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        // Create a pending payment record
                        final paymentRef = await FirebaseFirestore.instance
                            .collection('payments')
                            .add({
                              'userId': user.uid,
                              'carId': widget.carId,
                              'carName': widget.carName,
                              'amount': widget.totalPrice,
                              'timestamp': FieldValue.serverTimestamp(),
                              'startDate': Timestamp.fromDate(widget.startDate ?? DateTime.now()),
                              'endDate': Timestamp.fromDate(widget.endDate ?? DateTime.now()),
                              'status': 'pending',
                              'insurance': widget.insurance,
                              'childSeat': widget.childSeat,
                            });

                        // Create a pending booking record
                        final bookingRef = await FirebaseFirestore.instance
                            .collection('bookings')
                            .add({
                              'userId': user.uid,
                              'carId': widget.carId,
                              'carName': widget.carName,
                              'carImage': widget.carImage,
                              'startDate': Timestamp.fromDate(widget.startDate ?? DateTime.now()),
                              'endDate': Timestamp.fromDate(widget.endDate ?? DateTime.now()),
                              'totalAmount': widget.totalPrice,
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                              'paymentId': paymentRef.id,
                              'insurance': widget.insurance,
                              'childSeat': widget.childSeat,
                            });

                        // Update the payment with bookingId and carImage
                        await FirebaseFirestore.instance
                            .collection('payments')
                            .doc(paymentRef.id)
                            .update({
                              'bookingId': bookingRef.id,
                              'carImage': widget.carImage,
                            });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Booking saved as pending. You can complete the payment later.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving booking: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Confirm Payment",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    FocusNode? focusNode,
  }) {
    return Builder(
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.grey[300] : AppColors.textSecondary,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
            counterText: "",
            errorText: errorText,
          ),
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          keyboardType: keyboardType,
          maxLength: maxLength,
          validator: validator,
          inputFormatters: inputFormatters,
          onEditingComplete: () {
            // Move to next field or submit
            if (focusNode == _cardNumberFocus) {
              _expiryDateFocus.requestFocus();
            } else if (focusNode == _expiryDateFocus) {
              _cvvFocus.requestFocus();
            } else if (focusNode == _cvvFocus) {
              _cardHolderFocus.requestFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
        );
      },
    );
  }

  Widget _buildExpiryDateField() {
    return TextFormField(
      controller: _expiryDateController,
      focusNode: _expiryDateFocus,
      keyboardType: TextInputType.number,
      maxLength: 5,
      decoration: InputDecoration(
        labelText: "MM/YY",
        counterText: "",
        errorText: _expiryDateError,
        hintText: "MM/YY",
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      onChanged: (value) {
        // Remove any non-digit characters
        final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

        // Format the text
        if (digitsOnly.length > 0) {
          String formattedText = digitsOnly;

          // Add forward slash after 2 digits
          if (digitsOnly.length > 2) {
            final month = int.tryParse(digitsOnly.substring(0, 2));
            if (month != null && month >= 1 && month <= 12) {
              formattedText =
                  '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
            } else {
              // If invalid month, keep only the first digit
              formattedText = digitsOnly.substring(0, 1);
            }
          }

          // Only update if the text has changed
          if (formattedText != value) {
            _expiryDateController.text = formattedText;
            _expiryDateController.selection = TextSelection.fromPosition(
              TextPosition(offset: _expiryDateController.text.length),
            );
          }
        }
      },
      onEditingComplete: () {
        _cvvFocus.requestFocus();
      },
      validator: (value) {
        if (value?.isEmpty ?? true) return "Required";
        if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value!)) {
          return "Enter the correct date";
        }
        final parts = value.split('/');
        final month = int.tryParse(parts[0]);
        final year = int.tryParse(parts[1]);
        if (month == null || month < 1 || month > 12) {
          return "Enter the correct date";
        }
        if (year == null || year < 25 || year > 36) {
          return "Enter the correct date";
        }
        return null;
      },
    );
  }

  Widget _buildBulletPoint(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
