import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:familycal/features/calendar/presentation/agenda_view.dart';
import 'package:familycal/features/calendar/presentation/birthday_tab.dart';
import 'package:familycal/features/calendar/presentation/day_view.dart';
import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/presentation/month_view.dart';
import 'package:familycal/features/calendar/presentation/week_view.dart';
import 'package:familycal/features/settings/presentation/settings_page.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';

class CalendarShellPage extends StatefulWidget {
  const CalendarShellPage({
    super.key,
    required this.user,
    required this.households,
  });

  final User user;
  final List<Household> households;

  @override
  State<CalendarShellPage> createState() => _CalendarShellPageState();
}

class _CalendarShellPageState extends State<CalendarShellPage> {
  late Household _selectedHousehold;
  int _currentIndex = 0;
  late Stream<Membership?> _membershipStream;

  @override
  void initState() {
    super.initState();
    _selectedHousehold = widget.households.first;
    _membershipStream = FirebaseFirestore.instance
        .collection('memberships')
        .doc('${_selectedHousehold.id}_${widget.user.uid}')
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? Membership.fromFirestore(snapshot)
              : null,
        );
  }

  void _switchHousehold(Household household) {
    setState(() {
      _selectedHousehold = household;
      _currentIndex = 0;
      _membershipStream = FirebaseFirestore.instance
          .collection('memberships')
          .doc('${household.id}_${widget.user.uid}')
          .snapshots()
          .map(
            (snapshot) => snapshot.exists
                ? Membership.fromFirestore(snapshot)
                : null,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Membership?>(
      stream: _membershipStream,
      builder: (context, snapshot) {
        final membership = snapshot.data;
        final pages = [
          MonthView(household: _selectedHousehold),
          WeekView(household: _selectedHousehold),
          DayView(household: _selectedHousehold),
          AgendaView(household: _selectedHousehold),
          BirthdayTab(household: _selectedHousehold),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(_selectedHousehold.name),
            actions: [
              IconButton(
                onPressed: membership == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SettingsPage(
                              household: _selectedHousehold,
                              user: widget.user,
                              membership: membership,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.settings_outlined),
              ),
              PopupMenuButton<Household>(
                onSelected: _switchHousehold,
                itemBuilder: (context) {
                  return widget.households
                      .map(
                        (household) => PopupMenuItem(
                          value: household,
                          child: Text(household.name),
                        ),
                      )
                      .toList();
                },
                child: Chip(
                  avatar: const Icon(Icons.home_outlined, size: 18),
                  label: Text(
                    _selectedHousehold.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                onPressed: FirebaseAuth.instance.signOut,
                icon: const Icon(Icons.logout),
                tooltip: 'Abmelden',
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Monat',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: 'Woche',
              ),
              NavigationDestination(
                icon: Icon(Icons.today_outlined),
                selectedIcon: Icon(Icons.today),
                label: 'Tag',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda),
                label: 'Agenda',
              ),
              NavigationDestination(
                icon: Icon(Icons.cake_outlined),
                selectedIcon: Icon(Icons.cake),
                label: 'Geburtstage',
              ),
            ],
          ),
          drawer: membership == null
              ? null
              : Drawer(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.user.email ?? '',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text('Rolle: ${membership.roleName}'),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Einstellungen'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SettingsPage(
                                household: _selectedHousehold,
                                user: widget.user,
                                membership: membership,
                              ),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.notifications_active_outlined),
                        title: const Text('Benachrichtigungen'),
                        subtitle: const Text('FCM-Berechtigungen verwalten'),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.groups_outlined),
                        title: const Text('Mitgliederverwaltung (coming soon)'),
                      ),
                    ],
                  ),
          ),
          floatingActionButton: membership == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => EventEditorSheet.show(
                    context,
                    household: _selectedHousehold,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Termin'),
                ),
        );
      },
    );
  }
}
