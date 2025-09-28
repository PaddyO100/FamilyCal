import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/agenda_view.dart';
import 'package:familycal/features/calendar/presentation/availability_view.dart';
import 'package:familycal/features/calendar/presentation/birthday_tab.dart';
import 'package:familycal/features/calendar/presentation/day_view.dart';
import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/presentation/month_view.dart';
import 'package:familycal/features/calendar/presentation/week_view.dart';
import 'package:familycal/features/settings/presentation/settings_page.dart';
import 'package:familycal/features/tasks/presentation/task_board_page.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:flutter/scheduler.dart';

class CalendarShellPage extends StatefulWidget {
  const CalendarShellPage({super.key, required this.user, required this.households});
  final User user; final List<Household> households;
  @override State<CalendarShellPage> createState()=> _CalendarShellPageState();
}
class _CalendarShellPageState extends State<CalendarShellPage>{
  late Household _selectedHousehold; int _currentIndex = 0; late Stream<Membership?> _membershipStream;
  final Set<String> _ensuredHouseholds = <String>{};

  @override void initState(){
    super.initState();
    _selectedHousehold = widget.households.first;
    _membershipStream = _membershipForHousehold(_selectedHousehold);
  }

  Stream<Membership?> _membershipForHousehold(Household household){
    _ensureMembershipIfNeeded(household);
    return FirebaseFirestore.instance
        .collection('memberships')
        .doc('${household.id}_${widget.user.uid}')
        .snapshots()
        .map((s)=> s.exists ? Membership.fromFirestore(s) : null);
  }

  void _ensureMembershipIfNeeded(Household household){
    if (_ensuredHouseholds.contains(household.id)) return;
    _ensuredHouseholds.add(household.id);
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final docRef = FirebaseFirestore.instance
          .collection('memberships')
          .doc('${household.id}_${widget.user.uid}');
      try {
        final snapshot = await docRef.get();
        if (snapshot.exists) return;
        final isAdmin = household.adminUid == widget.user.uid;
        final fallbackColor = household.colorPalette.values.isNotEmpty
            ? household.colorPalette.values.first
            : '#5B67F1';
        await docRef.set({
          'householdId': household.id,
          'userId': widget.user.uid,
          'roleId': isAdmin ? 'admin' : 'member',
          'roleName': isAdmin ? 'Administrator' : 'Mitglied',
          'displayName': isAdmin ? 'Administrator' : 'Mitglied',
          'roleColor': fallbackColor,
          'isAdmin': isAdmin,
        });
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Mitgliedschaft konnte nicht erstellt werden: $error')),
          );
        }
      }
    });
  }

  void _switchHousehold(Household h){
    setState((){
      _selectedHousehold = h;
      _currentIndex = 0;
      _membershipStream = _membershipForHousehold(h);
    });
  }

  @override Widget build(BuildContext context){ return StreamBuilder<Membership?>(stream: _membershipStream, builder:(c,snap){
    if (snap.hasError) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Kalender kann nicht geladen werden: ${snap.error}', textAlign: TextAlign.center)));
    }
    final membership = snap.data;
    final navigationBar = NavigationBar(selectedIndex: _currentIndex, onDestinationSelected: (i)=> setState(()=> _currentIndex = i), destinations: const [
      NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Monat'),
      NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'Woche'),
      NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Tag'),
      NavigationDestination(icon: Icon(Icons.view_agenda_outlined), selectedIcon: Icon(Icons.view_agenda), label: 'Agenda'),
      NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Verfüg'),
      NavigationDestination(icon: Icon(Icons.cake_outlined), selectedIcon: Icon(Icons.cake), label: 'Geburtstage'),
    ]);

    if (membership == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_selectedHousehold.name), actions:[
          IconButton(onPressed: null, icon: const Icon(Icons.settings_outlined)),
          PopupMenuButton<Household>(onSelected: _switchHousehold, itemBuilder: (context)=> widget.households.map((h)=> PopupMenuItem(value: h, child: Text(h.name))).toList(), child: Chip(avatar: const Icon(Icons.home_outlined, size:18), label: Text(_selectedHousehold.name, style: const TextStyle(fontWeight: FontWeight.w600)))),
          IconButton(onPressed: FirebaseAuth.instance.signOut, icon: const Icon(Icons.logout), tooltip: 'Abmelden')
        ]),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Mitgliedschaft wird vorbereitet …'),
            ],
          ),
        ),
        bottomNavigationBar: navigationBar,
      );
    }

    final pages = [ MonthView(household: _selectedHousehold), WeekView(household: _selectedHousehold), DayView(household: _selectedHousehold), AgendaView(household: _selectedHousehold), AvailabilityView(household: _selectedHousehold, user: widget.user), BirthdayTab(household: _selectedHousehold) ];
    return Scaffold(
    appBar: AppBar(title: Text(_selectedHousehold.name), actions:[ IconButton(onPressed: (){ Navigator.of(context).push(MaterialPageRoute(builder: (c)=> SettingsPage(household: _selectedHousehold, user: widget.user, membership: membership))); }, icon: const Icon(Icons.settings_outlined)), PopupMenuButton<Household>(onSelected: _switchHousehold, itemBuilder: (c)=> widget.households.map((h)=> PopupMenuItem(value:h, child: Text(h.name))).toList(), child: Chip(avatar: const Icon(Icons.home_outlined, size:18), label: Text(_selectedHousehold.name, style: const TextStyle(fontWeight: FontWeight.w600)))), IconButton(onPressed: FirebaseAuth.instance.signOut, icon: const Icon(Icons.logout), tooltip: 'Abmelden') ]),
    body: IndexedStack(index: _currentIndex, children: pages),
    bottomNavigationBar: navigationBar,
    floatingActionButton: FloatingActionButton.extended(onPressed: ()=> EventEditorSheet.show(context, household: _selectedHousehold), icon: const Icon(Icons.add), label: const Text('Termin')),
    drawer: Drawer(child: ListView(padding: EdgeInsets.zero, children:[ DrawerHeader(decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children:[ Text(widget.user.email ?? '', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height:8), Text('Profil: ${membership.shortLabel}${membership.label != membership.roleName ? ' (${membership.roleName})' : ''}${membership.isAdmin ? ' · Admin' : ''}') ])), ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Einstellungen'), onTap: (){ Navigator.of(context).pop(); Navigator.of(context).push(MaterialPageRoute(builder:(c)=> SettingsPage(household: _selectedHousehold, user: widget.user, membership: membership))); }), ListTile(leading: const Icon(Icons.task_alt_outlined), title: const Text('Aufgaben'), onTap: (){ Navigator.of(context).pop(); Navigator.of(context).push(MaterialPageRoute(builder:(c)=> TaskBoardPage(householdId: _selectedHousehold.id, householdName: _selectedHousehold.name, user: widget.user))); }), ListTile(leading: const Icon(Icons.notifications_active_outlined), title: const Text('Benachrichtigungen')), ])),
  ); }); }
}
