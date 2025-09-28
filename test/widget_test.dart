// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:familycal/models/event.dart';
import 'package:familycal/utils/recurrence_utils.dart';

void main() {
  test('RecurrenceUtils returns original event when no rule', () {
    final event = CalendarEvent(
      id: 'e1',
      calendarId: 'c1',
      householdId: 'h1',
      authorId: 'u1',
      title: 'Termin',
      start: DateTime(2025, 1, 1, 10),
      end: DateTime(2025, 1, 1, 11),
      category: 'allgemein',
      visibility: 'household',
      participantIds: const ['u1'],
    );
    final list = RecurrenceUtils.expandOccurrences(
      event: event,
      from: DateTime(2024, 12, 31),
      to: DateTime(2025, 1, 2),
    );
    expect(list, hasLength(1));
    expect(list.single.id, 'e1');
  });
}
