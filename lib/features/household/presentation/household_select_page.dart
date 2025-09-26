import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:familycal/models/role.dart';
import 'package:familycal/services/repositories/household_repository.dart';

class HouseholdSelectPage extends StatefulWidget {
  const HouseholdSelectPage({super.key, required this.user});

  final User user;

  @override
  State<HouseholdSelectPage> createState() => _HouseholdSelectPageState();
}

class _HouseholdSelectPageState extends State<HouseholdSelectPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _inviteController = TextEditingController();

  bool _isSubmitting = false;
  bool _isJoining = false;
  String? _error;

  late final HouseholdRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = HouseholdRepository(FirebaseFirestore.instance);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final adminRole = HouseholdRole(
        id: const Uuid().v4(),
        name: 'Admin',
        color: '#5B67F1',
        isAdmin: true,
      );

      await _repository.createHousehold(
        adminUid: widget.user.uid,
        name: _nameController.text.trim(),
        adminRole: adminRole,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _joinHousehold() async {
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Bitte Code eingeben');
      return;
    }

    setState(() => _isJoining = true);

    try {
      await _repository.joinWithInvite(
        token: code,
        userId: widget.user.uid,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Haushalt beigetreten.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalt wählen'),
        actions: [
          IconButton(
            onPressed: FirebaseAuth.instance.signOut,
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lege deinen ersten Haushalt an',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Haushaltsname',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Bitte Namen eingeben';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _createHousehold,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_home_work_outlined),
                    label: const Text('Haushalt erstellen'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Einladungscode vorhanden?',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _inviteController,
                    decoration: const InputDecoration(
                      labelText: 'Code eingeben',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isJoining ? null : _joinHousehold,
                    icon: _isJoining
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Haushalt beitreten'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

