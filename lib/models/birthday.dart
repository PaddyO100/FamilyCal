import 'package:cloud_firestore/cloud_firestore.dart';

class BirthdayEntry {
  BirthdayEntry({
    required this.userId,
    required this.householdId,
    required this.name,
    required this.birthDate,
  });

  factory BirthdayEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return BirthdayEntry(
      userId: doc.id,
      householdId: data['householdId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      birthDate: (data['birthDate'] as Timestamp?)?.toDate() ?? DateTime(2000, 1, 1),
    );
  }

  final String userId;
  final String householdId;
  final String name;
  final DateTime birthDate;

  int get age {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Map<String, dynamic> toJson() {
    return {
      'householdId': householdId,
      'name': name,
      'birthDate': Timestamp.fromDate(birthDate),
    };
  }
}

