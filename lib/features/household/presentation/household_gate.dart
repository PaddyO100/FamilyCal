import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/calendar_shell_page.dart';
import 'package:familycal/features/household/presentation/household_select_page.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/household_repository.dart';

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key, required this.user});
  final User user;
  @override State<HouseholdGate> createState()=> _HouseholdGateState();
}
class _HouseholdGateState extends State<HouseholdGate>{
  late final HouseholdRepository _repository;
  Future<void>? _prepareFuture;
  List<Household> _loaded = const <Household>[];

  @override void initState(){ super.initState(); _repository = HouseholdRepository(FirebaseFirestore.instance); }

  Future<void> _ensureMemberships(User user, List<Household> households) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final h in households) {
      final docRef = FirebaseFirestore.instance.collection('memberships').doc('${h.id}_${user.uid}');
      final snap = await docRef.get();
      if (!snap.exists) {
        final isAdmin = h.adminUid == user.uid;
        final fallbackColor = h.colorPalette.values.isNotEmpty ? h.colorPalette.values.first : '#5B67F1';
        batch.set(docRef, {
          'householdId': h.id,
            'userId': user.uid,
            'roleId': isAdmin ? 'admin' : 'member',
            'roleName': isAdmin ? 'Administrator' : 'Mitglied',
            'roleColor': fallbackColor,
            'isAdmin': isAdmin,
        });
      }
    }
    await batch.commit();
  }

  @override Widget build(BuildContext context){
    return StreamBuilder<List<Household>>(stream: _repository.watchHouseholds(widget.user.uid), builder:(c,snap){
      if (snap.connectionState==ConnectionState.waiting){ return const Scaffold(body: Center(child: CircularProgressIndicator())); }
      final households = snap.data ?? <Household>[]; if (households.isEmpty){ return HouseholdSelectPage(user: widget.user); }
      // Wenn sich die Haushaltsliste geändert hat, Vorbereitung anstoßen
      final idsNew = households.map((e)=> e.id).toSet();
      final idsOld = _loaded.map((e)=> e.id).toSet();
      final changed = idsNew.length != idsOld.length || !idsNew.containsAll(idsOld);
      if (changed){
        _loaded = households;
        _prepareFuture = _ensureMemberships(widget.user, households);
      }
      return FutureBuilder<void>(future: _prepareFuture, builder:(c,prepSnap){
        if (prepSnap.connectionState==ConnectionState.waiting){
          return const Scaffold(body: Center(child: Column(mainAxisSize: MainAxisSize.min, children:[CircularProgressIndicator(), SizedBox(height:12), Text('Mitgliedschaft wird vorbereitet ...')])));
        }
        return CalendarShellPage(user: widget.user, households: households);
      });
    });
  }
}
