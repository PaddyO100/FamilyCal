import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/calendar.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/models/role.dart';
import 'package:uuid/uuid.dart';

class HouseholdRepository {
  HouseholdRepository(FirebaseFirestore firestore)
      : _households = firestore.collection('households'),
        _memberships = firestore.collection('memberships'),
        _invites = firestore.collection('invites'),
        _calendars = firestore.collection('calendars');

  final CollectionReference<Map<String, dynamic>> _households;
  final CollectionReference<Map<String, dynamic>> _memberships;
  final CollectionReference<Map<String, dynamic>> _invites;
  final CollectionReference<Map<String, dynamic>> _calendars;

  Stream<List<Household>> watchHouseholds(String userId) {
    final query = _memberships.where('userId', isEqualTo: userId);
    return query.snapshots().asyncMap((snapshot) async {
      final futures = snapshot.docs.map((membershipDoc) async {
        final membership = Membership.fromFirestore(membershipDoc);
        final householdDoc = await _households.doc(membership.householdId).get();
        return Household.fromFirestore(householdDoc);
      });
      return Future.wait(futures);
    });
  }

  Future<Household> createHousehold({
    required String adminUid,
    required String name,
    required HouseholdRole adminRole,
  }) async {
    final householdRef = _households.doc();
    final household = Household(
      id: householdRef.id,
      name: name,
      adminUid: adminUid,
      colorPalette: {adminRole.id: adminRole.color},
    );
    await householdRef.set(household.toJson());

    final membershipId = '${household.id}_$adminUid';
    await _memberships.doc(membershipId).set({
      'householdId': household.id,
      'userId': adminUid,
      'roleId': adminRole.id,
      'roleName': adminRole.name,
      'roleColor': adminRole.color,
      'isAdmin': true,
    });

    final calendarRef = _calendars.doc();
    final calendar = HouseholdCalendar(
      id: calendarRef.id,
      householdId: household.id,
      name: 'Familienkalender',
      color: adminRole.color,
    );
    await calendarRef.set(calendar.toJson());
    return household;
  }

  Future<void> inviteMember({
    required String householdId,
    required String userId,
    required HouseholdRole role,
    bool isAdmin = false,
  }) async {
    final membershipId = '${householdId}_$userId';
    await _memberships.doc(membershipId).set({
      'householdId': householdId,
      'userId': userId,
      'roleId': role.id,
      'roleName': role.name,
      'roleColor': role.color,
      'isAdmin': isAdmin,
    });
  }

  Future<String> generateInviteToken({
    required String householdId,
    required HouseholdRole role,
    bool isAdmin = false,
    Duration validity = const Duration(days: 7),
  }) async {
    final token = const Uuid().v4();
    final now = DateTime.now();
    await _invites.doc(token).set({
      'householdId': householdId,
      'roleId': role.id,
      'roleName': role.name,
      'roleColor': role.color,
      'isAdmin': isAdmin,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(validity)),
    });
    return token;
  }

  Future<Household?> joinWithInvite({
    required String token,
    required String userId,
  }) async {
    final inviteDoc = await _invites.doc(token).get();
    if (!inviteDoc.exists) throw StateError('Einladung wurde nicht gefunden.');
    final data = inviteDoc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) {
      throw StateError('Einladung ist abgelaufen.');
    }
    final householdId = data['householdId'] as String;
    final householdDoc = await _households.doc(householdId).get();
    if (!householdDoc.exists) throw StateError('Haushalt existiert nicht mehr.');

    final membershipId = '${householdId}_$userId';
    await _memberships.doc(membershipId).set({
      'householdId': householdId,
      'userId': userId,
      'roleId': data['roleId'],
      'roleName': data['roleName'],
      'roleColor': data['roleColor'],
      'isAdmin': data['isAdmin'] as bool? ?? false,
    });
    await _invites.doc(token).delete();
    return Household.fromFirestore(householdDoc);
  }
}

