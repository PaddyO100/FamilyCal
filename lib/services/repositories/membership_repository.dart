import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/membership.dart';

class MembershipRepository {
  MembershipRepository(FirebaseFirestore firestore)
      : _memberships = firestore.collection('memberships');

  final CollectionReference<Map<String, dynamic>> _memberships;

  Stream<List<Membership>> watchHouseholdMembers(String householdId) {
    return _memberships
        .where('householdId', isEqualTo: householdId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Membership.fromFirestore).toList()
          ..sort((a, b) => a.roleName.compareTo(b.roleName)));
  }

  Future<void> updateMemberRole({
    required String membershipId,
    required String roleName,
    required String roleColor,
  }) async {
    await _memberships.doc(membershipId).set(
      {
        'roleName': roleName,
        'roleColor': roleColor,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> updateAdmin(String membershipId, bool isAdmin) async {
    await _memberships.doc(membershipId).set(
      {
        'isAdmin': isAdmin,
      },
      SetOptions(merge: true),
    );
  }
}

