import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/services/repositories/membership_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/utils/date_math.dart';

class MonthView extends StatefulWidget {
  const MonthView({super.key, required this.household});
  final Household household;
  @override
  State<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends State<MonthView> {
  late DateTime _focusedDay;
  late final EventRepository _repository;
  late final MembershipRepository _membershipRepository;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _repository = EventRepository(FirebaseFirestore.instance);
    _membershipRepository = MembershipRepository(FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;
        final targetHeight = (availableHeight * (isLandscape ? 0.8 : 0.45)).clamp(isLandscape ? 200.0 : 260.0, 400.0);
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          return const Center(child: Text('Bitte melde dich an.'));
        }
        return Column(children: [
          SizedBox(
            height: targetHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CalendarDatePicker(
                initialDate: _focusedDay,
                firstDate: DateTime(_focusedDay.year - 2),
                lastDate: DateTime(_focusedDay.year + 2),
                onDateChanged: (d) {
                  setState(() => _focusedDay = d);
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Membership>>(
              stream: _membershipRepository.watchHouseholdMembers(widget.household.id),
              builder: (context, memberSnapshot) {
                if (memberSnapshot.hasError) {
                  return Center(child: Text('Mitglieder konnten nicht geladen werden: ${memberSnapshot.error}'));
                }
                if (!memberSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = memberSnapshot.data!;

                return StreamBuilder<List<CalendarEvent>>(
                  stream: _repository.watchEvents(
                    householdId: widget.household.id,
                    from: DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day),
                    to: DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day, 23, 59, 59),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Termine konnten nicht geladen werden.\n${snapshot.error}', textAlign: TextAlign.center),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final events = snapshot.data ?? <CalendarEvent>[];
                    if (events.isEmpty) {
                      return Center(child: Text('Keine Termine am ${DateMath.formatDay(_focusedDay)}'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (c, i) {
                        final e = events[i];
                        if (e.visibility == 'Privat' && e.authorId != currentUser.uid) {
                          final author = members.firstWhere((m) => m.userId == e.authorId, orElse: () => Membership(id: '', householdId: '', userId: '', roleId: '', roleName: 'Mitglied', roleColor: '#808080', isAdmin: false));
                          return ListTile(
                            leading: CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Text(e.start.hour.toString().padLeft(2, '0'),
                                    style: const TextStyle(color: Colors.white))),
                            title: Text('Privater Termin von ${author.label}'),
                            subtitle: Text(DateMath.formatTimeRange(e.start, e.end)),
                            onTap: null, // Disable tap for private events of others
                          );
                        }
                        return ListTile(
                          leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(e.start.hour.toString().padLeft(2, '0'),
                                  style: const TextStyle(color: Colors.white))),
                          title: Text(e.title),
                          subtitle: Text(DateMath.formatTimeRange(e.start, e.end)),
                          onTap: () => EventEditorSheet.show(context, household: widget.household, initialEvent: e),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: events.length,
                    );
                  },
                );
              },
            ),
          )
        ]);
      },
    );
  }
}
