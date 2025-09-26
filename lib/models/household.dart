import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  Household({
    required this.id,
    required this.name,
    required this.adminUid,
    required this.colorPalette,
  });

  factory Household.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Household(
      id: doc.id,
      name: data['name'] as String? ?? 'Familie',
      adminUid: data['adminUid'] as String? ?? '',
      colorPalette: Map<String, String>.from(data['colorPalette'] as Map? ?? <String, String>{}),
    );
  }

  final String id;
  final String name;
  final String adminUid;
  final Map<String, String> colorPalette;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'adminUid': adminUid,
      'colorPalette': colorPalette,
    };
  }
}

