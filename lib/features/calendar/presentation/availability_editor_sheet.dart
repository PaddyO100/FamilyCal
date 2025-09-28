import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:familycal/models/availability.dart';
import 'package:familycal/services/repositories/availability_repository.dart';

class AvailabilityEditorSheet extends StatefulWidget {
  const AvailabilityEditorSheet({
    super.key,
    required this.repository,
    required this.householdId,
    required this.userId,
    required this.date,
    this.initialAvailability,
  });

  final AvailabilityRepository repository;
  final String householdId;
  final String userId;
  final DateTime date;
  final DailyAvailability? initialAvailability;

  static Future<void> show(
    BuildContext context, {
    required AvailabilityRepository repository,
    required String householdId,
    required String userId,
    required DateTime date,
    DailyAvailability? availability,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AvailabilityEditorSheet(
            repository: repository,
            householdId: householdId,
            userId: userId,
            date: date,
            initialAvailability: availability,
          ),
        );
      },
    );
  }

  @override
  State<AvailabilityEditorSheet> createState() => _AvailabilityEditorSheetState();
}

class _AvailabilityEditorSheetState extends State<AvailabilityEditorSheet> {
  late List<AvailabilitySlot> _slots;
  late TextEditingController _noteController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _slots = List.of(widget.initialAvailability?.slots ?? const <AvailabilitySlot>[]);
    _noteController = TextEditingController(text: widget.initialAvailability?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addSlot() async {
    final messenger = ScaffoldMessenger.of(context);
    final now = TimeOfDay.fromDateTime(DateTime.now());
    final start = await showTimePicker(
      context: context,
      initialTime: _slots.isEmpty
          ? now
          : TimeOfDay(
              hour: (_slots.last.endMinutes ~/ 60).clamp(0, 23),
              minute: _slots.last.endMinutes % 60,
            ),
    );
    if (start == null) return;
    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (start.hour + 1).clamp(0, 23), minute: start.minute),
    );
    if (end == null) return;
    if (!mounted) return;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Endzeit muss nach der Startzeit liegen.')),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    setState(() {
      _slots = List.of(_slots)
        ..add(AvailabilitySlot(startMinutes: startMinutes, endMinutes: endMinutes))
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    });
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final base = widget.initialAvailability ??
          DailyAvailability(
            id: DailyAvailability.docId(widget.date, widget.userId),
            householdId: widget.householdId,
            userId: widget.userId,
            date: DateTime(widget.date.year, widget.date.month, widget.date.day),
            slots: const <AvailabilitySlot>[],
          );
      final updated = base.copyWith(
        slots: _slots,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        updatedAt: DateTime.now(),
      );
      if (updated.slots.isEmpty) {
        await widget.repository.deleteAvailability(userId: widget.userId, date: widget.date);
      } else {
        await widget.repository.upsertAvailability(updated);
      }
      if (!context.mounted) {
        return;
      }

      navigator.pop();
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: ${error.message ?? error.code}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAvailability() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await widget.repository.deleteAvailability(
        userId: widget.userId,
        date: widget.date,
      );

      if (!context.mounted) {
        return;
      }

      navigator.pop();
    } on FirebaseException catch (error) {
      if (!context.mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: ${error.message ?? error.code}')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verfügbarkeit für ${MaterialLocalizations.of(context).formatFullDate(widget.date)}',
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_slots.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('Keine Zeitfenster hinterlegt.'),
              )
            else
              ..._slots.map((slot) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(slot.formatLabel()),
                      subtitle: slot.note != null ? Text(slot.note!) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() {
                                  _slots = List.of(_slots)..remove(slot);
                                });
                              },
                      ),
                    ),
                  )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addSlot,
              icon: const Icon(Icons.add),
              label: const Text('Zeitfenster hinzufügen'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notiz (optional)',
                border: OutlineInputBorder(),
              ),
              enabled: !_saving,
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.initialAvailability != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _deleteAvailability,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Löschen'),
                  )
                else
                  const SizedBox.shrink(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Speichern'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

