import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:familycal/features/calendar/presentation/availability_editor_sheet.dart';
import 'package:familycal/models/availability.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/services/repositories/availability_repository.dart';
import 'package:familycal/services/repositories/membership_repository.dart';
import 'package:familycal/services/scheduling_service.dart';
import 'package:familycal/utils/date_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvailabilityView extends StatefulWidget {
  const AvailabilityView({super.key, required this.household, required this.user});
  final Household household;
  final User user;
  @override
  State<AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<AvailabilityView> {
  late AvailabilityRepository _repository;
  late MembershipRepository _membershipRepository;
  late DateTime _selectedDate;
  DateTime _monthAnchor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  _Mode _mode = _Mode.day;
  final SchedulingService _scheduling = SchedulingService(FirebaseFirestore.instance);
  bool _autoMode = false; // Automatischer Free/Busy Modus
  bool _includePrivate = true;
  bool _emptyParticipantsAll = true; // leere participantIds => alle
  int _minSlotMinutes = 30;
  bool _busyLoading = false;
  bool _freeLoading = false;
  final Map<String, Map<String,double>> _busyRatiosCache = {}; // MonatKey -> dateKey->ratio
  final Map<String, List<FreeInterval>> _freeDayCache = {}; // dateKey -> intervals
  final Set<String> _memberFilter = <String>{}; // leere Menge => alle
  bool _prefsLoaded = false;
  // Preference Keys
  static const _kPrefAuto = 'availability_autoMode';
  static const _kPrefIncludePrivate = 'availability_includePrivate';
  static const _kPrefEmptyAll = 'availability_emptyAll';
  static const _kPrefMinSlot = 'availability_minSlot';
  static const _kPrefMembers = 'availability_memberFilter';

  @override
  void initState() {
    super.initState();
    _repository = AvailabilityRepository(FirebaseFirestore.instance);
    _membershipRepository = MembershipRepository(FirebaseFirestore.instance);
    _selectedDate = DateMath.startOfDay(DateTime.now());
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _autoMode = p.getBool(_kPrefAuto) ?? _autoMode;
        _includePrivate = p.getBool(_kPrefIncludePrivate) ?? _includePrivate;
        _emptyParticipantsAll = p.getBool(_kPrefEmptyAll) ?? _emptyParticipantsAll;
        _minSlotMinutes = p.getInt(_kPrefMinSlot) ?? _minSlotMinutes;
        final memberCsv = p.getString(_kPrefMembers);
        if (memberCsv != null && memberCsv.isNotEmpty) {
          _memberFilter
            ..clear()
            ..addAll(memberCsv.split(','));
        }
        _prefsLoaded = true;
      });
      if (_autoMode) {
        _loadMonthBusy();
        _loadDayFree(_selectedDate);
      }
    } catch (_) {
      if (mounted) setState(()=> _prefsLoaded = true); // Weiter ohne Persistenz
    }
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kPrefAuto, _autoMode);
    await p.setBool(_kPrefIncludePrivate, _includePrivate);
    await p.setBool(_kPrefEmptyAll, _emptyParticipantsAll);
    await p.setInt(_kPrefMinSlot, _minSlotMinutes);
    await p.setString(_kPrefMembers, _memberFilter.join(','));
  }

  void _changeDay(int delta){ setState(()=> _selectedDate = _selectedDate.add(Duration(days: delta))); }
  void _invalidateCaches(){ setState((){ _busyRatiosCache.clear(); _freeDayCache.clear(); }); }
  String _monthKey(DateTime d)=> '${d.year.toString().padLeft(4,'0')}${d.month.toString().padLeft(2,'0')}';
  String _dayKey(DateTime d)=> DailyAvailability.dateKey(d);

  Future<void> _loadMonthBusy() async {
    final key = _monthKey(_monthAnchor);
    if (_busyRatiosCache.containsKey(key) || _busyLoading) return;
    setState(()=> _busyLoading = true);
    try {
      final ratios = await _scheduling.computeMonthBusyRatiosConfigured(
        householdId: widget.household.id,
        monthStart: _monthAnchor,
        includePrivate: _includePrivate,
        emptyParticipantsForAll: _emptyParticipantsAll,
        workStart: 0,
        workEnd: 24*60,
      );
      if (!mounted) return;
      setState(()=> _busyRatiosCache[key] = ratios);
    } catch (_) {
      // Ignoriere – UI zeigt dann grau
    } finally { if (mounted) setState(()=> _busyLoading = false); }
  }

  Future<void> _loadDayFree(DateTime day) async {
    final key = _dayKey(day);
    if (_freeDayCache.containsKey(key) || _freeLoading) return;
    setState(()=> _freeLoading = true);
    try {
      final intervals = await (_memberFilter.isEmpty
          ? _scheduling.computeCommonFreeIntervalsConfigured(
              householdId: widget.household.id,
              day: day,
              includePrivate: _includePrivate,
              emptyParticipantsForAll: _emptyParticipantsAll,
              workStart: 0,
              workEnd: 24*60,
            )
          : _scheduling.computeCommonFreeIntervalsForMembersConfigured(
              householdId: widget.household.id,
              day: day,
              includePrivate: _includePrivate,
              emptyParticipantsForAll: _emptyParticipantsAll,
              workStart: 0,
              workEnd: 24*60,
              focusMembers: _memberFilter,
            ));
      if (!mounted) return;
      setState(()=> _freeDayCache[key] = intervals);
    } catch (_) {
      // noop
    } finally { if (mounted) setState(()=> _freeLoading = false); }
  }

  void _openConfigDialog(){
    showDialog(context: context, builder: (c){
      bool includePrivate = _includePrivate;
      bool emptyAll = _emptyParticipantsAll;
      int minSlot = _minSlotMinutes;
      return AlertDialog(
        title: const Text('Automatik-Einstellungen'),
        content: StatefulBuilder(builder: (c,setStateDialog){
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Private Termine berücksichtigen'),
                value: includePrivate,
                onChanged: (v)=> setStateDialog(()=> includePrivate = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Leere Teilnehmerliste = alle'),
                value: emptyAll,
                onChanged: (v)=> setStateDialog(()=> emptyAll = v),
              ),
              const SizedBox(height:8),
              DropdownButtonFormField<int>(
                value: minSlot,
                decoration: const InputDecoration(labelText: 'Mindestdauer freier Slot (Minuten)'),
                items: const [15,30,45,60,90,120]
                    .map((v)=> DropdownMenuItem(value:v, child: Text('$v')))
                    .toList(),
                onChanged: (v)=> setStateDialog(()=> minSlot = v ?? 30),
              ),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: ()=> Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(onPressed: (){
            Navigator.pop(c);
            setState((){
              _includePrivate = includePrivate;
              _emptyParticipantsAll = emptyAll;
              _minSlotMinutes = minSlot;
              _invalidateCaches();
            });
          }, child: const Text('Übernehmen'))
        ],
      );
    });
  }

  Color _autoMonthColor(double? ratio, ThemeData theme){
    if (ratio == null) return theme.colorScheme.surfaceContainerHighest; // keine Daten
    if (ratio <= 0) return Colors.green;
    if (ratio >= 0.95) return Colors.red;
    return Colors.amber;
  }

  String _formatSummaryDate(BuildContext context, String key){
    final year = int.parse(key.substring(0,4));
    final month = int.parse(key.substring(4,6));
    final day = int.parse(key.substring(6,8));
    final date = DateTime(year, month, day);
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final from = _mode == _Mode.day
        ? _selectedDate.subtract(const Duration(days: 3))
        : DateTime(_monthAnchor.year, _monthAnchor.month, 1);
    final to = _mode == _Mode.day
        ? _selectedDate.add(const Duration(days: 7))
        : DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    final dateKey = DailyAvailability.dateKey(_selectedDate);
    return StreamBuilder<List<Membership>>(
      stream: _membershipRepository.watchHouseholdMembers(widget.household.id),
      builder: (context, memberSnap) {
        final totalMembers = (memberSnap.data ?? const <Membership>[]).length;
        return Column(children:[
          Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12), child: Row(children:[
            if (_mode == _Mode.day)
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=> _changeDay(-1))
            else
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: ()=> setState(()=> _monthAnchor = DateTime(_monthAnchor.year, _monthAnchor.month - 1, 1))),
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, children:[
              Text(
                _mode == _Mode.day
                  ? MaterialLocalizations.of(context).formatFullDate(_selectedDate)
                  : MaterialLocalizations.of(context).formatMonthYear(_monthAnchor),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text('${widget.household.name} · Verfügbarkeiten (${_mode == _Mode.day ? 'Tag' : 'Monat'})', textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            if (_mode == _Mode.day)
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=> _changeDay(1))
            else
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: ()=> setState(()=> _monthAnchor = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 1))),
          ])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal:16),
            child: Row(children:[
              Expanded(child: SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(value: _Mode.day, icon: Icon(Icons.view_day_outlined), label: Text('Tag')),
                  ButtonSegment(value: _Mode.month, icon: Icon(Icons.calendar_view_month_outlined), label: Text('Monat')),
                ],
                selected: <_Mode>{_mode},
                onSelectionChanged: (s)=> setState(()=> _mode = s.first),
              )),
              const SizedBox(width:12),
              if (!_prefsLoaded) const SizedBox(width:48, height:48, child: CircularProgressIndicator(strokeWidth:2)),
              if (_prefsLoaded) Column(crossAxisAlignment: CrossAxisAlignment.end, children:[
                Row(children:[
                  Switch(value: _autoMode, onChanged: (v){ setState(()=> _autoMode = v); _savePrefs(); if (v){ _invalidateCaches(); _loadMonthBusy(); _loadDayFree(_selectedDate); } }),
                  const Text('Auto')
                ]),
                Row(children:[
                  IconButton(onPressed: _openConfigDialog, icon: const Icon(Icons.tune), tooltip: 'Automatik konfigurieren'),
                  IconButton(onPressed: () async { final members = await _membershipRepository.watchHouseholdMembers(widget.household.id).first; if (!mounted) return; _openMemberFilter(members); }, icon: const Icon(Icons.group_outlined), tooltip: 'Mitglieder filtern'),
                ])
              ])
            ]),
          ),
          const SizedBox(height:8),
          Expanded(
            child: StreamBuilder<List<AvailabilitySummary>>(
              stream: _repository.watchHouseholdSummaries(householdId: widget.household.id, from: from, to: to),
              builder: (context, summarySnapshot){
                if (summarySnapshot.hasError) {
                  return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Verfügbarkeiten konnten nicht geladen werden.\n${summarySnapshot.error}', textAlign: TextAlign.center)));
                }
                if (summarySnapshot.connectionState == ConnectionState.waiting && !summarySnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final summaries = summarySnapshot.data ?? const <AvailabilitySummary>[];
                final summaryMap = { for (final s in summaries) s.dateKey : s };

                if (_mode == _Mode.month) {
                  if (_autoMode){ _loadMonthBusy(); final mk = _monthKey(_monthAnchor); final ratios = _busyRatiosCache[mk]; if (ratios == null || _busyLoading){ return const Center(child: CircularProgressIndicator()); } return _buildMonthGridAuto(context, ratios); }
                  return _buildMonthGrid(context, summaryMap, totalMembers);
                }

                final summary = summaryMap[dateKey] ?? AvailabilitySummary(id:'', householdId: widget.household.id, dateKey: dateKey, availableMembers: 0);
                return StreamBuilder<List<DailyAvailability>>(
                  stream: _repository.watchUserAvailabilities(userId: widget.user.uid, from: from, to: to),
                  builder: (context, availabilitySnapshot){
                    if (availabilitySnapshot.hasError) {
                      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Eigene Verfügbarkeiten konnten nicht geladen werden.\n${availabilitySnapshot.error}', textAlign: TextAlign.center)));
                    }
                    if (availabilitySnapshot.connectionState == ConnectionState.waiting && !availabilitySnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final myAvailabilities = availabilitySnapshot.data ?? const <DailyAvailability>[];
                    final existing = myAvailabilities.where((a)=> DailyAvailability.dateKey(DateMath.startOfDay(a.date)) == dateKey).toList();
                    final hasExisting = existing.isNotEmpty;
                    final myDay = hasExisting ? existing.first : DailyAvailability(id: DailyAvailability.docId(_selectedDate, widget.user.uid), householdId: widget.household.id, userId: widget.user.uid, date: _selectedDate, slots: const <AvailabilitySlot>[]);
                    return ListView(padding: const EdgeInsets.symmetric(horizontal:16, vertical:12), children:[
                      Card(child: ListTile(leading: const Icon(Icons.group_outlined), title: const Text('Gemeinsames Zeitfenster'), subtitle: Text(summary.availableMembers==0 ? 'Noch keine Angaben' : '${summary.availableMembers} Personen · ${summary.formatWindow()}'), trailing: IconButton(icon: const Icon(Icons.lightbulb_outline), onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(summary.availableMembers==0 ? 'Sobald alle ihre Zeiten eintragen, erscheinen Empfehlungen hier.' : 'Empfohlener Zeitraum: ${summary.formatWindow()}'))); })) ),
                      const SizedBox(height:16),
                      Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                        ListTile(title: const Text('Meine Slots'), subtitle: Text(myDay.slots.isEmpty ? 'Noch nichts eingetragen' : myDay.slots.map((s)=> s.formatLabel()).join(', ')) ),
                        if (myDay.note != null) Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: Text('Notiz: ${myDay.note}')),
                        Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: FilledButton.icon(onPressed: (){ AvailabilityEditorSheet.show(context, repository: _repository, householdId: widget.household.id, userId: widget.user.uid, date: _selectedDate, availability: hasExisting ? myDay : null); }, icon: const Icon(Icons.edit_outlined), label: const Text('Bearbeiten'))))
                      ])),
                      const SizedBox(height:16),
                      if (summaries.isNotEmpty) Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ const ListTile(leading: Icon(Icons.view_week_outlined), title: Text('Wochenausblick')), for (final item in summaries.take(7)) ListTile(title: Text(_formatSummaryDate(context, item.dateKey)), subtitle: Text(item.availableMembers==0 ? 'Noch keine Angaben' : '${item.availableMembers} Personen · ${item.formatWindow()}'), trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary), onTap: (){ setState(()=> _selectedDate = DateTime(int.parse(item.dateKey.substring(0,4)), int.parse(item.dateKey.substring(4,6)), int.parse(item.dateKey.substring(6,8)))); }, )]))
                    ]);
                  },
                );
              },
            ),
          ),
        ]);
      },
    );
  }

  void _openMemberFilter(List<Membership> members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final temp = Set<String>.from(_memberFilter);
        return StatefulBuilder(
          builder: (c,setStateSheet) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left:16, right:16, top:16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Mitglieder auswählen', style: TextStyle(fontSize:16, fontWeight: FontWeight.w600))),
                    IconButton(onPressed: ()=> Navigator.pop(c), icon: const Icon(Icons.close))
                  ],
                ),
                const SizedBox(height:8),
                Align(alignment: Alignment.centerLeft, child: Text(temp.isEmpty ? 'Alle Mitglieder aktuell einbezogen.' : '${temp.length} ausgewählt', style: Theme.of(context).textTheme.bodySmall)),
                const SizedBox(height:8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: members.map((m) {
                      final selected = temp.contains(m.userId);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v){ setStateSheet(()=> v==true ? temp.add(m.userId) : temp.remove(m.userId)); },
                        title: Text(m.label),
                        secondary: CircleAvatar(backgroundColor: Color(int.parse(m.roleColor.replaceFirst('#','0xff'))), child: Text(m.initial, style: const TextStyle(color: Colors.white))),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height:12),
                Row(children:[
                  TextButton(onPressed: (){ setStateSheet(()=> temp.clear()); }, child: const Text('Alle')), const SizedBox(width:8),
                  OutlinedButton(onPressed: (){ setStateSheet(()=> temp.clear()); Navigator.pop(c); setState((){ _memberFilter.clear(); _freeDayCache.clear(); }); _savePrefs(); if (_autoMode) _loadDayFree(_selectedDate); }, child: const Text('Übernehmen (Alle)')),
                  const Spacer(),
                  FilledButton(onPressed: (){ setState((){ _memberFilter..clear()..addAll(temp); _freeDayCache.clear(); }); Navigator.pop(c); _savePrefs(); if (_autoMode) _loadDayFree(_selectedDate); }, child: const Text('Übernehmen'))
                ])
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthGrid(BuildContext context, Map<String, AvailabilitySummary> map, int totalMembers) {
    final first = DateTime(_monthAnchor.year, _monthAnchor.month, 1);
    final last = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    final firstWeekday = first.weekday % 7; // Sonntag=0
    final dayCount = last.day;
    final cells = <Widget>[];
    final weekdayLabels = ['So','Mo','Di','Mi','Do','Fr','Sa'];
    cells.addAll(weekdayLabels.map((w)=> Center(child: Text(w, style: Theme.of(context).textTheme.labelSmall))));
    for (int i=0;i<firstWeekday;i++){ cells.add(const SizedBox()); }
    for (int d=1; d<=dayCount; d++){
      final date = DateTime(first.year, first.month, d);
      final key = DailyAvailability.dateKey(date);
      final summary = map[key];
      final color = _monthColor(summary, totalMembers, Theme.of(context));
      final selected = DateMath.isSameDay(date, _selectedDate);
      cells.add(GestureDetector(
        onTap: (){ setState((){ _selectedDate = date; _mode = _Mode.day; }); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds:180),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: selected ? 2 : 1),
          ),
          alignment: Alignment.topRight,
            padding: const EdgeInsets.all(4),
            child: Text('$d', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _foregroundFor(color, Theme.of(context)))) ,
        ),
      ));
    }
    return Column(children:[
      Expanded(child: GridView.count(
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: cells,
      )),
      Padding(padding: const EdgeInsets.fromLTRB(16,0,16,12), child: Wrap(spacing:12, runSpacing:4, children:[
        _legendSwatch(context, Colors.green, 'frei'),
        _legendSwatch(context, Colors.amber, 'teils belegt'),
        _legendSwatch(context, Colors.red, 'ganztägig belegt'),
        _legendSwatch(context, Theme.of(context).colorScheme.surfaceContainerHighest, 'keine Daten'),
      ]))
    ]);
  }

  Color _monthColor(AvailabilitySummary? s, int totalMembers, ThemeData theme){
    if (s == null) return theme.colorScheme.surfaceContainerHighest; // keine Daten
    if (totalMembers <= 0) return theme.colorScheme.surfaceContainerHighest;
    if (s.availableMembers <= 0) return Colors.red;
    if (s.availableMembers == totalMembers) return Colors.green;
    return Colors.amber;
  }
  Color _foregroundFor(Color bg, ThemeData theme){
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    return brightness == Brightness.dark ? Colors.white : Colors.black87;
  }
  Widget _legendSwatch(BuildContext context, Color c, String label){
    return Row(mainAxisSize: MainAxisSize.min, children:[ Container(width:14, height:14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4), border: Border.all(color: Theme.of(context).dividerColor))), const SizedBox(width:4), Text(label) ]);
  }

  Widget _buildMonthGridAuto(BuildContext context, Map<String,double> ratioMap){
    final first = DateTime(_monthAnchor.year, _monthAnchor.month, 1);
    final last = DateTime(_monthAnchor.year, _monthAnchor.month + 1, 0);
    final firstWeekday = first.weekday % 7;
    final dayCount = last.day;
    final cells = <Widget>[];
    final weekdayLabels = ['So','Mo','Di','Mi','Do','Fr','Sa'];
    cells.addAll(weekdayLabels.map((w)=> Center(child: Text(w, style: Theme.of(context).textTheme.labelSmall))));
    for (int i=0;i<firstWeekday;i++){ cells.add(const SizedBox()); }
    for (int d=1; d<= dayCount; d++){
      final date = DateTime(first.year, first.month, d);
      final key = DailyAvailability.dateKey(date);
      final ratio = ratioMap[key];
      final color = _autoMonthColor(ratio, Theme.of(context));
      final selected = DateMath.isSameDay(date, _selectedDate);
      cells.add(GestureDetector(
        onTap: (){ setState((){ _selectedDate = date; _mode = _Mode.day; }); if (_autoMode) _loadDayFree(date); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds:180),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor, width: selected ? 2 : 1),
          ),
          alignment: Alignment.topRight,
          padding: const EdgeInsets.all(4),
          child: Text('$d', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _foregroundFor(color, Theme.of(context)))) ,
        ),
      ));
    }
    return Column(children:[
      Expanded(child: GridView.count(
        padding: const EdgeInsets.symmetric(horizontal:16, vertical:12),
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: cells,
      )),
      Padding(padding: const EdgeInsets.fromLTRB(16,0,16,12), child: Wrap(spacing:12, runSpacing:4, children:[
        _legendSwatch(context, Colors.green, 'frei'),
        _legendSwatch(context, Colors.amber, 'teilweise'),
        _legendSwatch(context, Colors.red, 'voll belegt'),
        _legendSwatch(context, Theme.of(context).colorScheme.surfaceContainerHighest, 'keine Daten'),
      ]))
    ]);
  }
}

enum _Mode { day, month }
