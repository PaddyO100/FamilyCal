import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/widgets/event_card.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/utils/date_math.dart';

class WeekView extends StatefulWidget {
  const WeekView({super.key, required this.household});

  final Household household;

  @override
  State<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends State<WeekView> {
  late final EventRepository _repository;
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _repository = EventRepository(FirebaseFirestore.instance);
    _weekStart = DateMath.startOfWeek(DateTime.now());
  }

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: delta * 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = DateMath.endOfWeek(_weekStart);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeWeek(-1),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(_weekStart)} – ${MaterialLocalizations.of(context).formatMediumDate(weekEnd)}',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.household.name} · Woche',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeWeek(1),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CalendarEvent>>(
            stream: _repository.watchEvents(
              householdId: widget.household.id,
              from: _weekStart,
              to: weekEnd,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Wochentermine konnten nicht geladen werden.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = List<CalendarEvent>.from(
                snapshot.data ?? const <CalendarEvent>[],
              );
              final days = List.generate(7, (index) {
                final day = _weekStart.add(Duration(days: index));
                final dayEvents = events
                    .where((event) => DateMath.isSameDay(event.start, day))
                    .toList();
                dayEvents.sort((a, b) => a.start.compareTo(b.start));
                return MapEntry(day, dayEvents);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final entry = days[index];
                  final day = entry.key;
                  final dayEvents = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${MaterialLocalizations.of(context).formatMediumDate(day)} (${_weekdayLabel(day.weekday)})',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (dayEvents.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).colorScheme.surfaceVariant,
                          ),
                          child: const Text('Keine Termine'),
                        )
                      else
                        ...dayEvents.map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: EventCard(
                              event: event,
                              onTap: () => EventEditorSheet.show(
                                context,
                                household: widget.household,
                                initialEvent: event,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mo';
      case DateTime.tuesday:
        return 'Di';
      case DateTime.wednesday:
        return 'Mi';
      case DateTime.thursday:
        return 'Do';
      case DateTime.friday:
        return 'Fr';
      case DateTime.saturday:
        return 'Sa';
      case DateTime.sunday:
      default:
        return 'So';
    }
  }
}
