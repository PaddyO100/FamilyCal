import 'package:cloud_firestore/cloud_firestore.dart';
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

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _repository = EventRepository(FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CalendarDatePicker(
            initialDate: _focusedDay,
            firstDate: DateTime(_focusedDay.year - 2),
            lastDate: DateTime(_focusedDay.year + 2),
            onDateChanged: (date) {
              setState(() {
                _focusedDay = date;
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<CalendarEvent>>(
            stream: _repository.watchEvents(
              householdId: widget.household.id,
              from: DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day),
              to: DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day, 23, 59, 59),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final events = snapshot.data ?? <CalendarEvent>[];
              if (events.isEmpty) {
                return Center(
                  child: Text(
                    'Keine Termine am ${DateMath.formatDay(_focusedDay)}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final event = events[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        event.start.hour.toString().padLeft(2, '0'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(event.title),
                    subtitle: Text(DateMath.formatTimeRange(event.start, event.end)),
                    onTap: () => EventEditorSheet.show(
                      context,
                      household: widget.household,
                      initialEvent: event,
                    ),
                  );
                },
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemCount: events.length,
              );
            },
          ),
        ),
      ],
    );
  }
}
