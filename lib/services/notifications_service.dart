import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationsService {
  NotificationsService(FirebaseMessaging messaging) : _messaging = messaging;
  final FirebaseMessaging _messaging;

  Future<void> requestPermissions() async {
    final settings = await _messaging.requestPermission();
    if (kDebugMode) {
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
    }
  }

  Future<String?> getDeviceToken() async {
    return _messaging.getToken();
  }
}

