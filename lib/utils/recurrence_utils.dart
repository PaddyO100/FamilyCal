import 'package:collection/collection.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/utils/date_math.dart';

class RecurrenceUtils {
  static Map<String, String> parseRule(String rule) {
    final entries = rule.split(';');
    final map = <String, String>{};
    for (final entry in entries) {
      final pair = entry.split('=');
      if (pair.length == 2) {
        map[pair[0].toUpperCase()] = pair[1];
      }
    }
    return map;
  }

  static DateTime? _parseUntil(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      if (value.contains('T')) return DateTime.parse(value);
      final year = int.parse(value.substring(0, 4));
      final month = int.parse(value.substring(4, 6));
      final day = int.parse(value.substring(6, 8));
      return DateTime(year, month, day, 23, 59, 59);
    } catch (_) {
      return null;
    }
  }

  static List<int> _weekdayIndexes(List<String> byDay) {
    const mapping = {
      'MO': DateTime.monday,
      'TU': DateTime.tuesday,
      'WE': DateTime.wednesday,
      'TH': DateTime.thursday,
      'FR': DateTime.friday,
      'SA': DateTime.saturday,
      'SU': DateTime.sunday,
    };
    return byDay.map((code) => mapping[code] ?? DateTime.monday).toList();
  }

  static List<CalendarEvent> expandOccurrences({
    required CalendarEvent event,
    required DateTime from,
    required DateTime to,
  }) {
    if (event.recurrenceRule == null || event.recurrenceRule!.isEmpty) {
      return [event];
    }

    final parsed = parseRule(event.recurrenceRule!);
    final frequency = parsed['FREQ'] ?? 'DAILY';
    final interval = int.tryParse(parsed['INTERVAL'] ?? '1') ?? 1;
    final count = int.tryParse(parsed['COUNT'] ?? '') ?? -1;
    final until = _parseUntil(parsed['UNTIL']);
    final byDay = parsed['BYDAY']?.split(',') ?? <String>[];
    final byDayIndexes = _weekdayIndexes(byDay);
    final duration = event.end.difference(event.start);

    int generated = 0;
    final occurrences = <CalendarEvent>[];

    bool isException(DateTime value) {
      return event.exceptionDates.any(
        (exception) => DateMath.isSameMoment(
          DateTime(exception.year, exception.month, exception.day, exception.hour, exception.minute),
          DateTime(value.year, value.month, value.day, value.hour, value.minute),
        ),
      );
    }

    void addOccurrence(DateTime start) {
      if (start.isAfter(to)) return;
      if (start.isBefore(from)) return;
      final occurrence = event.copyWith(
        id: '${event.id}_${start.millisecondsSinceEpoch}',
        start: start,
        end: start.add(duration),
      );
      occurrences.add(occurrence);
    }

    DateTime advance(DateTime current) {
      switch (frequency) {
        case 'DAILY':
          return current.add(Duration(days: interval));
        case 'WEEKLY':
          return current.add(Duration(days: interval * 7));
        case 'MONTHLY':
          return DateTime(current.year, current.month + interval, current.day, current.hour, current.minute);
        case 'YEARLY':
          return DateTime(current.year + interval, current.month, current.day, current.hour, current.minute);
        default:
          return current.add(Duration(days: interval));
      }
    }

    DateTime iterateStart = event.start;
    DateTime iterateEndLimit = until ?? to;

    if (frequency == 'WEEKLY' && byDayIndexes.isNotEmpty) {
      final weekStart = DateMath.startOfWeek(event.start);
      var baseWeekStart = weekStart;
      while (baseWeekStart.isBefore(iterateEndLimit.add(duration))) {
  for (final weekday in byDayIndexes.sorted((a, b) => a.compareTo(b))) {
          final candidate = baseWeekStart.add(
            Duration(days: weekday - DateTime.monday, hours: event.start.hour, minutes: event.start.minute),
          );
          if (candidate.isBefore(event.start)) continue;
          if (candidate.isAfter(iterateEndLimit)) continue;
          if (count != -1 && generated >= count) break;
          if (!isException(candidate)) {
            addOccurrence(candidate);
            generated += 1;
          }
        }
        if (count != -1 && generated >= count) break;
        baseWeekStart = baseWeekStart.add(Duration(days: 7 * interval));
      }
      return occurrences..sort((a, b) => a.start.compareTo(b.start));
    }

    var pointer = iterateStart;
    while (!pointer.isAfter(iterateEndLimit)) {
      if (pointer.isBefore(event.start)) {
        pointer = advance(pointer);
        continue;
      }
      if (count != -1 && generated >= count) break;
      if (!isException(pointer)) {
        addOccurrence(pointer);
        generated += 1;
      }
      pointer = advance(pointer);
    }

    if (occurrences.isEmpty && !isException(event.start) && event.start.isBefore(to) && !event.end.isBefore(from)) {
      occurrences.add(event);
    }

    return occurrences..sort((a, b) => a.start.compareTo(b.start));
  }
}

