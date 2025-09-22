import 'package:cloud_firestore/cloud_firestore.dart';

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.startMinutes,
    required this.endMinutes,
    this.note,
  });

  final int startMinutes;
  final int endMinutes;
  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      if (note != null) 'note': note,
    };
  }

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      startMinutes: (json['startMinutes'] as num).toInt(),
      endMinutes: (json['endMinutes'] as num).toInt(),
      note: json['note'] as String?,
    );
  }

  String formatLabel() {
    return '${_formatMinutes(startMinutes)} – ${_formatMinutes(endMinutes)}';
  }

  static String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}

class DailyAvailability {
  DailyAvailability({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.date,
    required this.slots,
    this.note,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String userId;
  final DateTime date;
  final List<AvailabilitySlot> slots;
  final String? note;
  final DateTime? updatedAt;

  factory DailyAvailability.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return DailyAvailability.fromJson(data, id: snapshot.id);
  }

  factory DailyAvailability.fromJson(Map<String, dynamic> json, {required String id}) {
    final timestamp = json['date'] as Timestamp;
    final slots = (json['slots'] as List<dynamic>? ?? [])
        .map((slot) => AvailabilitySlot.fromJson(
              Map<String, dynamic>.from(slot as Map<Object?, Object?>),
            ))
        .toList();
    return DailyAvailability(
      id: id,
      householdId: json['householdId'] as String,
      userId: json['userId'] as String,
      date: timestamp.toDate(),
      slots: slots,
      note: json['note'] as String?,
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'householdId': householdId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'dateKey': dateKey(date),
      'slots': slots.map((slot) => slot.toJson()).toList(),
      if (note != null) 'note': note,
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  DailyAvailability copyWith({
    List<AvailabilitySlot>? slots,
    String? note,
    DateTime? updatedAt,
  }) {
    return DailyAvailability(
      id: id,
      householdId: householdId,
      userId: userId,
      date: date,
      slots: slots ?? this.slots,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String docId(DateTime date, String userId) {
    return '${userId}_${dateKey(date)}';
  }

  static String dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${y}${m}${d}';
  }
}

class AvailabilitySummary {
  AvailabilitySummary({
    required this.id,
    required this.householdId,
    required this.dateKey,
    required this.availableMembers,
    this.earliestStartMinutes,
    this.latestEndMinutes,
    this.updatedAt,
  });

  final String id;
  final String householdId;
  final String dateKey;
  final int availableMembers;
  final int? earliestStartMinutes;
  final int? latestEndMinutes;
  final DateTime? updatedAt;

  factory AvailabilitySummary.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data()!;
    return AvailabilitySummary(
      id: snapshot.id,
      householdId: data['householdId'] as String,
      dateKey: data['dateKey'] as String,
      availableMembers: (data['availableMembers'] as num).toInt(),
      earliestStartMinutes: (data['earliestStartMinutes'] as num?)?.toInt(),
      latestEndMinutes: (data['latestEndMinutes'] as num?)?.toInt(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String formatWindow() {
    if (earliestStartMinutes == null || latestEndMinutes == null) {
      return 'Noch keine gemeinsame Zeit';
    }
    final start = AvailabilitySlot._formatMinutes(earliestStartMinutes!);
    final end = AvailabilitySlot._formatMinutes(latestEndMinutes!);
    return '$start – $end';
  }
}
