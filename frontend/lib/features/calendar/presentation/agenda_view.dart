import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/widgets/event_card.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/utils/date_math.dart';

class AgendaView extends StatefulWidget {
  const AgendaView({super.key, required this.household});

  final Household household;

  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  late final EventRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = EventRepository(FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return StreamBuilder<List<CalendarEvent>>(
      stream: _repository.watchEvents(
        householdId: widget.household.id,
        from: now.subtract(const Duration(days: 1)),
        to: now.add(const Duration(days: 30)),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Agenda konnte nicht geladen werden.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data ?? <CalendarEvent>[];
        if (events.isEmpty) {
          return const Center(
            child: Text('Noch keine Termine geplant'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = events[index];
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
  }
}
