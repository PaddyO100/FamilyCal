import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/availability.dart';

class AvailabilityRepository {
  AvailabilityRepository(FirebaseFirestore firestore)
      : _availabilities = firestore.collection('availabilities'),
        _summaries = firestore.collection('availabilitySummaries');

  final CollectionReference<Map<String, dynamic>> _availabilities;
  final CollectionReference<Map<String, dynamic>> _summaries;

  Stream<List<DailyAvailability>> watchUserAvailabilities({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = DailyAvailability.dateKey(from);
    final toKey = DailyAvailability.dateKey(to);
    return _availabilities
        .where('userId', isEqualTo: userId)
        .orderBy('dateKey')
        .where('dateKey', isGreaterThanOrEqualTo: fromKey)
        .where('dateKey', isLessThanOrEqualTo: toKey)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DailyAvailability.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<AvailabilitySummary>> watchHouseholdSummaries({
    required String householdId,
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = DailyAvailability.dateKey(from);
    final toKey = DailyAvailability.dateKey(to);
    return _summaries
        .where('householdId', isEqualTo: householdId)
        .orderBy('dateKey')
        .where('dateKey', isGreaterThanOrEqualTo: fromKey)
        .where('dateKey', isLessThanOrEqualTo: toKey)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AvailabilitySummary.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> upsertAvailability(DailyAvailability availability) async {
    final docId = DailyAvailability.docId(availability.date, availability.userId);
    await _availabilities.doc(docId).set({
      ...availability.copyWith(updatedAt: DateTime.now()).toJson(),
      'householdId': availability.householdId,
    }, SetOptions(merge: true));
  }

  Future<void> deleteAvailability({
    required String userId,
    required DateTime date,
  }) async {
    final docId = DailyAvailability.docId(date, userId);
    await _availabilities.doc(docId).delete();
  }
}

