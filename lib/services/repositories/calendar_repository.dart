import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/calendar.dart';

class CalendarRepository {
  CalendarRepository(FirebaseFirestore firestore)
      : _calendars = firestore.collection('calendars');

  final CollectionReference<Map<String, dynamic>> _calendars;

  Stream<List<HouseholdCalendar>> watchCalendars(String householdId) {
    return _calendars
        .where('householdId', isEqualTo: householdId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HouseholdCalendar.fromFirestore)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name)),
        );
  }

  Future<void> createCalendar(HouseholdCalendar calendar) async {
    await _calendars.doc(calendar.id).set(calendar.toJson());
  }
}

