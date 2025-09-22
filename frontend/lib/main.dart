import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:familycal/services/firebase/firebase_options.dart';
import 'package:familycal/utils/app_theme.dart';
import 'package:familycal/features/auth/presentation/auth_page.dart';
import 'package:familycal/features/household/presentation/household_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await runZonedGuarded(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    runApp(const FamilyCalApp());
  }, (error, stackTrace) {
    debugPrint('Uncaught error: $error\n$stackTrace');
  });
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
