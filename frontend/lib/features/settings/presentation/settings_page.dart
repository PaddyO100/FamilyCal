import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:familycal/features/calendar/widgets/color_picker.dart';
import 'package:familycal/models/calendar.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/models/role.dart';
import 'package:familycal/services/functions_service.dart';
import 'package:familycal/services/notifications_service.dart';
import 'package:familycal/services/repositories/household_repository.dart';
import 'package:familycal/services/repositories/membership_repository.dart';
import 'package:familycal/services/repositories/calendar_repository.dart';

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
  late final FunctionsService _functionsService;
  late final NotificationsService _notificationsService;
  late final CalendarRepository _calendarRepository;

  final _icsController = TextEditingController();
  bool _isGeneratingInvite = false;
  bool _isImportingIcs = false;
  bool _isRequestingNotifications = false;
  String? _inviteCode;
  String? _selectedCalendarId;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _membershipRepository = MembershipRepository(firestore);
    _householdRepository = HouseholdRepository(firestore);
    _functionsService = FunctionsService(FirebaseFunctions.instance);
    _notificationsService = NotificationsService(FirebaseMessaging.instance);
    _calendarRepository = CalendarRepository(firestore);
  }

  @override
  void dispose() {
    _icsController.dispose();
    super.dispose();
  }

  Future<void> _editMember(Membership member) async {
    if (!widget.membership.isAdmin) {
      return;
    }
    final controller = TextEditingController(text: member.roleName);
    Color selectedColor = _colorFromHex(member.roleColor);
    bool isAdmin = member.isAdmin;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, innerSetState) {
            return AlertDialog(
              title: Text('Rolle für ${member.userId} anpassen'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Rollenname'),
                  ),
                  const SizedBox(height: 16),
                  Text('Farbe'),
                  const SizedBox(height: 12),
                  RoleColorPicker(
                    selectedColor: selectedColor,
                    onColorSelected: (color) {
                      innerSetState(() {
                        selectedColor = color;
                      });
                    },
                  ),
                  if (widget.membership.userId != member.userId) ...[
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Administrator'),
                      subtitle: const Text('Erlaubt das Einladen weiterer Mitglieder'),
                      value: isAdmin,
                      onChanged: (value) {
                        innerSetState(() {
                          isAdmin = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = controller.text.trim();
                    if (name.isEmpty) {
                      return;
                    }
                    await _membershipRepository.updateMemberRole(
                      membershipId: member.id,
                      roleName: name,
                      roleColor: _colorToHex(selectedColor),
                    );
                    if (widget.membership.userId != member.userId) {
                      await _membershipRepository.updateAdmin(member.id, isAdmin);
                    }
                    if (!mounted) return;
                    Navigator.of(context).pop();
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

  Future<void> _generateInvite(Household household) async {
    setState(() {
      _isGeneratingInvite = true;
    });
    try {
      final token = await _householdRepository.generateInviteToken(
        householdId: household.id,
        role: widget.membership.isAdmin
            ? HouseholdRole(
                id: widget.membership.roleId,
                name: widget.membership.roleName,
                color: widget.membership.roleColor,
                isAdmin: widget.membership.isAdmin,
              )
            : HouseholdRole(
                id: widget.membership.roleId,
                name: widget.membership.roleName,
                color: widget.membership.roleColor,
              ),
        isAdmin: widget.membership.isAdmin,
      );
      setState(() {
        _inviteCode = token;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingInvite = false;
        });
      }
    }
  }

  Future<void> _importIcs() async {
    final url = _icsController.text.trim();
    if (url.isEmpty || _selectedCalendarId == null) {
      return;
    }
    setState(() {
      _isImportingIcs = true;
    });
    try {
      await _functionsService.triggerIcsImport(url, _selectedCalendarId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ICS Import gestartet.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Import: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImportingIcs = false;
        });
      }
    }
  }

  Future<void> _registerNotifications() async {
    setState(() {
      _isRequestingNotifications = true;
    });
    try {
      await _notificationsService.requestPermissions();
      final token = await _notificationsService.getDeviceToken();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Benachrichtigungen aktiviert.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingNotifications = false;
        });
      }
    }
  }

  Color _colorFromHex(String hex) {
    final sanitized = hex.replaceFirst('#', '');
    final buffer = StringBuffer();
    if (sanitized.length == 6) {
      buffer.write('ff');
    }
    buffer.write(sanitized);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
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
              Text('Haushalt', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: Text(widget.household.name),
                  subtitle: Text('${members.length} Mitglieder'),
                ),
              ),
              const SizedBox(height: 24),
              Text('Mitglieder & Rollen',
                  style: Theme.of(context).textTheme.headlineSmall),
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
                    subtitle: Text(member.isAdmin ? 'Administrator' : 'Mitglied'),
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
                  onPressed: _isGeneratingInvite
                      ? null
                      : () => _generateInvite(widget.household),
                  icon: _isGeneratingInvite
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.key_outlined),
                  label: const Text('Einladungscode erzeugen'),
                ),
                if (_inviteCode != null) ...[
                  const SizedBox(height: 8),
                  SelectableText('Code: $_inviteCode'),
                ],
              ],
              const SizedBox(height: 24),
              Text('Benachrichtigungen',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Push-Benachrichtigungen aktivieren'),
                  subtitle: const Text('FCM Token registrieren und aktualisieren'),
                  trailing: IconButton(
                    icon: _isRequestingNotifications
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    onPressed:
                        _isRequestingNotifications ? null : _registerNotifications,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('ICS Import/Export',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: StreamBuilder<List<HouseholdCalendar>>(
                    stream: _calendarRepository.watchCalendars(widget.household.id),
                    builder: (context, snapshot) {
                      final calendars = snapshot.data ?? <HouseholdCalendar>[];
                      if (calendars.isEmpty) {
                        return const Text('Bitte zuerst einen Kalender anlegen.');
                      }
                      _selectedCalendarId ??= calendars.first.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCalendarId,
                            decoration: const InputDecoration(labelText: 'Zielkalender'),
                            items: calendars
                                .map(
                                  (calendar) => DropdownMenuItem(
                                    value: calendar.id,
                                    child: Text(calendar.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCalendarId = value;
                              });
                            },
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
                            onPressed: _isImportingIcs ? null : _importIcs,
                            child: _isImportingIcs
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Import starten'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Export: Nutze den Cloud Function Endpunkt `exportIcs` oder binde die Firestore Daten in dein bevorzugtes Kalender-Tool ein.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
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

