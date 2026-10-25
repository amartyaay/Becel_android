import 'dart:math' as math;

/// Muscle groups used for weekly set-volume tracking.
enum Muscle {
  chest('Chest'),
  back('Back'),
  shoulders('Shoulders'),
  biceps('Biceps'),
  triceps('Triceps'),
  quads('Quads'),
  hamstrings('Hamstrings'),
  glutes('Glutes'),
  calves('Calves'),
  core('Core');

  const Muscle(this.label);
  final String label;
}

class Exercise {
  const Exercise(
    this.id,
    this.name,
    this.primary, [
    this.secondary = const [],
    this.bodyweight = false,
  ]);

  final String id;
  final String name;
  final List<Muscle> primary;
  final List<Muscle> secondary;
  final bool bodyweight;
}

/// Common gym lifts. Primary movers count one set; synergists count half a
/// set, the fractional method used in recent volume–hypertrophy meta-analyses
/// (Pelland et al., 2024).
const exerciseCatalog = <Exercise>[
  Exercise(
    'back_squat',
    'Back squat',
    [Muscle.quads, Muscle.glutes],
    [Muscle.hamstrings, Muscle.core],
  ),
  Exercise(
    'front_squat',
    'Front squat',
    [Muscle.quads],
    [Muscle.glutes, Muscle.core],
  ),
  Exercise('leg_press', 'Leg press', [Muscle.quads], [Muscle.glutes]),
  Exercise(
    'split_squat',
    'Bulgarian split squat',
    [Muscle.quads, Muscle.glutes],
    [Muscle.hamstrings],
  ),
  Exercise(
    'lunge',
    'Walking lunge',
    [Muscle.quads, Muscle.glutes],
    [Muscle.hamstrings],
  ),
  Exercise('leg_extension', 'Leg extension', [Muscle.quads]),
  Exercise(
    'deadlift',
    'Deadlift',
    [Muscle.hamstrings, Muscle.glutes, Muscle.back],
    [Muscle.quads, Muscle.core],
  ),
  Exercise(
    'rdl',
    'Romanian deadlift',
    [Muscle.hamstrings, Muscle.glutes],
    [Muscle.back],
  ),
  Exercise('hip_thrust', 'Hip thrust', [Muscle.glutes], [Muscle.hamstrings]),
  Exercise('leg_curl', 'Leg curl', [Muscle.hamstrings]),
  Exercise('calf_raise', 'Calf raise', [Muscle.calves]),
  Exercise(
    'bench_press',
    'Bench press',
    [Muscle.chest],
    [Muscle.triceps, Muscle.shoulders],
  ),
  Exercise(
    'incline_bench',
    'Incline bench press',
    [Muscle.chest, Muscle.shoulders],
    [Muscle.triceps],
  ),
  Exercise(
    'db_press',
    'Dumbbell press',
    [Muscle.chest],
    [Muscle.triceps, Muscle.shoulders],
  ),
  Exercise(
    'dip',
    'Dip',
    [Muscle.chest, Muscle.triceps],
    [Muscle.shoulders],
    true,
  ),
  Exercise(
    'push_up',
    'Push-up',
    [Muscle.chest],
    [Muscle.triceps, Muscle.shoulders],
    true,
  ),
  Exercise('chest_fly', 'Chest fly', [Muscle.chest]),
  Exercise('ohp', 'Overhead press', [Muscle.shoulders], [Muscle.triceps]),
  Exercise('lateral_raise', 'Lateral raise', [Muscle.shoulders]),
  Exercise('rear_delt', 'Rear-delt fly', [Muscle.shoulders], [Muscle.back]),
  Exercise('pull_up', 'Pull-up', [Muscle.back], [Muscle.biceps], true),
  Exercise('lat_pulldown', 'Lat pulldown', [Muscle.back], [Muscle.biceps]),
  Exercise(
    'barbell_row',
    'Barbell row',
    [Muscle.back],
    [Muscle.biceps, Muscle.shoulders],
  ),
  Exercise('cable_row', 'Seated cable row', [Muscle.back], [Muscle.biceps]),
  Exercise('db_row', 'Dumbbell row', [Muscle.back], [Muscle.biceps]),
  Exercise('face_pull', 'Face pull', [Muscle.shoulders, Muscle.back]),
  Exercise('curl', 'Biceps curl', [Muscle.biceps]),
  Exercise('hammer_curl', 'Hammer curl', [Muscle.biceps]),
  Exercise('triceps_pushdown', 'Triceps pushdown', [Muscle.triceps]),
  Exercise('skull_crusher', 'Skull crusher', [Muscle.triceps]),
  Exercise('plank', 'Plank', [Muscle.core], [], true),
  Exercise('hanging_leg_raise', 'Hanging leg raise', [Muscle.core], [], true),
  Exercise('cable_crunch', 'Cable crunch', [Muscle.core]),
];

Exercise? exerciseById(String id) {
  for (final exercise in exerciseCatalog) {
    if (exercise.id == id) return exercise;
  }
  return null;
}

class StrengthSet {
  const StrengthSet({required this.reps, this.loadKg, this.rpe});

  factory StrengthSet.fromJson(Map<String, dynamic> json) => StrengthSet(
    reps: (json['reps'] as num?)?.toInt() ?? 0,
    loadKg: (json['loadKg'] as num?)?.toDouble(),
    rpe: (json['rpe'] as num?)?.toDouble(),
  );

  final int reps;
  final double? loadKg;

  /// Rate of perceived exertion, 1–10. 10 = no reps left in reserve.
  final double? rpe;

  /// Sets within ~4 reps of failure (RPE ≥ 6) count as hard sets. Sets
  /// without an RPE are assumed to be working sets.
  bool get isHard => reps > 0 && (rpe == null || rpe! >= 6);

  double get volumeKg => (loadKg ?? 0) * reps;

  Map<String, Object?> toJson() => {'reps': reps, 'loadKg': loadKg, 'rpe': rpe};
}

class ExerciseEntry {
  const ExerciseEntry({required this.exerciseId, required this.sets});

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
    exerciseId: json['exerciseId'] as String? ?? '',
    sets: (json['sets'] as List? ?? const [])
        .whereType<Map>()
        .map((set) => StrengthSet.fromJson(Map<String, dynamic>.from(set)))
        .toList(),
  );

  final String exerciseId;
  final List<StrengthSet> sets;

  Exercise? get exercise => exerciseById(exerciseId);

  Map<String, Object?> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets.map((set) => set.toJson()).toList(),
  };
}

class StrengthSession {
  const StrengthSession({
    required this.id,
    required this.start,
    required this.durationMinutes,
    required this.sessionRpe,
    this.exercises = const [],
    this.note,
  });

  factory StrengthSession.fromJson(Map<String, dynamic> json) =>
      StrengthSession(
        id: json['id'] as String? ?? '',
        start:
            DateTime.tryParse(json['start'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        sessionRpe: (json['sessionRpe'] as num?)?.toDouble() ?? 7,
        exercises: (json['exercises'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (entry) =>
                  ExerciseEntry.fromJson(Map<String, dynamic>.from(entry)),
            )
            .toList(),
        note: json['note'] as String?,
      );

  final String id;
  final DateTime start;
  final int durationMinutes;

  /// Foster session RPE (CR-10), asked ~30 min after the session.
  final double sessionRpe;
  final List<ExerciseEntry> exercises;
  final String? note;

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  /// Foster session-RPE load in arbitrary units (RPE × minutes).
  double get srpeLoad => sessionRpe * durationMinutes;

  double get volumeKg => exercises.fold(
    0,
    (sum, entry) => sum + entry.sets.fold(0.0, (s, set) => s + set.volumeKg),
  );

  int get hardSets => exercises.fold(
    0,
    (sum, entry) => sum + entry.sets.where((set) => set.isHard).length,
  );

  /// 2024 Adult Compendium resistance-training METs, which already average
  /// work and rest periods: 3.5 (light), 5.0 (moderate), 6.0 (vigorous).
  double get met => sessionRpe < 5
      ? 3.5
      : sessionRpe < 7
      ? 5.0
      : 6.0;

  Map<String, Object?> toJson() => {
    'id': id,
    'start': start.toIso8601String(),
    'durationMinutes': durationMinutes,
    'sessionRpe': sessionRpe,
    'exercises': exercises.map((entry) => entry.toJson()).toList(),
    'note': note,
  };
}

/// Estimated one-repetition maximum (Epley), adjusted for reps in reserve
/// when RPE is logged. Returns null beyond 12 effective reps, where rep-max
/// equations lose accuracy.
double? estimateOneRepMax({
  required double? loadKg,
  required int reps,
  double? rpe,
}) {
  if (loadKg == null || loadKg <= 0 || reps <= 0) return null;
  final reserve = rpe == null ? 0.0 : (10 - rpe).clamp(0, 5).toDouble();
  final effective = reps + reserve;
  if (effective > 12) return null;
  if (effective <= 1) return loadKg;
  return loadKg * (1 + effective / 30);
}

class MuscleVolume {
  const MuscleVolume(this.muscle, this.sets);

  final Muscle muscle;
  final double sets;

  /// Evidence-based weekly hard-set range for hypertrophy in trained lifters
  /// is roughly 10–20 sets per muscle (Schoenfeld et al., 2017; Pelland et
  /// al., 2024). Below 10 is maintenance territory for most.
  MuscleVolumeStatus get status => sets < 4
      ? MuscleVolumeStatus.minimal
      : sets < 10
      ? MuscleVolumeStatus.maintenance
      : sets <= 20
      ? MuscleVolumeStatus.growth
      : MuscleVolumeStatus.high;
}

enum MuscleVolumeStatus { minimal, maintenance, growth, high }

/// Fractional hard sets per muscle over the last [days] local days.
List<MuscleVolume> weeklyMuscleVolume(
  Iterable<StrengthSession> sessions, {
  required DateTime now,
  int days = 7,
}) {
  final cutoff = now.subtract(Duration(days: days));
  final totals = {for (final muscle in Muscle.values) muscle: 0.0};
  for (final session in sessions) {
    if (session.start.isBefore(cutoff) || session.start.isAfter(now)) continue;
    for (final entry in session.exercises) {
      final exercise = entry.exercise;
      if (exercise == null) continue;
      final hard = entry.sets.where((set) => set.isHard).length;
      for (final muscle in exercise.primary) {
        totals[muscle] = totals[muscle]! + hard;
      }
      for (final muscle in exercise.secondary) {
        totals[muscle] = totals[muscle]! + hard * 0.5;
      }
    }
  }
  return [
    for (final entry in totals.entries) MuscleVolume(entry.key, entry.value),
  ];
}

class LiftBest {
  const LiftBest({
    required this.exercise,
    required this.oneRepMaxKg,
    required this.at,
    required this.previousBestKg,
  });

  final Exercise exercise;
  final double oneRepMaxKg;
  final DateTime at;
  final double? previousBestKg;

  bool get isPersonalRecord =>
      previousBestKg == null || oneRepMaxKg > previousBestKg! + 0.05;

  double? get changeKg =>
      previousBestKg == null ? null : oneRepMaxKg - previousBestKg!;
}

/// Latest best estimated 1RM per exercise, compared with the best before
/// that session. Sorted newest first.
List<LiftBest> liftBests(Iterable<StrengthSession> sessions) {
  final ordered = [...sessions]..sort((a, b) => a.start.compareTo(b.start));
  final best = <String, double>{};
  final latest = <String, LiftBest>{};
  for (final session in ordered) {
    for (final entry in session.exercises) {
      final exercise = entry.exercise;
      if (exercise == null || exercise.bodyweight) continue;
      double? sessionBest;
      for (final set in entry.sets) {
        final e1rm = estimateOneRepMax(
          loadKg: set.loadKg,
          reps: set.reps,
          rpe: set.rpe,
        );
        if (e1rm != null) sessionBest = math.max(sessionBest ?? 0, e1rm);
      }
      if (sessionBest == null) continue;
      latest[exercise.id] = LiftBest(
        exercise: exercise,
        oneRepMaxKg: sessionBest,
        at: session.start,
        previousBestKg: best[exercise.id],
      );
      best[exercise.id] = math.max(best[exercise.id] ?? 0, sessionBest);
    }
  }
  return latest.values.toList()..sort((a, b) => b.at.compareTo(a.at));
}
