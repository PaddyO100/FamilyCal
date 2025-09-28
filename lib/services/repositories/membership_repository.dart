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
          ..sort((a, b) => (a.displayName ?? a.roleName).toLowerCase().compareTo((b.displayName ?? b.roleName).toLowerCase())));
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

  Future<void> updateDisplayName({
    required String membershipId,
    required String displayName,
  }) async {
    await _memberships.doc(membershipId).set(
      {
        'displayName': displayName,
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

  Future<void> deleteMembership(String membershipId) async {
    await _memberships.doc(membershipId).delete();
  }

  Future<int> fillMissingDisplayNames(String householdId) async {
    final query = await _memberships.where('householdId', isEqualTo: householdId).get();
    final batch = _memberships.firestore.batch();
    int count = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      final hasDisplay = (data['displayName'] as String?)?.trim().isNotEmpty ?? false;
      if (!hasDisplay) {
        final roleName = (data['roleName'] as String?) ?? '';
        if (roleName.isNotEmpty) {
          batch.set(doc.reference, {'displayName': roleName}, SetOptions(merge: true));
          count++;
        }
      }
    }
    if (count > 0) await batch.commit();
    return count;
  }
}
