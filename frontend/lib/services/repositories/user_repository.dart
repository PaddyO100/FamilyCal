import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/app_user.dart';

class UserRepository {
  UserRepository(FirebaseFirestore firestore)
      : _users = firestore.collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  Future<AppUser> createOrUpdateUser(AppUser user) async {
    await _users.doc(user.id).set(user.toJson(), SetOptions(merge: true));
    final snapshot = await _users.doc(user.id).get();
    return AppUser.fromFirestore(snapshot);
  }

  Future<AppUser?> fetchUser(String id) async {
    final snapshot = await _users.doc(id).get();
    if (!snapshot.exists) {
      return null;
    }
    return AppUser.fromFirestore(snapshot);
  }
}
