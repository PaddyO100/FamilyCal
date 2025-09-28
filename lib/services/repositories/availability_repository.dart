import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/availability.dart';

class AvailabilityRepository {
  AvailabilityRepository(FirebaseFirestore firestore)
      : _availabilities = firestore.collection('availabilities'),
        _summaries = firestore.collection('availabilitySummaries');

  final CollectionReference<Map<String, dynamic>> _availabilities;
  final CollectionReference<Map<String, dynamic>> _summaries;

  bool enableFallback = true;

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

    final baseQuery = _summaries
        .where('householdId', isEqualTo: householdId)
        .orderBy('dateKey')
        .where('dateKey', isGreaterThanOrEqualTo: fromKey)
        .where('dateKey', isLessThanOrEqualTo: toKey);

    final controller = StreamController<List<AvailabilitySummary>>();
    late StreamSubscription sub;

    Future<void> runFallback() async {
      try {
        final snap = await _summaries.where('householdId', isEqualTo: householdId).get();
        final list = snap.docs
            .map((d) => AvailabilitySummary.fromFirestore(d))
            .where((s) => s.dateKey.compareTo(fromKey) >= 0 && s.dateKey.compareTo(toKey) <= 0)
            .toList()
          ..sort((a,b)=> a.dateKey.compareTo(b.dateKey));
        controller.add(list);
      } catch (e) {
        controller.addError(e);
      }
    }

    sub = baseQuery.snapshots().listen((snapshot) {
      final list = snapshot.docs
          .map((doc) => AvailabilitySummary.fromFirestore(doc))
          .toList()
        ..sort((a,b)=> a.dateKey.compareTo(b.dateKey));
      controller.add(list);
    }, onError: (error, stack) {
      if (enableFallback) {
        runFallback();
      } else {
        controller.addError(error);
      }
    });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
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
