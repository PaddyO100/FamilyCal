class RecurrenceRule {
  RecurrenceRule({
    required this.rrule,
    this.exDates = const <DateTime>[],
  });

  final String rrule;
  final List<DateTime> exDates;

  Map<String, dynamic> toJson() {
    return {
      'rrule': rrule,
      'exceptionDates': exDates.map((date) => date.toIso8601String()).toList(),
    };
  }

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) {
    return RecurrenceRule(
      rrule: json['rrule'] as String,
      exDates: (json['exceptionDates'] as List?)
              ?.map((value) => DateTime.parse(value as String))
              .toList() ??
          <DateTime>[],
    );
  }
}
