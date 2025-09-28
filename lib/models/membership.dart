import 'package:cloud_firestore/cloud_firestore.dart';

class Membership {
  Membership({
    required this.id,
    required this.householdId,
    required this.userId,
    required this.roleId,
    required this.roleName,
    required this.roleColor,
    required this.isAdmin,
    this.displayName,
  });

  factory Membership.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Membership(
      id: doc.id,
      householdId: data['householdId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      roleId: data['roleId'] as String? ?? '',
      roleName: data['roleName'] as String? ?? '',
      roleColor: data['roleColor'] as String? ?? '#5B67F1',
      isAdmin: data['isAdmin'] as bool? ?? false,
      displayName: data['displayName'] as String?,
    );
  }

  final String id;
  final String householdId;
  final String userId;
  final String roleId;
  final String roleName;
  final String roleColor;
  final bool isAdmin;
  final String? displayName;

  Map<String, dynamic> toJson() {
    return {
      'householdId': householdId,
      'userId': userId,
      'roleId': roleId,
      'roleName': roleName,
      'roleColor': roleColor,
      'isAdmin': isAdmin,
      if (displayName != null) 'displayName': displayName,
    };
  }

  String get label => (displayName != null && displayName!.trim().isNotEmpty) ? displayName!.trim() : roleName;
  String get initial => label.isNotEmpty ? label.substring(0,1).toUpperCase() : '?';
  String get shortLabel => label.length > 24 ? '${label.substring(0,24)}…' : label;
}
