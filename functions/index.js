const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: 'your-email@gmail.com',
        pass: 'your-app-password'
    }
});

exports.sendBookingConfirmation = functions.firestore
    .document('bookings/{bookingId}')
    .onCreate(async (snap, context) => {
        const booking = snap.data();

        try {
            const userDoc = await admin.firestore()
                .collection('users')
                .doc(booking.userId)
                .get();

            const userEmail = userDoc.data().email;

            const mailOptions = {
                from: 'RevX Car Rental <your-email@gmail.com>',
                to: userEmail,
                subject: 'Booking Confirmation - RevX Car Rental',
                html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #e53935;">Booking Confirmation</h2>
            <p>Thank you for choosing RevX Car Rental!</p>
            
            <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
              <h3 style="color: #e53935;">Booking Details:</h3>
              <ul style="list-style: none; padding: 0;">
                <li><strong>Vehicle:</strong> ${booking.carName}</li>
                <li><strong>Start Date:</strong> ${booking.startDate.toDate().toLocaleDateString()}</li>
                <li><strong>End Date:</strong> ${booking.endDate.toDate().toLocaleDateString()}</li>
                <li><strong>Total Amount:</strong> ₺${booking.totalAmount.toFixed(2)}</li>
              </ul>
            </div>
            
            <p>Your payment has been successfully processed.</p>
            
            <div style="margin-top: 30px; color: #666;">
              <p>Best regards,<br>RevX Car Rental Team</p>
            </div>
          </div>
        `
            };

            await transporter.sendMail(mailOptions);
            console.log('Confirmation email sent successfully');

        } catch (error) {
            console.error('Error sending confirmation email:', error);
        }
    });