import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/utils/recurrence_utils.dart';
import 'package:familycal/config/debug_flags.dart';

class EventRepository {
  EventRepository(FirebaseFirestore firestore)
      : _firestore = firestore,
        _events = firestore.collectionGroup('events');

  final FirebaseFirestore _firestore;
  final Query<Map<String, dynamic>> _events;

  bool enableFallback = true; // kann bei Bedarf deaktiviert werden

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

    final controller = StreamController<List<CalendarEvent>>();

    late StreamSubscription sub;
    void emitError(Object error){
      if (DebugFlags.eventLogging) {
        // ignore: avoid_print
        print('[EventRepository] collectionGroup error=$error – Fallback ${enableFallback ? 'aktiv' : 'inaktiv'}');
      }
      if (enableFallback){
        _runFallback(controller, householdId: householdId, from: from, to: to);
      } else {
        controller.addError(error);
      }
    }

    sub = query.snapshots().listen((snapshot) async {
      try {
        final docs = snapshot.docs;
        if (docs.isEmpty && enableFallback){
          if (DebugFlags.eventLogging) {
            // ignore: avoid_print
            print('[EventRepository] collectionGroup leer – versuche Fallback');
          }
          await _runFallback(controller, householdId: householdId, from: from, to: to);
          return;
        }
        final events = docs
            .map(CalendarEvent.fromFirestore)
            .expand((event) => RecurrenceUtils.expandOccurrences(event: event, from: from, to: to))
            .toList()
          ..sort((a,b)=> a.start.compareTo(b.start));
        controller.add(events);
      } catch (e){ emitError(e); }
    }, onError: emitError, onDone: (){ controller.close(); });

    controller.onCancel = (){ sub.cancel(); };
    return controller.stream;
  }

  Future<void> _runFallback(StreamController<List<CalendarEvent>> controller, {required String householdId, required DateTime from, required DateTime to}) async {
    try {
      final calendarsSnap = await _firestore.collection('calendars').where('householdId', isEqualTo: householdId).get();
      final List<CalendarEvent> all = [];
      for (final cal in calendarsSnap.docs){
        final eventsSnap = await cal.reference.collection('events')
          .where('start', isLessThanOrEqualTo: Timestamp.fromDate(to))
          .get();
        for (final doc in eventsSnap.docs){
          final data = doc.data();
          // Filter lokal (start >= expandedFrom, <= to)
          final startTs = (data['start'] as Timestamp?)?.toDate();
          if (startTs == null) continue;
          if (startTs.isAfter(to)) continue;
          // Ende des Fensters wird weiter unten beim Expand beachtet
          final event = CalendarEvent.fromFirestore(doc);
          all.addAll(RecurrenceUtils.expandOccurrences(event: event, from: from, to: to));
        }
      }
      all.sort((a,b)=> a.start.compareTo(b.start));
      // ignore: avoid_print
      if (DebugFlags.eventLogging) {
        // ignore: avoid_print
        print('[EventRepository] Fallback lieferte ${all.length} Events');
      }
      controller.add(all);
    } catch (e){
      // ignore: avoid_print
      if (DebugFlags.eventLogging) {
        // ignore: avoid_print
        print('[EventRepository] Fallback Fehler: $e');
      }
      controller.addError(e);
    }
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
