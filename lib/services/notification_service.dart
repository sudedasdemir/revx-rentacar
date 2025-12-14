import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String oneSignalRestApiKey =
      'os_v2_app_mvfazgzqgfgn7jwmva5esvpnew4pbdpfsrke235ct53ssap2pvcg65zvq7rm4ya5r5z74mnzq72i7s6xmsja3az3uvzcwellaent7va';
  static const String oneSignalAppId = '654a0c9b-3031-4cdf-a6cc-a83a4955ed25';

  Future<void> initializeOneSignal() async {
    try {
      print('Initializing OneSignal...');

      // Initialize OneSignal
      OneSignal.initialize(oneSignalAppId);

      // Request permission for notifications
      await OneSignal.User.pushSubscription.optIn();

      // Get the OneSignal user ID
      final oneSignalUserId = OneSignal.User.pushSubscription.id;
      print('OneSignal User ID: $oneSignalUserId');

      // Save the OneSignal user ID to Firestore
      final user = _auth.currentUser;
      if (user != null && oneSignalUserId != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'oneSignalUserId': oneSignalUserId,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        print('Saved OneSignal User ID to Firestore');
      }

      // Handle notification opened
      OneSignal.Notifications.addClickListener((
        OSNotificationClickEvent result,
      ) {
        print('Notification opened: ${result.notification.title}');
      });

      // Handle notification received
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('Notification received: ${event.notification.title}');
      });

      print('OneSignal initialization completed');
    } catch (e) {
      print('Error initializing OneSignal: $e');
    }
  }

  Future<void> sendNotificationViaRestApi(
    Map<String, dynamic> notification,
  ) async {
    try {
      print('Sending notification via REST API...');
      print('Notification data: $notification');

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode(notification),
      );

      print('OneSignal API Response Status: ${response.statusCode}');
      print('OneSignal API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print(
          'Failed to send notification. Status code: ${response.statusCode}',
        );
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification via REST API: $e');
    }
  }

  Future<void> saveUserDeviceToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Get the OneSignal user ID using the new API
        final oneSignalUserId = OneSignal.User.pushSubscription.id;
        print('Current OneSignal User ID: $oneSignalUserId');

        if (oneSignalUserId != null) {
          // Save the OneSignal user ID to Firestore
          await _firestore.collection('users').doc(user.uid).update({
            'oneSignalUserId': oneSignalUserId,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('Updated OneSignal User ID in Firestore');
        } else {
          print('No OneSignal User ID available');
        }
      }
    } catch (e) {
      print('Error saving device token: $e');
    }
  }

  Future<void> sendNotification({
    required String title,
    required String body,
    required String userId,
  }) async {
    try {
      print('Attempting to send notification...');
      print('Title: $title');
      print('Body: $body');
      print('User ID: $userId');

      // Get the user's notification preference
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final notificationsEnabled =
          userDoc.data()?['notificationsEnabled'] ??
          true; // Default to true if not set

      if (!notificationsEnabled) {
        print(
          'Notifications are disabled for user: $userId. Skipping notification.',
        );
        return; // Do not send notification if disabled
      }

      final oneSignalUserId = userDoc.data()?['oneSignalUserId'];

      print('OneSignal User ID from Firestore: $oneSignalUserId');

      if (oneSignalUserId != null) {
        // Create notification content
        final notification = {
          "app_id": oneSignalAppId,
          "include_player_ids": [oneSignalUserId],
          "headings": {"en": title},
          "contents": {"en": body},
          "android_channel_id": "default",
          "priority": 10,
        };

        // Save notification to Firestore
        await _firestore.collection('notifications').add({
          'userId': userId,
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        print('Saved notification to Firestore');

        // Send the notification using OneSignal REST API
        await sendNotificationViaRestApi(notification);
      } else {
        print('No OneSignal user ID found for user: $userId');

        // Try to get a fresh OneSignal user ID
        final freshOneSignalUserId = OneSignal.User.pushSubscription.id;
        print('Fresh OneSignal User ID: $freshOneSignalUserId');

        if (freshOneSignalUserId != null) {
          // Update Firestore with the fresh ID
          await _firestore.collection('users').doc(userId).update({
            'oneSignalUserId': freshOneSignalUserId,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          print('Updated Firestore with fresh OneSignal User ID');

          // Retry sending the notification
          final notification = {
            "app_id": oneSignalAppId,
            "include_player_ids": [freshOneSignalUserId],
            "headings": {"en": title},
            "contents": {"en": body},
            "android_channel_id": "default",
            "priority": 10,
          };

          await sendNotificationViaRestApi(notification);
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
