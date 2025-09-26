import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/event_editor_sheet.dart';
import 'package:familycal/features/calendar/widgets/event_card.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/utils/date_math.dart';

class DayView extends StatefulWidget {
  const DayView({super.key, required this.household});
  final Household household;
  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late final EventRepository _repository;
  late DateTime _selectedDate;
  @override
  void initState() {
    super.initState();
    _repository = EventRepository(FirebaseFirestore.instance);
    _selectedDate = DateTime.now();
  }
  void _changeDay(int delta) {
    setState(() { _selectedDate = _selectedDate.add(Duration(days: delta)); });
  }
  @override
  Widget build(BuildContext context) {
    final rangeStart = DateMath.startOfDay(_selectedDate);
    final rangeEnd = DateMath.endOfDay(_selectedDate);
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),child:Row(children:[
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=> _changeDay(-1)),
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, children:[
          Text(
            MaterialLocalizations.of(context).formatFullDate(_selectedDate),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${widget.household.name} · Tag',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ])),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=> _changeDay(1)),
      ])),
      Expanded(child: StreamBuilder<List<CalendarEvent>>(
        stream: _repository.watchEvents(householdId: widget.household.id, from: rangeStart, to: rangeEnd),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Termine konnten nicht geladen werden.\n${snapshot.error}', textAlign: TextAlign.center)));
          }
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final events = List<CalendarEvent>.from(snapshot.data ?? const <CalendarEvent>[])..sort((a,b)=>a.start.compareTo(b.start));
          if (events.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
              const Icon(Icons.event_available_outlined, size: 48), const SizedBox(height:12), Text('Keine Termine am ${DateMath.formatDay(_selectedDate)}')
            ]));
          }
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: events.length, itemBuilder: (context,index){
            final event = events[index];
            return Padding(padding: const EdgeInsets.only(bottom:12), child: EventCard(event: event, trailing: Text(event.category.toUpperCase()), onTap: ()=> EventEditorSheet.show(context, household: widget.household, initialEvent: event)));
          });
        },
      ))
    ]);
  }
}

