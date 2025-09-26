import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:familycal/features/calendar/widgets/color_picker.dart';
import 'package:familycal/models/household.dart';
import 'package:familycal/models/membership.dart';
import 'package:familycal/models/role.dart';
import 'package:familycal/services/notifications_service.dart';
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
  late final NotificationsService _notifications;
  String? _inviteCode;

  bool _generating = false;
  bool _notifying = false;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _membershipRepository = MembershipRepository(firestore);
    _householdRepository = HouseholdRepository(firestore);
    _notifications = NotificationsService(FirebaseMessaging.instance);
  }

  @override
  void dispose() {
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
            ],
          );
        },
      ),
    );
  }
}

