import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/utils/recurrence_utils.dart';

class EventRepository {
  EventRepository(FirebaseFirestore firestore)
      : _events = firestore.collectionGroup('events');

  final Query<Map<String, dynamic>> _events;

  Stream<List<CalendarEvent>> watchEvents({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) {
    final expandedFrom = from.subtract(const Duration(days: 365));
    final startTimestamp = Timestamp.fromDate(expandedFrom);
    final endTimestamp = Timestamp.fromDate(to);

    final query = _events
        .where('householdId', isEqualTo: householdId)
        .where('start', isGreaterThanOrEqualTo: startTimestamp)
        .where('start', isLessThanOrEqualTo: endTimestamp);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(CalendarEvent.fromFirestore)
          .expand(
            (event) => RecurrenceUtils.expandOccurrences(
              event: event,
              from: from,
              to: to,
            ),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  Future<String> createEvent(CalendarEvent event) async {
    final eventsCollection = FirebaseFirestore.instance
        .collection('calendars')
        .doc(event.calendarId)
        .collection('events');
    final doc = event.id.isEmpty
        ? eventsCollection.doc()
        : eventsCollection.doc(event.id);
    final payload = event.copyWith(id: doc.id).toJson();
    await doc.set(payload);
    return doc.id;
  }

  Future<void> updateEvent(CalendarEvent event) async {
    final eventsCollection = FirebaseFirestore.instance
        .collection('calendars')
        .doc(event.calendarId)
        .collection('events');
    await eventsCollection.doc(event.id).set(event.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteEvent(CalendarEvent event) async {
    final eventsCollection = FirebaseFirestore.instance
        .collection('calendars')
        .doc(event.calendarId)
        .collection('events');
    await eventsCollection.doc(event.id).delete();
  }
}

