import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
	AppUser({
		required this.id,
		required this.email,
		required this.displayName,
		required this.timeZone,
		required this.householdIds,
	});

	factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
		final data = doc.data() ?? <String, dynamic>{};
		return AppUser(
			id: doc.id,
			email: data['email'] as String? ?? '',
			displayName: data['displayName'] as String? ?? '',
			timeZone: data['timeZone'] as String? ?? 'Europe/Berlin',
			householdIds: List<String>.from(data['householdIds'] as List? ?? <String>[]),
		);
	}

	final String id;
	final String email;
	final String displayName;
	final String timeZone;
	final List<String> householdIds;

	Map<String, dynamic> toJson() {
		return {
			'email': email,
			'displayName': displayName,
			'timeZone': timeZone,
			'householdIds': householdIds,
		};
	}
}
