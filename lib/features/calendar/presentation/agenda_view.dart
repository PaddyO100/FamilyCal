import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/widgets/event_card.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/services/repositories/membership_repository.dart';

class AgendaView extends StatefulWidget {
  const AgendaView({super.key, required this.household});
  final Household household;
  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  late final EventRepository _repository;
  late final MembershipRepository _membershipRepository;
  @override
  void initState() {
    super.initState();
    _repository = EventRepository(FirebaseFirestore.instance);
    _membershipRepository = MembershipRepository(FirebaseFirestore.instance);
  }
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<List<Membership>>(
      stream: _membershipRepository.watchHouseholdMembers(widget.household.id),
      builder: (context, memberSnap){
        if (memberSnap.hasError) {
          return Center(child: Text('Mitgliederfehler: ${memberSnap.error}'));
        }
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = memberSnap.data!;
        final currentUser = FirebaseAuth.instance.currentUser;
        return StreamBuilder<List<CalendarEvent>>(
          stream: _repository.watchEvents(
            householdId: widget.household.id,
            from: now.subtract(const Duration(days: 1)),
            to: now.add(const Duration(days: 30)),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Agenda konnte nicht geladen werden.\n${snapshot.error}', textAlign: TextAlign.center)));
            }
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = snapshot.data ?? <CalendarEvent>[];
            if (events.isEmpty) {
              return const Center(child: Text('Noch keine Termine geplant'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final event = events[index];
                if (event.visibility == 'Privat' && event.authorId != (currentUser?.uid ?? '')) {
                  final author = members.firstWhere((m)=> m.userId == event.authorId, orElse: ()=> Membership(id:'', householdId:'', userId:'', roleId:'', roleName:'Mitglied', roleColor:'#808080', isAdmin:false));
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(children:[
                      CircleAvatar(backgroundColor: Colors.grey, child: Text(event.start.hour.toString().padLeft(2,'0'), style: const TextStyle(color: Colors.white))),
                      const SizedBox(width:12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        Text('Privater Termin von ${author.label}', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height:4),
                        Text('${MaterialLocalizations.of(context).formatMediumDate(event.start)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.start))} – ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(event.end))}', style: Theme.of(context).textTheme.bodySmall),
                      ]))
                    ])
                  );
                }
                return EventCard(
                  event: event,
                  onTap: () => EventEditorSheet.show(
                    context,
                    household: widget.household,
                    initialEvent: event,
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: events.length,
            );
          },
        );
      },
    );
  }
}
