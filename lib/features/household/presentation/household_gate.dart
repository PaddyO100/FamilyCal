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
  @override void initState(){ super.initState(); _repository = HouseholdRepository(FirebaseFirestore.instance); }
  @override Widget build(BuildContext context){
    return StreamBuilder<List<Household>>(stream: _repository.watchHouseholds(widget.user.uid), builder:(c,snap){ if (snap.connectionState==ConnectionState.waiting){ return const Scaffold(body: Center(child: CircularProgressIndicator())); } final households = snap.data ?? <Household>[]; if (households.isEmpty){ return HouseholdSelectPage(user: widget.user); } return CalendarShellPage(user: widget.user, households: households); });
  }
}

