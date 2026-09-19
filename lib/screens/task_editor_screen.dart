import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/quest_type.dart';
import '../models/recurrence_rule.dart';
import '../models/task.dart';
import '../services/date_display.dart';
import '../services/task_validator.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, this.task});

  final Task? task;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _validator = const TaskValidator();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _xpController;
  DateTime? _dueDate;
  var _submitted = false;
  late QuestType _questType;
  late RecurrenceKind _recurrenceKind;
  late List<int> _weekdays;
  late int _dayOfMonth;
  var _customUsesMonthDay = true;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final now = DateTime.now();
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _xpController = TextEditingController(
      text: task == null ? '' : '${task.xpReward}',
    );
    _dueDate = task?.dueDate;
    _questType = task?.questType ?? QuestType.sideQuest;
    final recurrence = task?.recurrence;
    _recurrenceKind = recurrence?.kind ?? RecurrenceKind.daily;
    _weekdays = List<int>.from(
      recurrence?.weekdays ?? [now.weekday],
    );
    _dayOfMonth = recurrence?.dayOfMonth ?? now.day;
    _customUsesMonthDay =
        recurrence == null || recurrence.dayOfMonth != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  RecurrenceRule? _buildRecurrence() {
    if (_questType != QuestType.habit) {
      return null;
    }
    switch (_recurrenceKind) {
      case RecurrenceKind.daily:
        return RecurrenceRule.daily;
      case RecurrenceKind.weekly:
        return RecurrenceRule.weekly(
          _weekdays.isEmpty ? [DateTime.now().weekday] : _weekdays,
        );
      case RecurrenceKind.monthly:
        return RecurrenceRule.monthly(_dayOfMonth);
      case RecurrenceKind.custom:
        if (_customUsesMonthDay) {
          return RecurrenceRule.custom(dayOfMonth: _dayOfMonth);
        }
        return RecurrenceRule.custom(
          weekdays: _weekdays.isEmpty ? [DateTime.now().weekday] : _weekdays,
        );
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) {
      setState(() => _dueDate = selected);
    }
  }

  void _save() {
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final draft = Task(
      id: widget.task?.id ?? '',
      title: _titleController.text.trim(),
      description: _validator.normalizeDescription(_descriptionController.text),
      xpReward: _validator.parseXp(_xpController.text),
      dueDate: _dueDate,
      isCompleted: widget.task?.isCompleted ?? false,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      completedAt: widget.task?.completedAt,
      questType: _questType,
      recurrence: _buildRecurrence(),
      completedDates: widget.task?.completedDates ?? const [],
    );
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit quest' : 'New quest'),
        actions: [
          TextButton(
            key: const Key('save-task'),
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              TextFormField(
                key: const Key('task-title-field'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Gym, studying, reading…',
                ),
                validator: (value) => _validator.titleError(value ?? ''),
              ),
              const SizedBox(height: 16),
              Text(
                'Quest Type',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<QuestType>(
                key: const Key('quest-type-selector'),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: QuestType.habit,
                    label: Text('Character Arc'),
                    icon: Icon(Icons.replay),
                  ),
                  ButtonSegment(
                    value: QuestType.sideQuest,
                    label: Text('Side Hustle'),
                    icon: Icon(Icons.flag_outlined),
                  ),
                ],
                selected: {_questType},
                onSelectionChanged: (selected) {
                  setState(() => _questType = selected.first);
                },
              ),
              const SizedBox(height: 8),
              Text(
                _questType == QuestType.habit
                    ? 'Repeats on a schedule. Completing it today awards XP once and it returns when due again.'
                    : 'One-time quest. Completing it awards XP and it stays finished.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_questType == QuestType.habit) ...[
                const SizedBox(height: 20),
                Text(
                  'Repeat',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<RecurrenceKind>(
                  key: const Key('recurrence-kind-field'),
                  initialValue: _recurrenceKind,
                  decoration: const InputDecoration(
                    labelText: 'Recurrence',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: RecurrenceKind.daily,
                      child: Text('Daily'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceKind.weekly,
                      child: Text('Weekly'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceKind.monthly,
                      child: Text('Monthly'),
                    ),
                    DropdownMenuItem(
                      value: RecurrenceKind.custom,
                      child: Text('Custom'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _recurrenceKind = value);
                    }
                  },
                ),
                if (_recurrenceKind == RecurrenceKind.weekly) ...[
                  const SizedBox(height: 12),
                  _WeekdayPicker(
                    selected: _weekdays,
                    onChanged: (days) => setState(() => _weekdays = days),
                  ),
                ],
                if (_recurrenceKind == RecurrenceKind.monthly) ...[
                  const SizedBox(height: 12),
                  _DayOfMonthPicker(
                    day: _dayOfMonth,
                    onChanged: (day) => setState(() => _dayOfMonth = day),
                  ),
                ],
                if (_recurrenceKind == RecurrenceKind.custom) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    key: const Key('custom-recurrence-mode'),
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Day of month'),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Days of week'),
                      ),
                    ],
                    selected: {_customUsesMonthDay},
                    onSelectionChanged: (selected) {
                      setState(() => _customUsesMonthDay = selected.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_customUsesMonthDay)
                    _DayOfMonthPicker(
                      day: _dayOfMonth,
                      onChanged: (day) => setState(() => _dayOfMonth = day),
                    )
                  else
                    _WeekdayPicker(
                      selected: _weekdays,
                      onChanged: (days) => setState(() => _weekdays = days),
                    ),
                ],
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('task-description-field'),
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('task-xp-field'),
                controller: _xpController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'XP reward',
                  helperText: 'Stored with the quest. XP is not awarded yet.',
                ),
                validator: (value) => _validator.xpError(value ?? ''),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _dueDate == null
                      ? 'Due date (optional)'
                      : 'Due ${formatTaskDate(_dueDate!)}',
                ),
                trailing: _dueDate == null
                    ? TextButton(
                        onPressed: _pickDueDate,
                        child: const Text('Add'),
                      )
                    : TextButton(
                        onPressed: () => setState(() => _dueDate = null),
                        child: const Text('Clear'),
                      ),
                onTap: _pickDueDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({
    required this.selected,
    required this.onChanged,
  });

  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  static const _days = [
    (DateTime.monday, 'Mon'),
    (DateTime.tuesday, 'Tue'),
    (DateTime.wednesday, 'Wed'),
    (DateTime.thursday, 'Thu'),
    (DateTime.friday, 'Fri'),
    (DateTime.saturday, 'Sat'),
    (DateTime.sunday, 'Sun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in _days)
          FilterChip(
            key: Key('weekday-${day.$1}'),
            label: Text(day.$2),
            selected: selected.contains(day.$1),
            onSelected: (isSelected) {
              final next = [...selected];
              if (isSelected) {
                if (!next.contains(day.$1)) {
                  next.add(day.$1);
                }
              } else {
                next.remove(day.$1);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _DayOfMonthPicker extends StatelessWidget {
  const _DayOfMonthPicker({
    required this.day,
    required this.onChanged,
  });

  final int day;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: const Key('day-of-month-field'),
      initialValue: day,
      decoration: const InputDecoration(
        labelText: 'Day of month',
      ),
      items: [
        for (var i = 1; i <= 31; i++)
          DropdownMenuItem(
            value: i,
            child: Text('$i'),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
