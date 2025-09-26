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
  late final NotificationsService _notificationsService;

  bool _isGeneratingInvite = false;
  bool _isRequestingNotifications = false;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    final firestore = FirebaseFirestore.instance;
    _membershipRepository = MembershipRepository(firestore);
    _householdRepository = HouseholdRepository(firestore);
    _notificationsService = NotificationsService(FirebaseMessaging.instance);
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
            ],
          );
        },
      ),
    );
  }
}

