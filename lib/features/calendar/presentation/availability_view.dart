import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/availability_editor_sheet.dart';
import 'package:familycal/models/availability.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/services/repositories/availability_repository.dart';
import 'package:familycal/utils/date_math.dart';

class AvailabilityView extends StatefulWidget {
  const AvailabilityView({super.key, required this.household, required this.user});
  final Household household;
  final User user;
  @override
  State<AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<AvailabilityView> {
  late AvailabilityRepository _repository;
  late DateTime _selectedDate;
  @override
  void initState() { super.initState(); _repository = AvailabilityRepository(FirebaseFirestore.instance); _selectedDate = DateMath.startOfDay(DateTime.now()); }
  void _changeDay(int delta){ setState(()=> _selectedDate = _selectedDate.add(Duration(days: delta))); }
  @override
  Widget build(BuildContext context) {
    final from = _selectedDate.subtract(const Duration(days: 3));
    final to = _selectedDate.add(const Duration(days: 7));
    final dateKey = DailyAvailability.dateKey(_selectedDate);
    return Column(children:[
      Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=> _changeDay(-1)),
        Column(children:[
          Text(MaterialLocalizations.of(context).formatFullDate(_selectedDate), style: Theme.of(context).textTheme.titleMedium),
          Text('${widget.household.name} · Verfügbarkeiten')
        ]),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=> _changeDay(1)),
      ])),
      Expanded(child: StreamBuilder<List<AvailabilitySummary>>(
        stream: _repository.watchHouseholdSummaries(householdId: widget.household.id, from: from, to: to),
        builder: (context, summarySnapshot){
          final summaries = summarySnapshot.data ?? const <AvailabilitySummary>[];
          final summary = summaries.firstWhere((s)=> s.dateKey == dateKey, orElse: ()=> AvailabilitySummary(id:'', householdId: widget.household.id, dateKey: dateKey, availableMembers: 0));
          return StreamBuilder<List<DailyAvailability>>(
            stream: _repository.watchUserAvailabilities(userId: widget.user.uid, from: from, to: to),
            builder: (context, availabilitySnapshot){
              if (!availabilitySnapshot.hasData && !summarySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final myAvailabilities = availabilitySnapshot.data ?? const <DailyAvailability>[];
              final existing = myAvailabilities.where((a)=> DailyAvailability.dateKey(DateMath.startOfDay(a.date)) == dateKey).toList();
              final hasExisting = existing.isNotEmpty;
              final myDay = hasExisting ? existing.first : DailyAvailability(id: DailyAvailability.docId(_selectedDate, widget.user.uid), householdId: widget.household.id, userId: widget.user.uid, date: _selectedDate, slots: const <AvailabilitySlot>[]);
              return ListView(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12), children:[
                Card(child: ListTile(leading: const Icon(Icons.group_outlined), title: const Text('Gemeinsames Zeitfenster'), subtitle: Text(summary.availableMembers==0 ? 'Noch keine Angaben' : '${summary.availableMembers} Personen · ${summary.formatWindow()}'), trailing: IconButton(icon: const Icon(Icons.lightbulb_outline), onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary.availableMembers==0 ? 'Sobald alle ihre Zeiten eintragen, erscheinen Empfehlungen hier.' : 'Empfohlener Zeitraum: ${summary.formatWindow()}'))); }))),
                const SizedBox(height:16),
                Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  ListTile(title: const Text('Meine Slots'), subtitle: Text(myDay.slots.isEmpty ? 'Noch nichts eingetragen' : myDay.slots.map((s)=> s.formatLabel()).join(', '))),
                  if (myDay.note != null) Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: Text('Notiz: ${myDay.note}')),
                  Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: FilledButton.icon(onPressed: (){ AvailabilityEditorSheet.show(context, repository: _repository, householdId: widget.household.id, userId: widget.user.uid, date: _selectedDate, availability: hasExisting ? myDay : null); }, icon: const Icon(Icons.edit_outlined), label: const Text('Bearbeiten'))))
                ])),
                const SizedBox(height:16),
                if (summaries.isNotEmpty) Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ const ListTile(leading: Icon(Icons.view_week_outlined), title: Text('Wochenausblick')), for (final item in summaries.take(7)) ListTile(title: Text(_formatSummaryDate(context, item.dateKey)), subtitle: Text(item.availableMembers==0 ? 'Noch keine Angaben' : '${item.availableMembers} Personen · ${item.formatWindow()}'), trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary), onTap: (){ setState(()=> _selectedDate = DateTime(int.parse(item.dateKey.substring(0,4)), int.parse(item.dateKey.substring(4,6)), int.parse(item.dateKey.substring(6,8)))); }, )]))
              ]);
            },
          );
        },
      ))
    ]);
  }
  String _formatSummaryDate(BuildContext context, String key){ final date = DateTime(int.parse(key.substring(0,4)), int.parse(key.substring(4,6)), int.parse(key.substring(6,8))); return MaterialLocalizations.of(context).formatMediumDate(date); }
}

