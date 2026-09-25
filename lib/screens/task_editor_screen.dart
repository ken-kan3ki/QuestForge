import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/game_constants.dart';
import '../models/quest_difficulty.dart';
import '../models/quest_type.dart';
import '../models/recurrence_rule.dart';
import '../models/reminder_config.dart';
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
  late QuestDifficulty _difficulty;
  late RecurrenceKind _recurrenceKind;
  late List<int> _weekdays;
  late int _dayOfMonth;
  var _customUsesMonthDay = true;

  // ── Reminder State ──────────────────────────────────────────────────────────
  var _reminderEnabled = false;
  var _reminderType = ReminderType.custom;
  DateTime? _reminderCustomDate;
  TimeOfDay? _reminderCustomTime;
  var _reminderFrequency = ReminderFrequency.daily;
  late List<int> _reminderWeekdays;
  late int _reminderDayOfMonth;
  var _reminderRecurringTime = const TimeOfDay(hour: 20, minute: 0);
  String? _reminderValidationError;

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
    if (task == null) {
      _difficulty = QuestDifficulty.standard;
      _xpController = TextEditingController(text: '${GameConstants.xpStandard}');
    } else {
      _difficulty = QuestDifficulty.fromXp(task.xpReward);
      _xpController = TextEditingController(text: '${task.xpReward}');
    }
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

    // Initialize reminder state
    final reminder = task?.reminder;
    if (reminder != null && reminder.enabled) {
      _reminderEnabled = true;
      _reminderType = reminder.type;
      if (reminder.customDateTime != null) {
        _reminderCustomDate = DateTime(
          reminder.customDateTime!.year,
          reminder.customDateTime!.month,
          reminder.customDateTime!.day,
        );
        _reminderCustomTime = TimeOfDay(
          hour: reminder.customDateTime!.hour,
          minute: reminder.customDateTime!.minute,
        );
      } else {
        final tomorrow = now.add(const Duration(days: 1));
        _reminderCustomDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
        _reminderCustomTime = const TimeOfDay(hour: 20, minute: 0);
      }
      _reminderFrequency = reminder.frequency ?? ReminderFrequency.daily;
      _reminderWeekdays = List<int>.from(
        reminder.selectedWeekdays.isNotEmpty
            ? reminder.selectedWeekdays
            : [now.weekday],
      );
      _reminderDayOfMonth = reminder.dayOfMonth ?? now.day;
      if (reminder.time != null) {
        _reminderRecurringTime = reminder.time!.toTimeOfDay();
      }
    } else {
      _reminderEnabled = false;
      _reminderType = ReminderType.custom;
      final tomorrow = now.add(const Duration(days: 1));
      _reminderCustomDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      _reminderCustomTime = const TimeOfDay(hour: 20, minute: 0);
      _reminderFrequency = ReminderFrequency.daily;
      _reminderWeekdays = [now.weekday];
      _reminderDayOfMonth = now.day;
      _reminderRecurringTime = const TimeOfDay(hour: 20, minute: 0);
    }
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

  ReminderConfig? _buildReminder() {
    if (!_reminderEnabled) {
      return null;
    }
    if (_reminderType == ReminderType.custom) {
      if (_reminderCustomDate == null || _reminderCustomTime == null) {
        return null;
      }
      final dt = DateTime(
        _reminderCustomDate!.year,
        _reminderCustomDate!.month,
        _reminderCustomDate!.day,
        _reminderCustomTime!.hour,
        _reminderCustomTime!.minute,
      );
      return ReminderConfig.custom(
        dateTime: dt,
        enabled: true,
      );
    }

    final remTime = ReminderTime.fromTimeOfDay(_reminderRecurringTime);
    switch (_reminderFrequency) {
      case ReminderFrequency.daily:
        return ReminderConfig.daily(
          time: remTime,
          enabled: true,
        );
      case ReminderFrequency.weekly:
        return ReminderConfig.weekly(
          weekdays: _reminderWeekdays,
          time: remTime,
          enabled: true,
        );
      case ReminderFrequency.monthly:
        return ReminderConfig.monthly(
          dayOfMonth: _reminderDayOfMonth,
          time: remTime,
          enabled: true,
        );
    }
  }

  String? _validateReminder() {
    if (!_reminderEnabled) {
      return null;
    }
    final now = DateTime.now();
    if (_reminderType == ReminderType.custom) {
      if (_reminderCustomDate == null || _reminderCustomTime == null) {
        return 'Please select a date and time for the reminder.';
      }
      final dt = DateTime(
        _reminderCustomDate!.year,
        _reminderCustomDate!.month,
        _reminderCustomDate!.day,
        _reminderCustomTime!.hour,
        _reminderCustomTime!.minute,
      );
      if (!dt.isAfter(now)) {
        return 'Reminder date and time must be in the future.';
      }
    } else if (_reminderType == ReminderType.recurring) {
      if (_reminderFrequency == ReminderFrequency.weekly) {
        if (_reminderWeekdays.isEmpty) {
          return 'Select at least one day for weekly reminder.';
        }
      } else if (_reminderFrequency == ReminderFrequency.monthly) {
        if (_reminderDayOfMonth < 1 || _reminderDayOfMonth > 31) {
          return 'Day of the month must be between 1 and 31.';
        }
      }
    }
    return null;
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

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _reminderCustomDate ?? now;
    final first = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) {
      setState(() {
        _reminderCustomDate = selected;
        _reminderValidationError = _validateReminder();
      });
    }
  }

  Future<void> _pickCustomTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderCustomTime ?? TimeOfDay.now(),
    );
    if (selected != null) {
      setState(() {
        _reminderCustomTime = selected;
        _reminderValidationError = _validateReminder();
      });
    }
  }

  Future<void> _pickRecurringTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderRecurringTime,
    );
    if (selected != null) {
      setState(() {
        _reminderRecurringTime = selected;
        _reminderValidationError = null;
      });
    }
  }

  void _save() {
    setState(() => _submitted = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    final reminderError = _validateReminder();
    setState(() => _reminderValidationError = reminderError);

    if (!formValid || reminderError != null) {
      return;
    }

    final draft = Task(
      id: widget.task?.id ?? '',
      title: _titleController.text.trim(),
      description: _validator.normalizeDescription(_descriptionController.text),
      xpReward: _validator.parseXp(
        _xpController.text,
        originalXp: widget.task?.xpReward,
      ),
      dueDate: _dueDate,
      isCompleted: widget.task?.isCompleted ?? false,
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      completedAt: widget.task?.completedAt,
      questType: _questType,
      recurrence: _buildRecurrence(),
      completedDates: widget.task?.completedDates ?? const [],
      reminder: _buildReminder(),
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
              Text(
                'Difficulty',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<QuestDifficulty>(
                key: const Key('difficulty-selector'),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(
                    value: QuestDifficulty.light,
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: QuestDifficulty.standard,
                    label: Text('Standard'),
                  ),
                  ButtonSegment(
                    value: QuestDifficulty.challenging,
                    label: Text('Challenging'),
                  ),
                  ButtonSegment(
                    value: QuestDifficulty.custom,
                    label: Text('Custom'),
                  ),
                ],
                selected: {_difficulty},
                onSelectionChanged: (selected) {
                  final newDiff = selected.first;
                  setState(() {
                    _difficulty = newDiff;
                    if (newDiff != QuestDifficulty.custom) {
                      _xpController.text = '${newDiff.defaultXp}';
                    } else {
                      final currentVal = int.tryParse(_xpController.text);
                      if (currentVal == null ||
                          currentVal < GameConstants.minCustomXp ||
                          currentVal > GameConstants.maxCustomXp) {
                        _xpController.text = '25';
                      }
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('task-xp-field'),
                controller: _xpController,
                enabled: _difficulty == QuestDifficulty.custom,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'XP reward',
                  helperText: _difficulty == QuestDifficulty.custom
                      ? 'Custom reward between 5 and 50 XP.'
                      : '${_difficulty.label} difficulty awards ${_difficulty.defaultXp} base XP.',
                ),
                validator: (value) => _validator.xpError(
                  value ?? '',
                  originalXp: widget.task?.xpReward,
                ),
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const Key('reminder-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Reminder',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _reminderEnabled
                      ? 'Notification reminder enabled'
                      : 'Notify when this quest is due',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _reminderEnabled,
                onChanged: (value) {
                  setState(() {
                    _reminderEnabled = value;
                    _reminderValidationError = null;
                  });
                },
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 12),
                Text(
                  'Reminder Type',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ReminderType>(
                  key: const Key('reminder-type-selector'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: ReminderType.custom,
                      label: Text('Custom'),
                      icon: Icon(Icons.alarm_outlined, size: 18),
                    ),
                    ButtonSegment(
                      value: ReminderType.recurring,
                      label: Text('Recurring'),
                      icon: Icon(Icons.repeat, size: 18),
                    ),
                  ],
                  selected: {_reminderType},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _reminderType = selected.first;
                      _reminderValidationError = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (_reminderType == ReminderType.custom) ...[
                  Text(
                    'Date',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('reminder-custom-date-button'),
                    onPressed: _pickCustomDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _reminderCustomDate != null
                          ? formatReminderDate(_reminderCustomDate!)
                          : 'Select Date',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Time',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('reminder-custom-time-button'),
                    onPressed: _pickCustomTime,
                    icon: const Icon(Icons.access_time_outlined, size: 18),
                    label: Text(
                      _reminderCustomTime != null
                          ? _reminderCustomTime!.format(context)
                          : 'Select Time',
                    ),
                  ),
                ] else ...[
                  Text(
                    'Frequency',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ReminderFrequency>(
                    key: const Key('reminder-frequency-selector'),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ReminderFrequency.daily,
                        label: Text('Daily'),
                      ),
                      ButtonSegment(
                        value: ReminderFrequency.weekly,
                        label: Text('Weekly'),
                      ),
                      ButtonSegment(
                        value: ReminderFrequency.monthly,
                        label: Text('Monthly'),
                      ),
                    ],
                    selected: {_reminderFrequency},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _reminderFrequency = selected.first;
                        _reminderValidationError = null;
                      });
                    },
                  ),
                  if (_reminderFrequency == ReminderFrequency.weekly) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Days',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _WeekdayPicker(
                      selected: _reminderWeekdays,
                      onChanged: (days) {
                        setState(() {
                          _reminderWeekdays = days;
                          _reminderValidationError = null;
                        });
                      },
                    ),
                  ],
                  if (_reminderFrequency == ReminderFrequency.monthly) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Day',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DayOfMonthPicker(
                      day: _reminderDayOfMonth,
                      onChanged: (day) {
                        setState(() {
                          _reminderDayOfMonth = day;
                          _reminderValidationError = null;
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Time',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('reminder-recurring-time-button'),
                    onPressed: _pickRecurringTime,
                    icon: const Icon(Icons.access_time_outlined, size: 18),
                    label: Text(_reminderRecurringTime.format(context)),
                  ),
                ],
                if (_reminderValidationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _reminderValidationError!,
                    key: const Key('reminder-validation-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
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
