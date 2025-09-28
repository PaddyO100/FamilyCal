import 'package:flutter/material.dart';

import 'package:familycal/models/membership.dart';
import 'package:familycal/models/task.dart';
import 'package:familycal/services/repositories/task_repository.dart';

class TaskEditorSheet extends StatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.repository,
    required this.householdId,
    required this.createdBy,
    required this.members,
    this.task,
  });

  final TaskRepository repository;
  final String householdId;
  final String createdBy;
  final List<Membership> members;
  final HouseholdTask? task;

  static Future<void> show(
    BuildContext context, {
    required TaskRepository repository,
    required String householdId,
    required String createdBy,
    required List<Membership> members,
    HouseholdTask? task,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom,
        ),
        child: TaskEditorSheet(
          repository: repository,
          householdId: householdId,
          createdBy: createdBy,
          members: members,
          task: task,
        ),
      ),
    );
  }

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDate;
  late List<String> _assigneeIds;
  bool _completed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _dueDate = widget.task?.dueDate;
    _assigneeIds = List.of(widget.task?.assigneeIds ?? <String>[]);
    _completed = widget.task?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel darf nicht leer sein.')),
      );
      return;
    }

    setState(() => _saving = true);

    final task = HouseholdTask(
      id: widget.task?.id ?? '',
      householdId: widget.householdId,
      title: _titleController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      dueDate: _dueDate,
      createdBy: widget.task?.createdBy ?? widget.createdBy,
      isCompleted: _completed,
      assigneeIds: _assigneeIds,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.task == null) {
        await widget.repository.createTask(task);
      } else {
        await widget.repository.updateTask(task);
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $error')),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.task == null
                        ? 'Neue Aufgabe'
                        : 'Aufgabe bearbeiten',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titel',
                  border: OutlineInputBorder(),
                ),
                enabled: !_saving,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
                enabled: !_saving,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDueDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'Fälligkeitsdatum setzen'
                            : 'Fällig bis ${MaterialLocalizations.of(context).formatMediumDate(_dueDate!)}',
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _saving
                          ? null
                          : () => setState(() => _dueDate = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Zugewiesene Mitglieder',
                style: theme.textTheme.titleSmall,
              ),
              Wrap(
                spacing: 8,
                children: widget.members.map((member) {
                  final selected = _assigneeIds.contains(member.userId);
                  return FilterChip(
                    label: Text(member.shortLabel.isEmpty ? 'Mitglied' : member.shortLabel),
                    avatar: CircleAvatar(
                      backgroundColor: Color(int.parse(member.roleColor.replaceFirst('#','0xff'))),
                      child: Text(member.initial, style: const TextStyle(color: Colors.white)),
                    ),
                    selected: selected,
                    onSelected: _saving
                        ? null
                        : (value) {
                            setState(
                              () => value
                                  ? _assigneeIds.add(member.userId)
                                  : _assigneeIds.remove(member.userId),
                            );
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _completed,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _completed = value ?? false),
                title: const Text('Als erledigt markieren'),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Speichern'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
