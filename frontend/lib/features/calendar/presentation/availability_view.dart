import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDay(-1),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      MaterialLocalizations.of(context)
                          .formatFullDate(_selectedDate),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.household.name} · Verfügbarkeiten',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeDay(1),
              ),
            ],
          ),
        ),
  void initState() {
    super.initState();
    _repository = AvailabilityRepository(FirebaseFirestore.instance);
    _selectedDate = DateMath.startOfDay(DateTime.now());
  }

  void _changeDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  @override
  Widget build(BuildContext context) {
    final from = _selectedDate.subtract(const Duration(days: 3));
    final to = _selectedDate.add(const Duration(days: 7));
    final dateKey = DailyAvailability.dateKey(_selectedDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeDay(-1),
              ),
              Column(
                children: [
                  Text(
                    MaterialLocalizations.of(context).formatFullDate(_selectedDate),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${widget.household.name} · Verfügbarkeiten'),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _changeDay(1),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AvailabilitySummary>>(
            stream: _repository.watchHouseholdSummaries(
              householdId: widget.household.id,
              from: from,
              to: to,
            ),
            builder: (context, summarySnapshot) {
              if (summarySnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Verfügbarkeiten konnten nicht geladen werden.\n${summarySnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (summarySnapshot.connectionState == ConnectionState.waiting &&
                  !summarySnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final summaries = summarySnapshot.data ?? const <AvailabilitySummary>[];
              final summary = summaries.firstWhere(
                (item) => item.dateKey == dateKey,
                orElse: () => AvailabilitySummary(
                  id: '',
                  householdId: widget.household.id,
                  dateKey: dateKey,
                  availableMembers: 0,
                ),
              );
              return StreamBuilder<List<DailyAvailability>>(
                stream: _repository.watchUserAvailabilities(
                  userId: widget.user.uid,
                  from: from,
                  to: to,
                ),
                builder: (context, availabilitySnapshot) {
                  if (availabilitySnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Eigene Verfügbarkeiten konnten nicht geladen werden.\n${availabilitySnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (availabilitySnapshot.connectionState == ConnectionState.waiting &&
                      !availabilitySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final myAvailabilities = availabilitySnapshot.data ?? const <DailyAvailability>[];
                  final existing = myAvailabilities
                      .where((item) => DailyAvailability.dateKey(DateMath.startOfDay(item.date)) == dateKey)
                      .toList();
                  final hasExisting = existing.isNotEmpty;
                  final myDay = hasExisting
                      ? existing.first
                      : DailyAvailability(
                          id: DailyAvailability.docId(_selectedDate, widget.user.uid),
                          householdId: widget.household.id,
                          userId: widget.user.uid,
                          date: _selectedDate,
                          slots: const <AvailabilitySlot>[],
                        );

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.group_outlined),
                          title: const Text('Gemeinsames Zeitfenster'),
                          subtitle: Text(summary.availableMembers == 0
                              ? 'Noch keine Angaben'
                              : '${summary.availableMembers} Personen · ${summary.formatWindow()}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.lightbulb_outline),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    summary.availableMembers == 0
                                        ? 'Sobald alle ihre Zeiten eintragen, erscheinen Empfehlungen hier.'
                                        : 'Empfohlener Zeitraum: ${summary.formatWindow()}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: const Text('Meine Slots'),
                              subtitle: Text(
                                myDay.slots.isEmpty
                                    ? 'Noch nichts eingetragen'
                                    : myDay.slots.map((slot) => slot.formatLabel()).join(', '),
                              ),
                            ),
                            if (myDay.note != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text('Notiz: ${myDay.note}'),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: FilledButton.icon(
                                  onPressed: () {
                                    AvailabilityEditorSheet.show(
                                      context,
                                      repository: _repository,
                                      householdId: widget.household.id,
                                      userId: widget.user.uid,
                                      date: _selectedDate,
                                      availability: hasExisting ? myDay : null,
                                    );
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Bearbeiten'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (summaries.isNotEmpty)
                        Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ListTile(
                                leading: Icon(Icons.view_week_outlined),
                                title: Text('Wochenausblick'),
                              ),
                              for (final item in summaries.take(7))
                                ListTile(
                                  title: Text(_formatSummaryDate(context, item.dateKey)),
                                  subtitle: Text(item.availableMembers == 0
                                      ? 'Noch keine Angaben'
                                      : '${item.availableMembers} Personen · ${item.formatWindow()}'),
                                  trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = DateTime(
                                        int.parse(item.dateKey.substring(0, 4)),
                                        int.parse(item.dateKey.substring(4, 6)),
                                        int.parse(item.dateKey.substring(6, 8)),
                                      );
                                    });
                                  },
                                ),
                            ],
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

  String _formatSummaryDate(BuildContext context, String key) {
    final date = DateTime(
      int.parse(key.substring(0, 4)),
      int.parse(key.substring(4, 6)),
      int.parse(key.substring(6, 8)),
    );
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}
