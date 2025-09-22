import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarEvent {
  CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.householdId,
    required this.title,
    required this.start,
    required this.end,
    required this.category,
    required this.visibility,
    required this.participantIds,
    this.location,
    this.notes,
    this.recurrenceRule,
    this.exceptionDates = const <DateTime>[],
    this.reminderMinutes = const <int>[30],
  });

  factory CalendarEvent.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return CalendarEvent(
      id: doc.id,
      calendarId: data['calendarId'] as String? ?? '',
      householdId: data['householdId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      start: (data['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (data['end'] as Timestamp?)?.toDate() ?? DateTime.now(),
      category: data['category'] as String? ?? 'general',
      visibility: data['visibility'] as String? ?? 'household',
      participantIds: List<String>.from(data['participantIds'] as List? ?? <String>[]),
      location: data['location'] as String?,
      notes: data['notes'] as String?,
      recurrenceRule: data['recurrenceRule'] as String?,
      exceptionDates: (data['exceptionDates'] as List?)
              ?.map((value) => (value as Timestamp).toDate())
              .toList() ??
          <DateTime>[],
      reminderMinutes: List<int>.from(data['reminderMinutes'] as List? ?? <int>[30]),
    );
  }

  final String id;
  final String calendarId;
  final String householdId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String category;
  final String visibility;
  final List<String> participantIds;
  final String? location;
  final String? notes;
  final String? recurrenceRule;
  final List<DateTime> exceptionDates;
  final List<int> reminderMinutes;

  Map<String, dynamic> toJson() {
    return {
      'calendarId': calendarId,
      'householdId': householdId,
      'title': title,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'category': category,
      'visibility': visibility,
      'participantIds': participantIds,
      'location': location,
      'notes': notes,
      'recurrenceRule': recurrenceRule,
      'exceptionDates': exceptionDates.map(Timestamp.fromDate).toList(),
      'reminderMinutes': reminderMinutes,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? calendarId,
    String? householdId,
    String? title,
    DateTime? start,
    DateTime? end,
    String? category,
    String? visibility,
    List<String>? participantIds,
    String? location,
    String? notes,
    String? recurrenceRule,
    List<DateTime>? exceptionDates,
    List<int>? reminderMinutes,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      calendarId: calendarId ?? this.calendarId,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      participantIds: participantIds ?? this.participantIds,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      exceptionDates: exceptionDates ?? this.exceptionDates,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }
}
