import 'package:flutter_test/flutter_test.dart';

import 'package:familycal/models/event.dart';
import 'package:familycal/utils/recurrence_utils.dart';

void main() {
  group('RecurrenceUtils.expandOccurrences', () {
    test('expands weekly rule with exceptions', () {
      final event = CalendarEvent(
        id: 'base',
        calendarId: 'cal1',
        householdId: 'hh1',
        title: 'Training',
        start: DateTime(2024, 1, 1, 18),
        end: DateTime(2024, 1, 1, 19),
        category: 'sport',
        visibility: 'household',
        participantIds: const ['user1'],
        recurrenceRule: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE',
        exceptionDates: [DateTime(2024, 1, 8, 18)],
      );

      final occurrences = RecurrenceUtils.expandOccurrences(
        event: event,
        from: DateTime(2024, 1, 1),
        to: DateTime(2024, 1, 21),
      );

      expect(occurrences.length, 5);
      expect(occurrences.first.start, DateTime(2024, 1, 1, 18));
      expect(occurrences.map((e) => e.start).contains(DateTime(2024, 1, 8, 18)), isFalse);
    });

    test('returns original event when no recurrence rule present', () {
      final event = CalendarEvent(
        id: 'single',
        calendarId: 'cal1',
        householdId: 'hh1',
        title: 'Arzttermin',
        start: DateTime(2024, 2, 10, 10),
        end: DateTime(2024, 2, 10, 11),
        category: 'health',
        visibility: 'household',
        participantIds: const ['user1'],
      );

      final occurrences = RecurrenceUtils.expandOccurrences(
        event: event,
        from: DateTime(2024, 2, 1),
        to: DateTime(2024, 2, 28),
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.id, 'single');
    });
  });
}
