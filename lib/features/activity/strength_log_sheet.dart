import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../data/local_store.dart';
import '../../domain/strength.dart';
import '../../widgets/format.dart';

/// Opens the session logger. Returns true when a session was saved.
Future<bool> showStrengthLogSheet(
  BuildContext context, {
  StrengthSession? existing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (context) => StrengthLogSheet(existing: existing),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session logged. Strain and load updated.')),
    );
  }
  return saved ?? false;
}

class StrengthLogSheet extends StatefulWidget {
  const StrengthLogSheet({super.key, this.existing});

  final StrengthSession? existing;

  @override
  State<StrengthLogSheet> createState() => _StrengthLogSheetState();
}

class _SetDraft {
  _SetDraft({String reps = '', String load = '', this.rpe})
    : reps = TextEditingController(text: reps),
      load = TextEditingController(text: load);

  final TextEditingController reps;
  final TextEditingController load;
  double? rpe;

  void dispose() {
    reps.dispose();
    load.dispose();
  }
}

class _ExerciseDraft {
  _ExerciseDraft(this.exercise, this.sets);

  final Exercise exercise;
  final List<_SetDraft> sets;
}

class _StrengthLogSheetState extends State<StrengthLogSheet> {
  late DateTime _start;
  late int _minutes;
  late double _rpe;
  final _exercises = <_ExerciseDraft>[];
  bool _saving = false;

  static const _rpeWords = {
    3: 'Easy',
    5: 'Moderate',
    7: 'Hard',
    8: 'Very hard',
    9: 'Near max',
    10: 'Max',
  };

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _minutes = existing?.durationMinutes ?? 60;
    _rpe = existing?.sessionRpe ?? 7;
    _start =
        existing?.start ?? DateTime.now().subtract(Duration(minutes: _minutes));
    for (final entry in existing?.exercises ?? const <ExerciseEntry>[]) {
      final exercise = entry.exercise;
      if (exercise == null) continue;
      _exercises.add(
        _ExerciseDraft(exercise, [
          for (final set in entry.sets)
            _SetDraft(
              reps: '${set.reps}',
              load: set.loadKg == null ? '' : _trim(set.loadKg!),
              rpe: set.rpe,
            ),
        ]),
      );
    }
  }

  @override
  void dispose() {
    for (final exercise in _exercises) {
      for (final set in exercise.sets) {
        set.dispose();
      }
    }
    super.dispose();
  }

  String _trim(double value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  Future<void> _pickExercise() async {
    final picked = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      builder: (context) => const _ExercisePicker(),
    );
    if (picked == null) return;
    setState(() => _exercises.add(_ExerciseDraft(picked, [_SetDraft(rpe: 8)])));
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = StrengthSession(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      start: _start,
      durationMinutes: _minutes,
      sessionRpe: _rpe,
      exercises: [
        for (final draft in _exercises)
          ExerciseEntry(
            exerciseId: draft.exercise.id,
            sets: [
              for (final set in draft.sets)
                if ((int.tryParse(set.reps.text) ?? 0) > 0)
                  StrengthSet(
                    reps: int.parse(set.reps.text),
                    loadKg: double.tryParse(set.load.text),
                    rpe: set.rpe,
                  ),
            ],
          ),
      ],
    );
    final saved = await LocalStore.instance.saveStrengthSession(session);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged for this session only — storage failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final load = (_rpe * _minutes).round();
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigher,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null
                  ? 'Log a strength session'
                  : 'Edit session',
              style: AppType.sectionTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 4),
            const Text(
              'Heart rate under-reads lifting. Session RPE × minutes adds the '
              'missing muscular load to strain. Sets are optional.',
              style: AppType.caption,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _FieldBox(
                    label: 'STARTED',
                    child: InkWell(
                      onTap: _pickTime,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '${formatDayShort(_start)} ${formatClock(_start)}',
                          style: AppType.numS.copyWith(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FieldBox(
                    label: 'DURATION',
                    child: Row(
                      children: [
                        _Step(
                          icon: Icons.remove_rounded,
                          onTap: () => setState(
                            () => _minutes = (_minutes - 5).clamp(5, 240),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '$_minutes min',
                            textAlign: TextAlign.center,
                            style: AppType.numS.copyWith(fontSize: 16),
                          ),
                        ),
                        _Step(
                          icon: Icons.add_rounded,
                          onTap: () => setState(
                            () => _minutes = (_minutes + 5).clamp(5, 240),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('SESSION RPE', style: AppType.eyebrow),
                const Spacer(),
                Text(
                  '${_rpe.round()} · ${_rpeWords.entries.lastWhere((e) => e.key <= _rpe, orElse: () => _rpeWords.entries.first).value} · $load AU',
                  style: AppType.caption.copyWith(
                    color: AppColors.orange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Slider(
              value: _rpe,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.orange,
              label: '${_rpe.round()}',
              onChanged: (value) => setState(() => _rpe = value),
            ),
            const Text(
              'How hard was the whole session, rated ~30 min after (Foster CR-10).',
              style: AppType.caption,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('EXERCISES', style: AppType.eyebrow),
                const Spacer(),
                Text(
                  _exercises.isEmpty ? 'optional' : '${_exercises.length}',
                  style: AppType.caption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _exercises.length; index++)
              _ExerciseCard(
                draft: _exercises[index],
                onChanged: () => setState(() {}),
                onRemove: () => setState(() {
                  for (final set in _exercises[index].sets) {
                    set.dispose();
                  }
                  _exercises.removeAt(index);
                }),
              ),
            SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _pickExercise,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add exercise'),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: AppColors.bg,
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(_saving ? 'Saving…' : 'Save session'),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stored on this phone only. Not written to Health Connect.',
              textAlign: TextAlign.center,
              style: AppType.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.eyebrow.copyWith(fontSize: 10)),
        child,
      ],
    ),
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: onTap,
    radius: 22,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 18, color: AppColors.textSecondary),
    ),
  );
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _ExerciseDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final muscles = [...draft.exercise.primary.map((m) => m.label)].join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.exercise.name, style: AppType.rowTitle),
                    Text(
                      muscles,
                      style: AppType.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove exercise',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 26),
              Expanded(
                child: Text(
                  'REPS',
                  style: AppType.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'KG',
                  style: AppType.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'RPE',
                  style: AppType.eyebrow.copyWith(fontSize: 9.5),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
          for (var index = 0; index < draft.sets.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${index + 1}',
                      style: AppType.caption.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: draft.sets[index].reps,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(hintText: '8'),
                      style: AppType.numS.copyWith(fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: draft.sets[index].load,
                      enabled: !draft.exercise.bodyweight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        hintText: draft.exercise.bodyweight ? 'BW' : '60',
                      ),
                      style: AppType.numS.copyWith(fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: draft.sets[index].rpe,
                      isDense: true,
                      items: [
                        for (final value in [6.0, 7.0, 8.0, 9.0, 10.0])
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.round().toString()),
                          ),
                      ],
                      onChanged: (value) {
                        draft.sets[index].rpe = value;
                        onChanged();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      tooltip: 'Remove set',
                      onPressed: draft.sets.length == 1
                          ? null
                          : () {
                              draft.sets.removeAt(index).dispose();
                              onChanged();
                            },
                      icon: const Icon(
                        Icons.remove_circle_outline_rounded,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final last = draft.sets.last;
                draft.sets.add(
                  _SetDraft(
                    reps: last.reps.text,
                    load: last.load.text,
                    rpe: last.rpe,
                  ),
                );
                onChanged();
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add set'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final exercise in exerciseCatalog)
        if (exercise.name.toLowerCase().contains(_query.toLowerCase()) ||
            exercise.primary.any(
              (m) => m.label.toLowerCase().contains(_query.toLowerCase()),
            ))
          exercise,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search exercise or muscle',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final exercise = matches[index];
                return ListTile(
                  title: Text(exercise.name),
                  subtitle: Text(
                    exercise.primary.map((m) => m.label).join(', '),
                    style: AppType.caption,
                  ),
                  onTap: () => Navigator.of(context).pop(exercise),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
