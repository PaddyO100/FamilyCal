import 'package:flutter_test/flutter_test.dart';

import 'package:familycal/models/availability.dart';

void main() {
  test('DailyAvailability serializes and restores slots', () {
    final availability = DailyAvailability(
      id: DailyAvailability.docId(DateTime(2024, 3, 5), 'user1'),
      householdId: 'hh1',
      userId: 'user1',
      date: DateTime(2024, 3, 5),
      slots: const [
        AvailabilitySlot(startMinutes: 8 * 60, endMinutes: 10 * 60),
        AvailabilitySlot(startMinutes: 14 * 60, endMinutes: 16 * 60, note: 'Nachmittag'),
      ],
      note: 'Homeoffice',
      updatedAt: DateTime(2024, 3, 4, 22),
    );

    final json = availability.toJson();
    final restored = DailyAvailability.fromJson(json, id: availability.id);

    expect(restored.id, availability.id);
    expect(restored.slots.length, 2);
    expect(restored.slots.first.startMinutes, 8 * 60);
    expect(restored.slots.last.note, 'Nachmittag');
    expect(restored.note, 'Homeoffice');
  });
}
