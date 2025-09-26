import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/services/repositories/event_repository.dart';

class EventController {
  EventController({required FirebaseFirestore firestore}) : _repository = EventRepository(firestore);
  final EventRepository _repository;

  StreamSubscription<List<CalendarEvent>> watchRange({
    required String householdId,
    required DateTime from,
    required DateTime to,
    required void Function(List<CalendarEvent> events) onData,
  }) {
    return _repository.watchEvents(householdId: householdId, from: from, to: to).listen(onData);
  }
}

