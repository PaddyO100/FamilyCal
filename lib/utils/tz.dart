import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeZoneHelper {
  static Future<void> ensureInitialized() async {
    Intl.defaultLocale = WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
  }

  static String formattedOffset(DateTime dateTime) {
    final duration = dateTime.timeZoneOffset;
    final sign = duration.isNegative ? '-' : '+';
    final hours = duration.inHours.abs().toString().padLeft(2, '0');
    final minutes = (duration.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  static void debugLogCurrentZone() {
    if (kDebugMode) {
      debugPrint('Current time zone: ${DateTime.now().timeZoneName}');
    }
  }
}

