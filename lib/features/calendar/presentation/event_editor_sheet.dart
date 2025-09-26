import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:familycal/config/firebase_features.dart';
import 'package:familycal/features/calendar/widgets/category_chips.dart';
import 'package:familycal/models/calendar.dart';
import 'package:familycal/models/event.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/services/functions_service.dart';
import 'package:familycal/services/notifications_service.dart';
import 'package:familycal/services/repositories/calendar_repository.dart';
import 'package:familycal/services/repositories/event_repository.dart';
import 'package:familycal/services/repositories/membership_repository.dart';
import 'package:familycal/utils/recurrence_utils.dart';

enum RecurrenceType { none, daily, weekly, monthly, yearly, custom }

class EventEditorSheet extends StatefulWidget {
  const EventEditorSheet({
    super.key,
    required this.household,
    this.initialEvent,
  });

  final Household household;
  final CalendarEvent? initialEvent;

  static Future<void> show(
    BuildContext context, {
    required Household household,
    CalendarEvent? initialEvent,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: EventEditorSheet(
          household: household,
          initialEvent: initialEvent,
        ),
      ),
    );
  }

  @override
  State<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<EventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _customRecurrenceController = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  String? _selectedCalendarId;
  String _category = defaultCategories.first;
  String _visibility = 'household';
  List<String> _selectedParticipants = <String>[];
  RecurrenceType _recurrenceType = RecurrenceType.none;
  List<int> _weeklyWeekdays = <int>[];
  int _interval = 1;
  List<int> _reminders = <int>[30];

  late final EventRepository _eventRepository;
  late final CalendarRepository _calendarRepository;
  late final MembershipRepository _membershipRepository;
  FunctionsService? _functionsService;
  late final NotificationsService _notificationsService;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _eventRepository = EventRepository(FirebaseFirestore.instance);
    _calendarRepository = CalendarRepository(FirebaseFirestore.instance);
    _membershipRepository = MembershipRepository(FirebaseFirestore.instance);
    if (cloudFunctionsEnabled) {
      _functionsService = FunctionsService(FirebaseFunctions.instance);
    }
    _notificationsService = NotificationsService(FirebaseMessaging.instance);

    final now = DateTime.now();
    _start = widget.initialEvent?.start ?? now;
    _end = widget.initialEvent?.end ?? now.add(const Duration(hours: 1));
    _category = widget.initialEvent?.category ?? _category;
    _visibility = widget.initialEvent?.visibility ?? _visibility;
    _selectedParticipants =
        List<String>.from(widget.initialEvent?.participantIds ?? <String>[]);
    _reminders =
        List<int>.from(widget.initialEvent?.reminderMinutes ?? <int>[30]);
    _selectedCalendarId = widget.initialEvent?.calendarId;

    if (widget.initialEvent != null) {
      _titleController.text = widget.initialEvent!.title;
      _locationController.text = widget.initialEvent!.location ?? '';
      _notesController.text = widget.initialEvent!.notes ?? '';

      final rule = widget.initialEvent!.recurrenceRule;
      if (rule != null) {
        final parsed = RecurrenceUtils.parseRule(rule);
        final freq = parsed['FREQ'];
        _interval = int.tryParse(parsed['INTERVAL'] ?? '1') ?? 1;

        switch (freq) {
          case 'DAILY':
            _recurrenceType = RecurrenceType.daily;
            break;
          case 'WEEKLY':
            _recurrenceType = RecurrenceType.weekly;
            final days = parsed['BYDAY']?.split(',') ?? <String>[];
            _weeklyWeekdays = days.map(_weekdayFromCode).toList();
            break;
          case 'MONTHLY':
            _recurrenceType = RecurrenceType.monthly;
            break;
          case 'YEARLY':
            _recurrenceType = RecurrenceType.yearly;
            break;
          default:
            _recurrenceType = RecurrenceType.custom;
            _customRecurrenceController.text = rule;
        }
      }
    } else {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _selectedParticipants = [uid];
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _customRecurrenceController.dispose();
    super.dispose();
  }

  int _weekdayFromCode(String code) {
    switch (code) {
      case 'MO':
        return DateTime.monday;
      case 'TU':
        return DateTime.tuesday;
      case 'WE':
        return DateTime.wednesday;
      case 'TH':
        return DateTime.thursday;
      case 'FR':
        return DateTime.friday;
      case 'SA':
        return DateTime.saturday;
      case 'SU':
      default:
        return DateTime.sunday;
    }
  }

  String _weekdayCode(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'MO';
      case DateTime.tuesday:
        return 'TU';
      case DateTime.wednesday:
        return 'WE';
      case DateTime.thursday:
        return 'TH';
      case DateTime.friday:
        return 'FR';
      case DateTime.saturday:
        return 'SA';
      case DateTime.sunday:
      default:
        return 'SU';
    }
  }

  String? _buildRecurrenceRule() {
    switch (_recurrenceType) {
      case RecurrenceType.none:
        return null;
      case RecurrenceType.daily:
        return 'FREQ=DAILY;INTERVAL=$_interval';
      case RecurrenceType.weekly:
        final codes = _weeklyWeekdays.isEmpty
            ? _weekdayCode(_start.weekday)
            : _weeklyWeekdays.map(_weekdayCode).join(',');
        return 'FREQ=WEEKLY;INTERVAL=$_interval;BYDAY=$codes';
      case RecurrenceType.monthly:
        return 'FREQ=MONTHLY;INTERVAL=$_interval';
      case RecurrenceType.yearly:
        return 'FREQ=YEARLY;INTERVAL=$_interval';
      case RecurrenceType.custom:
        final custom = _customRecurrenceController.text.trim();
        return custom.isEmpty ? null : custom;
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );

    if (pickedDate == null) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null) {
      return;
    }

    final newDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _start = newDate;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = newDate.isAfter(_start)
            ? newDate
            : _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _saveEvent(
    HouseholdCalendar calendar,
    List<Membership> members,
  ) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _notificationsService.requestPermissions();
      final reminderToken = await _notificationsService.getDeviceToken();

      if (reminderToken != null) {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseFirestore.instance
            .collection('deviceTokens')
            .doc(uid)
            .collection('tokens')
            .doc(reminderToken)
            .set({
          'token': reminderToken,
          'updatedAt': Timestamp.now(),
        });
      }

      final participants = _selectedParticipants.isEmpty
          ? members.map((m) => m.userId).toList()
          : _selectedParticipants.toSet().toList();
      final reminderValues = _reminders.toSet().toList()..sort();
      final event = CalendarEvent(
        id: widget.initialEvent?.id ?? const Uuid().v4(),
        calendarId: calendar.id,
        householdId: widget.household.id,
        title: _titleController.text.trim(),
        start: _start,
        end: _end,
        category: _category,
        visibility: _visibility,
        participantIds: participants,
        location:
            _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        recurrenceRule: _buildRecurrenceRule(),
        reminderMinutes: reminderValues,
      );

      final functionsEnabled = cloudFunctionsEnabled && _functionsService != null;

      if (widget.initialEvent == null) {
        final id = await _eventRepository.createEvent(event);
        if (functionsEnabled) {
          await _functionsService!.scheduleReminders(
            calendarId: calendar.id,
            eventId: id,
            reminderMinutes: reminderValues,
          );
        }
      } else {
        await _eventRepository.updateEvent(event);
        if (functionsEnabled) {
          await _functionsService!.scheduleReminders(
            calendarId: calendar.id,
            eventId: event.id,
            reminderMinutes: reminderValues,
          );
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Termin gespeichert.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RecurrenceType>(
          value: _recurrenceType,
          decoration: const InputDecoration(labelText: 'Wiederholung'),
          items: const [
            DropdownMenuItem(
              value: RecurrenceType.none,
              child: Text('Keine'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.daily,
              child: Text('Täglich'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.weekly,
              child: Text('Wöchentlich'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.monthly,
              child: Text('Monatlich'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.yearly,
              child: Text('Jährlich'),
            ),
            DropdownMenuItem(
              value: RecurrenceType.custom,
              child: Text('Benutzerdefiniert (RRULE)'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _recurrenceType = value);
            }
          },
        ),
        if (_recurrenceType != RecurrenceType.none &&
            _recurrenceType != RecurrenceType.custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: DropdownButtonFormField<int>(
              value: _interval,
              decoration: const InputDecoration(labelText: 'Intervall'),
              items: List.generate(12, (index) => index + 1)
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _interval = value);
                }
              },
            ),
          ),
        if (_recurrenceType == RecurrenceType.weekly)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in _weekdayLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: _weeklyWeekdays.contains(entry.key),
                    onSelected: (selected) {
                      setState(
                        () => selected
                            ? _weeklyWeekdays.add(entry.key)
                            : _weeklyWeekdays.remove(entry.key),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (_recurrenceType == RecurrenceType.custom)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: _customRecurrenceController,
              decoration: const InputDecoration(
                labelText: 'RRULE',
                hintText: 'FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,FR',
              ),
            ),
          ),
      ],
    );
  }

  static const Map<int, String> _weekdayLabels = {
    DateTime.monday: 'Mo',
    DateTime.tuesday: 'Di',
    DateTime.wednesday: 'Mi',
    DateTime.thursday: 'Do',
    DateTime.friday: 'Fr',
    DateTime.saturday: 'Sa',
    DateTime.sunday: 'So',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: StreamBuilder<List<HouseholdCalendar>>(
          stream: _calendarRepository.watchCalendars(widget.household.id),
          builder: (context, calendarSnapshot) {
            if (!calendarSnapshot.hasData) {
              return const SizedBox(
                height: 320,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final calendars = calendarSnapshot.data!;
            if (calendars.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Bitte zuerst einen Kalender anlegen.'),
              );
            }

            _selectedCalendarId ??= calendars.first.id;
            final selectedCalendar = calendars.firstWhere(
              (calendar) => calendar.id == _selectedCalendarId,
              orElse: () => calendars.first,
            );

            return StreamBuilder<List<Membership>>(
              stream:
                  _membershipRepository.watchHouseholdMembers(widget.household.id),
              builder: (context, membershipSnapshot) {
                if (!membershipSnapshot.hasData) {
                  return const SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final members = membershipSnapshot.data!;
                _selectedParticipants = _selectedParticipants
                    .where((id) => members.any((m) => m.userId == id))
                    .toList();

                if (_selectedParticipants.isEmpty && members.isNotEmpty) {
                  _selectedParticipants =
                      members.map((member) => member.userId).toList();
                }

                return Form(
                  key: _formKey,
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        widget.initialEvent == null
                            ? 'Termin erstellen'
                            : 'Termin bearbeiten',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCalendarId,
                        decoration: const InputDecoration(labelText: 'Kalender'),
                        items: calendars
                            .map(
                              (calendar) => DropdownMenuItem(
                                value: calendar.id,
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 6,
                                      backgroundColor: Color(
                                        int.parse(
                                          calendar.color.replaceFirst('#', '0xff'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(calendar.name),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => _selectedCalendarId = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titel',
                          prefixIcon: Icon(Icons.event_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Titel ist erforderlich';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text(
                          'Beginn: ${MaterialLocalizations.of(context).formatMediumDate(_start)} '
                          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_start))}',
                        ),
                        onTap: () => _pickDateTime(isStart: true),
                      ),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: Text(
                          'Ende: ${MaterialLocalizations.of(context).formatMediumDate(_end)} '
                          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_end))}',
                        ),
                        onTap: () => _pickDateTime(isStart: false),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                          labelText: 'Ort',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notizen',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Kategorie',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      CategoryChips(
                        selectedCategory: _category,
                        onCategorySelected: (value) {
                          setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _visibility,
                        decoration: const InputDecoration(labelText: 'Sichtbarkeit'),
                        items: const [
                          DropdownMenuItem(
                            value: 'private',
                            child: Text('Privat'),
                          ),
                          DropdownMenuItem(
                            value: 'household',
                            child: Text('Haushalt'),
                          ),
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Öffentlich'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _visibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Teilnehmer',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final member in members)
                            FilterChip(
                              label: Text(member.roleName),
                              avatar: CircleAvatar(
                                backgroundColor: Color(
                                  int.parse(
                                    member.roleColor.replaceFirst('#', '0xff'),
                                  ),
                                ),
                                child: Text(
                                  member.roleName.isNotEmpty
                                      ? member.roleName.substring(0, 1).toUpperCase()
                                      : '?',
                                ),
                              ),
                              selected: _selectedParticipants.contains(member.userId),
                              onSelected: (selected) {
                                setState(
                                  () => selected
                                      ? _selectedParticipants.add(member.userId)
                                      : _selectedParticipants.remove(member.userId),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRecurrenceSection(),
                      const SizedBox(height: 16),
                      Text(
                        'Erinnerungen',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in const [5, 10, 15, 30, 60, 120])
                            FilterChip(
                              label: Text('$value Min vorher'),
                              selected: _reminders.contains(value),
                              onSelected: (selected) {
                                setState(
                                  () => selected
                                      ? _reminders.add(value)
                                      : _reminders.remove(value),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () => _saveEvent(selectedCalendar, members),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          widget.initialEvent == null
                              ? 'Termin erstellen'
                              : 'Änderungen speichern',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

