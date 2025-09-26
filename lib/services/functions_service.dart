import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  FunctionsService(FirebaseFunctions functions) : _functions = functions;
  final FirebaseFunctions _functions;

  Future<void> scheduleReminders({
    required String calendarId,
    required String eventId,
    required List<int> reminderMinutes,
  }) async {
    final callable = _functions.httpsCallable('scheduleEventReminders');
    await callable({
      'calendarId': calendarId,
      'eventId': eventId,
      'reminderMinutes': reminderMinutes,
    });
  }

  Future<void> triggerIcsImport(String url, String calendarId) async {
    final callable = _functions.httpsCallable('importIcs');
    await callable({'url': url, 'calendarId': calendarId});
  }

  Future<String> exportIcs(String calendarId) async {
    final callable = _functions.httpsCallable('exportIcs');
    final result = await callable({'calendarId': calendarId});
    final data = result.data;
    if (data is Map && data['ics'] is String) {
      return data['ics'] as String;
    }
    throw StateError('Ungültige Antwort vom exportIcs Endpoint.');
  }
}

