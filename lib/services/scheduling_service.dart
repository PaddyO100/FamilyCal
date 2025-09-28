import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/utils/recurrence_utils.dart';

/// Simple free/busy computation based on calendar events.
/// Not all-day aware yet; assumes events inside working hours window.
class SchedulingService {
  SchedulingService(this._firestore)
      : _events = _firestore.collectionGroup('events');

  final FirebaseFirestore _firestore;
  final Query<Map<String, dynamic>> _events;

  /// Working hours (minutes from midnight) used for coverage computation
  final int workStartMinutes = 0; // 00:00
  final int workEndMinutes = 24 * 60; // 24:00 (Folgetag Mitternacht)

  /// Fetch all events overlapping the month range plus a small buffer to catch spanning events.
  Future<List<CalendarEvent>> _fetchEvents(String householdId, DateTime from, DateTime to) async {
    final startTs = Timestamp.fromDate(from.subtract(const Duration(days: 1)));
    final endTs = Timestamp.fromDate(to.add(const Duration(days: 1)));
    final snap = await _events
        .where('householdId', isEqualTo: householdId)
        .where('start', isGreaterThanOrEqualTo: startTs)
        .where('start', isLessThanOrEqualTo: endTs)
        .get();
    return snap.docs.map(CalendarEvent.fromFirestore).toList();
  }

  /// (intern) Monatliche Busy-Statistiken; liefert private Struktur.
  Future<Map<String, _DayBusyStats>> _computeMonthBusyStats(String householdId, DateTime monthStart) async {
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final events = await _fetchEvents(householdId, firstDay, lastDay);
    final membersSnap = await _firestore.collection('memberships').where('householdId', isEqualTo: householdId).get();
    final members = membersSnap.docs.map(Membership.fromFirestore).toList();
    final memberIds = members.map((m) => m.userId).toSet();
    final Map<String, _DayBusyStats> stats = {};
    for (final event in events) {
      // Expand recurrences per day range
      final occs = RecurrenceUtils.expandOccurrences(
        event: event,
        from: firstDay,
        to: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59),
      );
      for (final occ in occs) {
        final dateKey = _dateKey(occ.start);
        if (occ.start.isAfter(lastDay) || occ.end.isBefore(firstDay)) continue;
        final dayStats = stats.putIfAbsent(dateKey, () => _DayBusyStats(totalMembers: memberIds.length));
        final busyStart = _clipToWorkWindow(occ.start);
        final busyEnd = _clipToWorkWindow(occ.end);
        if (busyEnd.isBefore(busyStart)) continue;
        final busyMinutes = busyEnd.difference(busyStart).inMinutes;
        // Each participant counts as busy for that timespan.
        final participants = (event.participantIds.isEmpty ? memberIds : event.participantIds.toSet()..retainAll(memberIds));
        for (final pid in participants) {
          dayStats.addBusy(pid, busyMinutes);
        }
      }
    }

    return stats;
  }

  /// Compute free intervals (common) for given day for all household members.
  Future<List<FreeInterval>> computeCommonFreeIntervals(String householdId, DateTime day) async {
    final startDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endDay = DateTime(day.year, day.month, day.day, 23, 59, 59);
    final events = await _fetchEvents(householdId, startDay, endDay);
    final membersSnap = await _firestore.collection('memberships').where('householdId', isEqualTo: householdId).get();
    final members = membersSnap.docs.map(Membership.fromFirestore).toList();
    final memberIds = members.map((m)=> m.userId).toSet();
    final Map<String, List<_Interval>> busy = { for (final id in memberIds) id : <_Interval>[] };
    for (final event in events) {
      final occs = RecurrenceUtils.expandOccurrences(event: event, from: startDay, to: endDay);
      final participants = (event.participantIds.isEmpty ? memberIds : event.participantIds.toSet()..retainAll(memberIds));
      for (final occ in occs) {
        final bStart = _clipToWorkWindow(occ.start);
        final bEnd = _clipToWorkWindow(occ.end);
        if (bEnd.isBefore(bStart)) continue;
        final interval = _Interval(bStart, bEnd);
        for (final pid in participants) { busy[pid]!.add(interval); }
      }
    }
    for (final id in busy.keys) { busy[id] = _merge(busy[id]!); }
    final dayStart = DateTime(day.year, day.month, day.day).add(Duration(minutes: workStartMinutes));
    final dayEnd = DateTime(day.year, day.month, day.day).add(Duration(minutes: workEndMinutes));
    List<_Interval> commonFree = [ _Interval(dayStart, dayEnd) ];
    for (final id in busy.keys) { commonFree = _subtract(commonFree, busy[id]!); if (commonFree.isEmpty) break; }
    return commonFree.map((i)=> FreeInterval(i.start, i.end)).toList();
  }

  int get workStart => workStartMinutes;
  int get workEnd => workEndMinutes;

  Future<Map<String,double>> computeMonthBusyRatiosConfigured({
    required String householdId,
    required DateTime monthStart,
    required bool includePrivate,
    required bool emptyParticipantsForAll,
    required int workStart,
    required int workEnd,
  }) async {
    final stats = await _computeMonthBusyStats(householdId, monthStart);
    final firstDay = DateTime(monthStart.year, monthStart.month, 1);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0);
    final Map<String,double> ratios = {};
    stats.forEach((k,v){ ratios[k] = v.averageBusyRatio(workStart, workEnd).clamp(0,1); });
    // Ensure days w/o stats are treated as free (ratio 0)
    for (int d=1; d<= lastDay.day; d++){
      final key = _dateKey(DateTime(firstDay.year, firstDay.month, d));
      ratios.putIfAbsent(key, ()=> 0);
    }
    return ratios;
  }

  Future<List<FreeInterval>> computeCommonFreeIntervalsConfigured({
    required String householdId,
    required DateTime day,
    required bool includePrivate,
    required bool emptyParticipantsForAll,
    required int workStart,
    required int workEnd,
  }) async {
    final startDay = DateTime(day.year, day.month, day.day, 0,0,0);
    final endDay = DateTime(day.year, day.month, day.day, 23,59,59);
    final events = await _fetchEvents(householdId, startDay, endDay);
    final membersSnap = await _firestore.collection('memberships').where('householdId', isEqualTo: householdId).get();
    final memberIds = membersSnap.docs.map((d)=> d.data()['userId'] as String).toSet();
    final Map<String,List<_Interval>> busy = { for (final id in memberIds) id: <_Interval>[] };
    for (final event in events) {
      if (!includePrivate && event.visibility == 'Privat') continue;
      final participants = event.participantIds.isEmpty
          ? (emptyParticipantsForAll ? memberIds : {event.authorId})
          : (event.participantIds.toSet()..retainAll(memberIds));
      if (participants.isEmpty) continue;
      final occs = RecurrenceUtils.expandOccurrences(event: event, from: startDay, to: endDay);
      for (final occ in occs){
        final bStart = _clipToCustomWindow(occ.start, workStart, workEnd);
        final bEnd = _clipToCustomWindow(occ.end, workStart, workEnd);
        if (bEnd.isBefore(bStart)) continue;
        final interval = _Interval(bStart,bEnd);
        for (final pid in participants){ busy[pid]!.add(interval); }
      }
    }
    for (final id in busy.keys){ busy[id] = _merge(busy[id]!); }
    final dayStart = DateTime(day.year, day.month, day.day).add(Duration(minutes: workStart));
    final dayEnd = DateTime(day.year, day.month, day.day).add(Duration(minutes: workEnd));
    List<_Interval> commonFree = [ _Interval(dayStart, dayEnd) ];
    for (final id in busy.keys){ commonFree = _subtract(commonFree, busy[id]!); if (commonFree.isEmpty) break; }
    return commonFree.map((i)=> FreeInterval(i.start, i.end)).toList();
  }

  Future<List<FreeInterval>> computeCommonFreeIntervalsForMembersConfigured({
    required String householdId,
    required DateTime day,
    required bool includePrivate,
    required bool emptyParticipantsForAll,
    required int workStart,
    required int workEnd,
    required Set<String> focusMembers,
  }) async {
    final effectiveMembers = focusMembers; // falls leer -> später ersetzt
    final startDay = DateTime(day.year, day.month, day.day, 0,0,0);
    final endDay = DateTime(day.year, day.month, day.day, 23,59,59);
    final events = await _fetchEvents(householdId, startDay, endDay);
    final membersSnap = await _firestore.collection('memberships').where('householdId', isEqualTo: householdId).get();
    final allMemberIds = membersSnap.docs.map((d)=> d.data()['userId'] as String).toSet();
    final target = effectiveMembers.isEmpty ? allMemberIds : (effectiveMembers..retainAll(allMemberIds));
    final Map<String,List<_Interval>> busy = { for (final id in target) id: <_Interval>[] };
    for (final event in events) {
      if (!includePrivate && event.visibility == 'Privat') continue;
      var participants = event.participantIds.isEmpty
          ? (emptyParticipantsForAll ? allMemberIds : {event.authorId})
          : (event.participantIds.toSet()..retainAll(allMemberIds));
      participants = participants.where((p)=> target.contains(p)).toSet();
      if (participants.isEmpty) continue;
      final occs = RecurrenceUtils.expandOccurrences(event: event, from: startDay, to: endDay);
      for (final occ in occs){
        final bStart = _clipToCustomWindow(occ.start, workStart, workEnd);
        final bEnd = _clipToCustomWindow(occ.end, workStart, workEnd);
        if (bEnd.isBefore(bStart)) continue;
        final interval = _Interval(bStart,bEnd);
        for (final pid in participants){ busy[pid]!.add(interval); }
      }
    }
    for (final id in busy.keys){ busy[id] = _merge(busy[id]!); }
    final dayStart = DateTime(day.year, day.month, day.day).add(Duration(minutes: workStart));
    final dayEnd = DateTime(day.year, day.month, day.day).add(Duration(minutes: workEnd));
    List<_Interval> commonFree = [ _Interval(dayStart, dayEnd) ];
    for (final id in busy.keys){ commonFree = _subtract(commonFree, busy[id]!); if (commonFree.isEmpty) break; }
    return commonFree.map((i)=> FreeInterval(i.start, i.end)).toList();
  }

  DateTime _clipToCustomWindow(DateTime dt, int startM, int endM){
    final base = DateTime(dt.year, dt.month, dt.day);
    final ws = base.add(Duration(minutes: startM));
    final we = base.add(Duration(minutes: endM));
    if (dt.isBefore(ws)) return ws;
    if (dt.isAfter(we)) return we;
    return dt;
  }

  // Helpers
  DateTime _clipToWorkWindow(DateTime dt) {
    final base = DateTime(dt.year, dt.month, dt.day);
    final ws = base.add(Duration(minutes: workStartMinutes));
    final we = base.add(Duration(minutes: workEndMinutes));
    if (dt.isBefore(ws)) return ws;
    if (dt.isAfter(we)) return we;
    return dt;
  }
  String _dateKey(DateTime d){
    final y = d.year.toString().padLeft(4,'0');
    final m = d.month.toString().padLeft(2,'0');
    final da = d.day.toString().padLeft(2,'0');
    return '$y$m$da';
  }
}

class _DayBusyStats {
  _DayBusyStats({required this.totalMembers});
  final int totalMembers;
  final Map<String,int> _busyByMember = {};
  final Map<String,int> _totalByMember = {};
  void addBusy(String memberId, int minutes){
    _busyByMember.update(memberId, (v)=> v+minutes, ifAbsent: ()=> minutes);
    _totalByMember[memberId] = 1; // marker presence
  }
  double averageBusyRatio(int workStartMinutes, int workEndMinutes){
    final workSpan = workEndMinutes - workStartMinutes;
    if (workSpan <= 0) return 0;
    if (_busyByMember.isEmpty) return 0;
    double sum = 0;
    for (final minutes in _busyByMember.values){ sum += (minutes / workSpan).clamp(0,1); }
    return sum / _busyByMember.length;
  }
}

class _Interval {
  _Interval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class FreeInterval {
  FreeInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
  int get minutes => end.difference(start).inMinutes;
}

List<_Interval> _merge(List<_Interval> list){
  if (list.isEmpty) return list;
  list.sort((a,b)=> a.start.compareTo(b.start));
  final merged = <_Interval>[];
  var current = list.first;
  for (var i=1;i<list.length;i++){
    final next = list[i];
    if (next.start.isBefore(current.end) || next.start.isAtSameMomentAs(current.end)){
      if (next.end.isAfter(current.end)){
        current = _Interval(current.start, next.end);
      }
    } else {
      merged.add(current); current = next;
    }
  }
  merged.add(current);
  return merged;
}

List<_Interval> _subtract(List<_Interval> base, List<_Interval> busy){
  if (busy.isEmpty) return base;
  final result = <_Interval>[];
  for (final free in base){
    var segments = <_Interval>[free];
    for (final b in busy){
      final nextSegments = <_Interval>[];
      for (final s in segments){
        // no overlap
        if (b.end.isBefore(s.start) || b.start.isAfter(s.end)) { nextSegments.add(s); continue; }
        // overlap cases
        if (b.start.isAfter(s.start)){
          nextSegments.add(_Interval(s.start, b.start));
        }
        if (b.end.isBefore(s.end)){
          nextSegments.add(_Interval(b.end, s.end));
        }
      }
      segments = nextSegments.where((seg)=> seg.end.isAfter(seg.start)).toList();
      if (segments.isEmpty) break;
    }
    result.addAll(segments);
  }
  return result;
}
