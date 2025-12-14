import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app/config/email_config.dart';
import 'package:firebase_app/utils/price_formatter.dart';

class EmailService {
  static final smtpServer = gmail(
    EmailConfig.emailUsername,
    EmailConfig.emailPassword,
  );

  static Future<bool> sendBookingConfirmation({
    required String userEmail,
    required String userName,
    required String carName,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    try {
      final message =
          Message()
            ..from = Address(EmailConfig.emailUsername, EmailConfig.companyName)
            ..recipients.add(userEmail)
            ..subject = EmailConfig.bookingSubject
            ..html = '''
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2>Hello $userName,</h2>
            <p>Thank you for choosing ${EmailConfig.companyName}!</p>
            
            <div style="background-color: #f5f5f5; padding: 20px; border-radius: 8px;">
              <h3>Booking Details:</h3>
              <p>Car: $carName</p>
              <p>From: ${DateFormat('dd MMM yyyy').format(startDate)}</p>
              <p>To: ${DateFormat('dd MMM yyyy').format(endDate)}</p>
              <p>Total: ${PriceFormatter.formatPrice(totalPrice)}</p>
            </div>

            <p>Need help? Contact us:</p>
            <ul>
              <li>Email: ${EmailConfig.supportEmail}</li>
              <li>Phone: ${EmailConfig.phoneNumber}</li>
              <li>Website: ${EmailConfig.websiteUrl}</li>
            </ul>
          </div>
        ''';

      await send(message, smtpServer);
      return true;
    } catch (e) {
      print('Failed to send email: $e');
      return false;
    }
  }
}
