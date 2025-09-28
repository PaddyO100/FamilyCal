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

  Future<String?> _registerNotifications() async {
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
      return null;
    } catch (error) {
      return 'Fehler: $error';
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
    final argb = color.toARGB32();
    final rgb = argb & 0x00FFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  Future<void> _editMember(Membership member) async {
    final isSelf = member.userId == widget.membership.userId;
    final canEditDisplay = widget.membership.isAdmin || isSelf;
    final canEditRole = widget.membership.isAdmin; // Nur Admins ändern Rollenname für andere (oder sich selbst optional)
    if (!canEditDisplay && !canEditRole) return;

    final displayController = TextEditingController(text: member.displayName ?? member.roleName);
    final roleController = TextEditingController(text: member.roleName);
    Color selected = _colorFromHex(member.roleColor);
    bool isAdmin = member.isAdmin;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          title: Text(member.label.isEmpty ? 'Mitglied bearbeiten' : member.label),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: displayController,
                  decoration: const InputDecoration(labelText: 'Anzeigename'),
                  enabled: canEditDisplay,
                ),
                const SizedBox(height: 12),
                if (canEditRole) TextField(
                  controller: roleController,
                  decoration: const InputDecoration(labelText: 'Rollenbezeichnung'),
                ),
                const SizedBox(height: 12),
                RoleColorPicker(
                  selectedColor: selected,
                  onColorSelected: (c)=> setStateDialog(()=> selected = c),
                ),
                if (canEditRole && !isSelf)
                  SwitchListTile.adaptive(
                    title: const Text('Administrator'),
                    value: isAdmin,
                    onChanged: (v)=> setStateDialog(()=> isAdmin = v),
                  ),
                if (!canEditRole && canEditDisplay)
                  const Padding(
                    padding: EdgeInsets.only(top:8),
                    child: Text('Du kannst deinen Anzeigenamen & deine Farbe anpassen.', style: TextStyle(fontSize:12)),
                  )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: ()=> Navigator.of(dialogContext).pop(), child: const Text('Abbrechen')),
            FilledButton(onPressed: () async {
              final newDisplay = displayController.text.trim();
              final newRole = roleController.text.trim();
              if (newDisplay.isEmpty) return; // Minimalvalidierung
              // Update DisplayName falls geändert
              if (newDisplay != (member.displayName ?? member.roleName)) {
                await _membershipRepository.updateDisplayName(membershipId: member.id, displayName: newDisplay);
              }
              // Update Rolle + Farbe falls Admin & geändert
              if (canEditRole && (newRole != member.roleName || _colorToHex(selected) != member.roleColor)) {
                await _membershipRepository.updateMemberRole(
                  membershipId: member.id,
                  roleName: newRole.isEmpty ? member.roleName : newRole,
                  roleColor: _colorToHex(selected),
                );
              } else if (_colorToHex(selected) != member.roleColor) {
                // Nur Farbe geändert (Nicht-Admin), Rolle unverändert
                await _membershipRepository.updateMemberRole(
                  membershipId: member.id,
                  roleName: member.roleName,
                  roleColor: _colorToHex(selected),
                );
              }
              if (canEditRole && !isSelf && isAdmin != member.isAdmin) {
                await _membershipRepository.updateAdmin(member.id, isAdmin);
              }
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            }, child: const Text('Speichern'))
          ],
        ),
      ),
    );
  }

  Future<bool> _isLastAdmin(List<Membership> members, Membership m){
    final admins = members.where((mm)=> mm.isAdmin).map((e)=> e.userId).toSet();
    return Future.value(admins.length == 1 && admins.contains(m.userId));
  }

  Future<void> _removeMember(List<Membership> members, Membership member) async {
    if (!widget.membership.isAdmin) return;
    if (await _isLastAdmin(members, member)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Der letzte Administrator kann nicht entfernt werden.')));
      }
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (c)=> AlertDialog(
      title: const Text('Mitglied entfernen?'),
      content: Text('Soll ${member.roleName} wirklich entfernt werden?'),
      actions: [TextButton(onPressed: ()=> Navigator.pop(c,false), child: const Text('Abbrechen')), FilledButton(onPressed: ()=> Navigator.pop(c,true), child: const Text('Entfernen'))],
    ));
    if (confirm != true) return;
    try {
      await _membershipRepository.deleteMembership(member.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${member.roleName} entfernt.')));
      }
    } catch (e){
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _leaveHousehold(List<Membership> members) async {
    final me = widget.membership;
    if (await _isLastAdmin(members, me)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Du bist der letzte Admin und kannst den Haushalt nicht verlassen. Übertrage zuerst die Admin-Rolle.')));
      }
      return;
    }
    final confirm = await showDialog<bool>(context: context, builder: (c)=> AlertDialog(
      title: const Text('Haushalt verlassen?'),
      content: const Text('Dein Zugriff auf Kalender & Daten dieses Haushalts erlischt. Fortfahren?'),
      actions: [TextButton(onPressed: ()=> Navigator.pop(c,false), child: const Text('Abbrechen')), FilledButton(onPressed: ()=> Navigator.pop(c,true), child: const Text('Verlassen'))],
    ));
    if (confirm != true) return;
    try {
      await _membershipRepository.deleteMembership(me.id);
      if (mounted) {
        Navigator.of(context)
            .pop(); // zurück
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Haushalt verlassen.')));
      }
    } catch (e){
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
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
                    onTap: () => _editMember(member),
                    leading: CircleAvatar(
                      backgroundColor: _colorFromHex(member.roleColor),
                      child: Text(member.initial),
                    ),
                    title: Text(member.label.isEmpty ? '(Ohne Name)' : member.label),
                    subtitle: Text(member.isAdmin ? 'Administrator${(member.label != member.roleName) ? ' · Rolle: ${member.roleName}' : ''}' : 'Mitglied${(member.label != member.roleName) ? ' · Rolle: ${member.roleName}' : ''}'),
                    trailing: widget.membership.isAdmin
                        ? PopupMenuButton<String>(
                            onSelected: (value){
                              switch(value){
                                case 'edit': _editMember(member); break;
                                case 'remove': _removeMember(members, member); break;
                              }
                            },
                            itemBuilder: (c)=> [
                              const PopupMenuItem(value:'edit', child: Text('Bearbeiten')),
                              if (member.userId != widget.membership.userId) const PopupMenuItem(value:'remove', child: Text('Entfernen')),
                            ],
                          )
                        : (member.userId == widget.membership.userId ? IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Profil bearbeiten', onPressed: ()=> _editMember(member)) : null),
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
                    onPressed: _notifying
                        ? null
                        : () async {
                            final result = await _registerNotifications();
                            if (!context.mounted) {
                              return;
                            }

                            if (result == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Benachrichtigungen aktiviert.'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result)),
                              );
                            }
                          },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (widget.membership.isAdmin)
                FilledButton.icon(
                  onPressed: () async {
                    final count = await _membershipRepository.fillMissingDisplayNames(widget.household.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(count == 0 ? 'Alle Anzeigenamen bereits gesetzt.' : '$count Anzeigenamen ergänzt.')));
                  },
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('Anzeigenamen auffüllen'),
                ),
              const SizedBox(height: 12),
              if (!widget.membership.isAdmin)
                FilledButton.icon(
                  onPressed: ()=> _leaveHousehold(members),
                  icon: const Icon(Icons.logout),
                  label: const Text('Haushalt verlassen'),
                ),
              if (widget.membership.isAdmin)
                OutlinedButton.icon(
                  onPressed: ()=> _leaveHousehold(members),
                  icon: const Icon(Icons.logout),
                  label: const Text('Haushalt verlassen (nicht letzter Admin)'),
                ),
            ],
          );
        },
      ),
    );
  }
}
