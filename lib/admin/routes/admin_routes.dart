import 'package:firebase_app/admin/screens/gift_vouchers_screen.dart';
import 'package:firebase_app/admin/screens/discount_management_screen.dart';
import 'package:firebase_app/admin/screens/corporate_rental_management_screen.dart';
import 'package:firebase_app/admin/screens/corporate_payment_management_screen.dart';
import 'package:firebase_app/admin/screens/cancellation_management_screen.dart';
import 'package:flutter/material.dart';

class AdminRoutes {
  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/admin/gift-vouchers': (context) => const GiftVouchersScreen(),
      '/admin/discount-management':
          (context) => const DiscountManagementScreen(),
      '/admin/corporate-rentals':
          (context) => const CorporateRentalManagementScreen(),
      '/admin/corporate-payments':
          (context) => const CorporatePaymentManagementScreen(),
      '/cancellation_management':
          (context) => const CancellationManagementScreen(),
    };
  }
}
