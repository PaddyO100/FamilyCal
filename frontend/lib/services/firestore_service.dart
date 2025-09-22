import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();

  static final instance = FirebaseFirestore.instance;

  static void configureForEmulator({
    required String host,
    required int port,
  }) {
    FirebaseFirestore.instance.settings = Settings(
      host: '$host:$port',
      sslEnabled: false,
      persistenceEnabled: true,
    );
  }
}
