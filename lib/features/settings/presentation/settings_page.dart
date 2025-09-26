import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:familycal/config/firebase_features.dart';
import 'package:familycal/features/calendar/widgets/color_picker.dart';
import 'package:familycal/models/calendar.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/models/role.dart';
import 'package:familycal/services/functions_service.dart';
import 'package:familycal/services/notifications_service.dart';
import 'package:familycal/services/repositories/calendar_repository.dart';
import 'package:familycal/services/repositories/household_repository.dart';
import 'package:familycal/services/repositories/membership_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.household,
    required this.user,
    required this.membership,
  });

  final Household household;
  final User user;
  final Membership membership;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final MembershipRepository _membershipRepository;
  late final HouseholdRepository _householdRepository;
  FunctionsService? _functions;
  late final NotificationsService _notifications;
  late final CalendarRepository _calendarRepository;

  final _icsController = TextEditingController();
  String? _inviteCode;
  String? _selectedCalendarId;

  bool _generating = false;
  bool _importing = false;
  bool _exporting = false;
  bool _notifying = false;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _membershipRepository = MembershipRepository(firestore);
    _householdRepository = HouseholdRepository(firestore);
    _calendarRepository = CalendarRepository(firestore);
    if (cloudFunctionsEnabled) {
      _functions = FunctionsService(FirebaseFunctions.instance);
    }
    _notifications = NotificationsService(FirebaseMessaging.instance);
  }

  @override
  void dispose() {
    _icsController.dispose();
    super.dispose();
  }

  Future<void> _generateInvite() async {
    setState(() => _generating = true);
    try {
      final role = HouseholdRole(
        id: widget.membership.roleId,
        name: widget.membership.roleName,
        color: widget.membership.roleColor,
        isAdmin: widget.membership.isAdmin,
      );

      final token = await _householdRepository.generateInviteToken(
        householdId: widget.household.id,
        role: role,
        isAdmin: widget.membership.isAdmin,
      );

      if (!mounted) {
        return;
      }

      setState(() => _inviteCode = token);
    } finally {
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  Future<void> _registerNotifications() async {
    setState(() => _notifying = true);
    try {
      await _notifications.requestPermissions();
      final token = await _notifications.getDeviceToken();

      if (token != null) {
        await FirebaseFirestore.instance
            .collection('deviceTokens')
            .doc(widget.user.uid)
            .collection('tokens')
            .doc(token)
            .set({
          'token': token,
          'updatedAt': Timestamp.now(),
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Benachrichtigungen aktiviert.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _notifying = false);
      }
    }
  }

  Future<void> _importIcs() async {
    if (_selectedCalendarId == null) {
      return;
    }

    final url = _icsController.text.trim();
    if (url.isEmpty) {
      return;
    }

    if (!cloudFunctionsEnabled || _functions == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud Functions sind deaktiviert. ICS Import ist derzeit nicht verfügbar.'),
        ),
      );
      return;
    }

    setState(() => _importing = true);
    try {
      await _functions!.triggerIcsImport(url, _selectedCalendarId!);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ICS Import gestartet.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _exportIcs() async {
    if (_selectedCalendarId == null) {
      return;
    }

    if (!cloudFunctionsEnabled || _functions == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cloud Functions sind deaktiviert. ICS Export ist derzeit nicht verfügbar.'),
        ),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final ics = await _functions!.exportIcs(_selectedCalendarId!);

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('ICS Export'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(child: SelectableText(ics)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ics));
                  Navigator.of(dialogContext).pop();
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ICS kopiert.')),
                  );
                },
                child: const Text('In Zwischenablage'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Color _colorFromHex(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('ff$value', radix: 16));
  }

  String _colorToHex(Color color) {
    final rgb = color.value & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _editMember(Membership member) async {
    if (!widget.membership.isAdmin) {
      return;
    }

    final nameController = TextEditingController(text: member.roleName);
    Color selected = _colorFromHex(member.roleColor);
    bool isAdmin = member.isAdmin;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text('Rolle für ${member.userId}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Rollenname'),
                    ),
                    const SizedBox(height: 12),
                    RoleColorPicker(
                      selectedColor: selected,
                      onColorSelected: (color) => setStateDialog(() => selected = color),
                    ),
                    if (widget.membership.userId != member.userId)
                      SwitchListTile.adaptive(
                        title: const Text('Administrator'),
                        value: isAdmin,
                        onChanged: (value) => setStateDialog(() => isAdmin = value),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      return;
                    }

                    await _membershipRepository.updateMemberRole(
                      membershipId: member.id,
                      roleName: name,
                      roleColor: _colorToHex(selected),
                    );

                    if (widget.membership.userId != member.userId) {
                      await _membershipRepository.updateAdmin(member.id, isAdmin);
                    }

                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: FirebaseAuth.instance.signOut,
          ),
        ],
      ),
      body: StreamBuilder<List<Membership>>(
        stream: _membershipRepository.watchHouseholdMembers(widget.household.id),
        builder: (context, snapshot) {
          final members = snapshot.data ?? <Membership>[];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Haushalt', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(widget.household.name),
                  subtitle: Text('${members.length} Mitglieder'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Mitglieder & Rollen', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              ...members.map(
                (member) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorFromHex(member.roleColor),
                      child: Text(
                        member.roleName.isEmpty
                            ? '?'
                            : member.roleName.substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(member.roleName),
                    subtitle:
                        Text(member.isAdmin ? 'Administrator' : 'Mitglied'),
                    trailing: widget.membership.isAdmin
                        ? IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editMember(member),
                          )
                        : null,
                  ),
                ),
              ),
              if (widget.membership.isAdmin) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _generating ? null : _generateInvite,
                  icon: _generating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.key_outlined),
                  label: const Text('Einladungscode erzeugen'),
                ),
                if (_inviteCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SelectableText('Code: $_inviteCode'),
                  ),
              ],
              const SizedBox(height: 24),
              Text('Benachrichtigungen', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push-Benachrichtigungen aktivieren'),
                  trailing: IconButton(
                    icon: _notifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    onPressed: _notifying ? null : _registerNotifications,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('ICS Import/Export', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              if (cloudFunctionsEnabled && _functions != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StreamBuilder<List<HouseholdCalendar>>(
                      stream: _calendarRepository.watchCalendars(widget.household.id),
                      builder: (context, calendarSnapshot) {
                        final calendars =
                            calendarSnapshot.data ?? <HouseholdCalendar>[];
                        if (calendars.isEmpty) {
                          return const Text(
                            'Bitte zuerst einen Kalender anlegen.',
                          );
                        }

                        _selectedCalendarId ??= calendars.first.id;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedCalendarId,
                              decoration:
                                  const InputDecoration(labelText: 'Zielkalender'),
                              items: calendars
                                  .map(
                                    (calendar) => DropdownMenuItem(
                                      value: calendar.id,
                                      child: Text(calendar.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() {
                                _selectedCalendarId = value;
                              }),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _icsController,
                              decoration: const InputDecoration(
                                labelText: 'ICS Feed URL',
                                hintText: 'https://example.com/calendar.ics',
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _importing ? null : _importIcs,
                              child: _importing
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Import starten'),
                            ),
                            FilledButton.tonal(
                              onPressed: _exporting ? null : _exportIcs,
                              child: _exporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Export anzeigen'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'ICS Import/Export ist derzeit deaktiviert.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Diese Funktion benötigt Firebase Cloud Functions. '
                          'Aktiviere sie in den Firebase-Einstellungen oder aktualisiere auf einen Tarif mit Functions-Unterstützung.',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

