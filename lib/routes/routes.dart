import 'package:firebase_app/admin/screens/admin_panel_screen.dart';
import 'package:firebase_app/admin/screens/cancellation_management_screen.dart';
import 'package:firebase_app/admin/screens/payment_detail_screen.dart';
import 'package:firebase_app/admin/screens/payment_list_screen.dart';
import 'package:firebase_app/admin/screens/rental_detail_screen.dart';
import 'package:firebase_app/admin/screens/rental_list_screen.dart';
import 'package:firebase_app/admin/screens/rental_management_screen.dart';
import 'package:firebase_app/admin/screens/reporting_screen.dart';
import 'package:firebase_app/admin/screens/vehicle_maintenance_screen.dart';
import 'package:firebase_app/car_model.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/profile_tab.dart';
import 'package:firebase_app/screens/booking_screen.dart';
import 'package:firebase_app/screens/car_detail_screen.dart';
import 'package:firebase_app/screens/login_screen.dart';
import 'package:firebase_app/screens/add_driver_license_screen.dart';
import 'package:flutter/material.dart';

import 'about_us_page.dart';
import 'vision_mission_page.dart';
import 'our_values_page.dart';
import 'info_society_services_page.dart';
import 'personal_data_protection_page.dart';
import 'quality_policy_page.dart';
import 'privacy_policy_page.dart';
import 'legal_warning_page.dart';
import 'return_cancel_terms_page.dart';
import 'rental_agreement_page.dart';
import 'faq_page.dart';
import 'reservation_cancellation_form_page.dart';
import 'corporate_cancellation_form_page.dart';
import 'corporate_rental_reservation_form_page.dart';
import 'gift_voucher_page.dart';
import 'contact_center_page.dart';
import 'e_bulletin_page.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/about_us': (context) => const AboutUsPage(),
  '/vision_mission': (context) => const VisionMissionPage(),
  '/our_values': (context) => const OurValuesPage(),
  '/info_society_services': (context) => const InfoSocietyServicesPage(),
  '/personal_data_protection': (context) => const PersonalDataProtectionPage(),
  '/quality_policy': (context) => const QualityPolicyPage(),
  '/privacy_policy': (context) => const PrivacyPolicyPage(),
  '/legal_warning': (context) => const LegalWarningPage(),
  '/return_cancel_terms': (context) => const ReturnCancelTermsPage(),
  '/rental_agreement': (context) => const RentalAgreementPage(),
  '/faq': (context) => const FaqPage(),
  '/reservation_cancellation_form':
      (context) => const ReservationCancellationFormPage(),
  '/corporate_cancellation_form':
      (context) => const CorporateCancellationFormPage(),
  '/corporate_rental_reservation_form':
      (context) => const CorporateRentalReservationFormPage(),
  '/gift_voucher': (context) => const GiftVoucherPage(),
  '/contact_center': (context) => const ContactCenterPage(),
  '/e_bulletin': (context) => const EBulletinPage(),

  '/booking':
      (context) =>
          BookingScreen(car: ModalRoute.of(context)!.settings.arguments as Car),
  '/admin/rentals': (context) => RentalManagementScreen(),
  '/rental_list': (context) => const RentalListScreen(),
  '/rental_detail': (context) {
    final rentalId = ModalRoute.of(context)!.settings.arguments as String;
    return RentalDetailScreen(bookingId: rentalId);
  },
  '/payment_list': (context) => PaymentListScreen(),
  '/payment_detail':
      (context) => PaymentDetailScreen(
        paymentId: ModalRoute.of(context)!.settings.arguments as String,
      ),
  '/admin/vehicle_maintenance':
      (context) => const VehicleMaintenanceScreen(carId: 'carId'),
  '/add-driver-license': (context) => const AddDriverLicenseScreen(),
  '/home': (context) => const HomeScreen(), // Same as above
  '/admin': (context) => const AdminPanelScreen(),
  '/login': (context) => const LoginScreen(),
  '/profile': (context) => const ProfileTab(),
  '/admin/cancellations': (context) => const CancellationManagementScreen(),
  '/car-details': (context) {
    final carId = ModalRoute.of(context)!.settings.arguments as String;
    return CarDetailScreen(carId: carId);
  },

  // Admin panel route
  // Add other routes as needed
};
