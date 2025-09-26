import 'package:intl/intl.dart';

class DateMath {
	static String formatDay(DateTime date) {
		return DateFormat('EEE, d. MMM').format(date);
	}

	static String formatTimeRange(DateTime start, DateTime end) {
		final startFormat = DateFormat.Hm();
		final endFormat = DateFormat.Hm();
		return '${startFormat.format(start)} – ${endFormat.format(end)}';
	}

	static bool isSameDay(DateTime a, DateTime b) {
		return a.year == b.year && a.month == b.month && a.day == b.day;
	}

	static bool isSameMoment(DateTime a, DateTime b) {
		return a.toUtc().isAtSameMomentAs(b.toUtc());
	}

	static DateTime startOfDay(DateTime date) {
		return DateTime(date.year, date.month, date.day);
	}

	static DateTime endOfDay(DateTime date) {
		return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
	}

	static DateTime startOfWeek(DateTime date) {
		final weekday = date.weekday;
		return startOfDay(date.subtract(Duration(days: weekday - 1)));
	}

	static DateTime endOfWeek(DateTime date) {
		final weekday = date.weekday;
		return endOfDay(date.add(Duration(days: 7 - weekday)));
	}
}
