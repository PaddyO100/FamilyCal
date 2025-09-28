import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:familycal/firebase_options.dart';
import 'package:familycal/utils/app_theme.dart';
import 'package:familycal/features/auth/presentation/auth_page.dart';
import 'package:familycal/features/household/presentation/household_gate.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        Firebase.app();
      } else {
        rethrow;
      }
    }
    logFirebaseContext();
    runApp(const FamilyCalApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught zone error: $error');
    debugPrint('Stack trace: $stackTrace');
    logFirebaseContext();
  });
}

void logFirebaseContext() {
  if (Firebase.apps.isEmpty) {
    debugPrint('Firebase not initialised; context unavailable.');
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  debugPrint('UID: ${user?.uid ?? 'no user'}');

  try {
    final projectId = FirebaseFirestore.instance.app.options.projectId;
    debugPrint('Firestore project: $projectId');
  } catch (error) {
    debugPrint('Unable to resolve Firestore project: $error');
  }
}

class FamilyCalApp extends StatelessWidget {
  const FamilyCalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyCal',
      debugShowCheckedModeBanner: false,
      theme: FamilyCalTheme.light,
      darkTheme: FamilyCalTheme.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de'),
        Locale('en'),
      ],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const AuthPage();
        }

        return HouseholdGate(user: snapshot.data!);
      },
    );
  }
}
