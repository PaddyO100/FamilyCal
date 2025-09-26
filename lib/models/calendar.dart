import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdCalendar {
  HouseholdCalendar({
    required this.id,
    required this.householdId,
    required this.name,
    required this.color,
  });

  factory HouseholdCalendar.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return HouseholdCalendar(
      id: doc.id,
      householdId: data['householdId'] as String? ?? '',
      name: data['name'] as String? ?? 'Allgemein',
      color: data['color'] as String? ?? '#5B67F1',
    );
  }

  final String id;
  final String householdId;
  final String name;
  final String color;

  Map<String, dynamic> toJson() {
    return {
      'householdId': householdId,
      'name': name,
      'color': color,
    };
  }
}

