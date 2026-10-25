import 'dart:math' as math;

import 'estimates.dart';
import 'profile.dart';
import 'strength.dart';

/// A five-minute step bucket from Health Connect step records.
class StepBucket {
  const StepBucket({required this.start, required this.steps});

  final DateTime start;
  final int steps;
}

/// Steps in a 5-minute bucket below this are treated as incidental (arm
/// swings, typing, fidgeting) unless heart rate confirms movement. Real
/// walking runs at ~100 steps/min, so even one minute of it clears 120.
const ambulatoryBucketSteps = 120;

/// Mid-range buckets count only when bucket HR is this far above resting.
const confirmedBucketSteps = 40;
const confirmedBucketHrRise = 15.0;

/// Net metabolic cost of level walking, kcal per kg per km (≈0.5; Margaria;
/// van der Walt & Wyndham). Net = above resting, so it never double-counts RMR.
const walkingNetKcalPerKgKm = 0.5;

/// Awake, non-walking minutes (sitting, standing, fidgeting, chores the
/// band cannot classify) cost ~1.3× resting. Doubly labelled water studies
/// put even sedentary adults at PAL ≥ 1.4, which this allowance plus RMR and
/// TEF reproduces on a rest day. Under-counting here risks under-fuelling.
const awakeAllowance = 0.30;

/// Thermic effect of food: ~10 % of energy eaten (Westerterp 2004).
const tefFractionOfIntake = 0.10;

/// TEF when food is not (fully) logged: ~8 % of expenditure. Together with
/// the allowance this keeps a light, ambulatory day near PAL 1.35–1.45,
/// the floor seen in doubly labelled water studies of free-living adults
/// (Black et al., 1996). Earlier, lower constants produced PAL ~1.25,
/// which only chair-bound subjects reach.
const tefFractionOfExpenditure = 0.08;

class DayEnergy {
  const DayEnergy({
    required this.date,
    required this.restingKcal,
    required this.heartKcal,
    required this.stepKcal,
    required this.strengthKcal,
    required this.awakeKcal,
    required this.countedSteps,
    required this.filteredSteps,
    required this.flexBpm,
    required this.heartMinutes,
    required this.minutesElapsed,
    required this.complete,
    required this.rmrMethod,
    this.intakeKcal,
  });

  final DateTime date;
  final double restingKcal;
  final double heartKcal;
  final double stepKcal;
  final double strengthKcal;
  final double awakeKcal;
  final int countedSteps;
  final int filteredSteps;
  final int flexBpm;
  final int heartMinutes;
  final int minutesElapsed;
  final bool complete;
  final String rmrMethod;

  /// Food logged for this date, if any (drives the TEF estimate).
  final double? intakeKcal;

  double get _movementKcal => heartKcal + stepKcal + strengthKcal + awakeKcal;

  /// Thermic effect of food. Logged intake can only raise it: a partial
  /// food log must never make the day's burn smaller.
  double get tefKcal {
    final fallback =
        (restingKcal + _movementKcal) *
        tefFractionOfExpenditure /
        (1 - tefFractionOfExpenditure);
    final fromIntake = (intakeKcal ?? 0) * tefFractionOfIntake;
    return math.max(fallback, fromIntake);
  }

  bool get tefFromIntake =>
      intakeKcal != null &&
      intakeKcal! * tefFractionOfIntake > 0 &&
      intakeKcal! * tefFractionOfIntake >=
          (restingKcal + _movementKcal) *
              tefFractionOfExpenditure /
              (1 - tefFractionOfExpenditure);

  double get activeKcal => _movementKcal + tefKcal;
  double get totalKcal => restingKcal + activeKcal;

  /// Physical activity level (TDEE ÷ RMR), complete days only. Healthy
  /// adults sit at ~1.4–2.5; values outside suggest missing wear or data.
  double? get pal =>
      complete && restingKcal > 0 ? totalKcal / restingKcal : null;
  bool get palPlausible => pal == null || (pal! >= 1.35 && pal! <= 2.6);

  /// Plain ± error budget: RMR equations ~8 %, HR-derived energy ~25 %,
  /// step energy ~20 %, MET-based lifting ~25 %, allowance and TEF ~40 %.
  double get uncertaintyKcal =>
      0.08 * restingKcal +
      0.25 * heartKcal +
      0.20 * stepKcal +
      0.25 * strengthKcal +
      0.40 * (awakeKcal + tefKcal);

  /// Today only: the remaining hours at resting plus a typical evening
  /// (part awake, part asleep), plus TEF on that remainder.
  double projectedTotalKcal(double rmrPerDay) {
    if (complete) return totalKcal;
    final remaining = math.max(0, 1440 - minutesElapsed);
    final rest = remaining * rmrPerDay / 1440 * (1 + awakeAllowance / 2);
    return totalKcal + rest / (1 - tefFractionOfExpenditure);
  }
}

double restingMetabolicRate(BodyProfile profile) {
  final lean = profile.leanMassKg;
  if (lean != null) return 370 + 21.6 * lean; // Katch–McArdle
  final base =
      10 * profile.weightKg! + 6.25 * profile.heightCm! - 5 * profile.age!;
  return profile.sex == BiologicalSex.male
      ? base + 5
      : base - 161; // Mifflin–St Jeor
}

String rmrMethodLabel(BodyProfile profile) => profile.leanMassKg != null
    ? 'Katch–McArdle (lean mass ${profile.leanMassKg!.toStringAsFixed(0)} kg)'
    : 'Mifflin–St Jeor';

/// The heart-rate point above which pulse tracks energy expenditure
/// (FLEX-HR, Spurr et al. 1988). Below it, HR is driven by posture,
/// caffeine, stress, and digestion, and HR equations overestimate.
int flexHeartRate({required double restingBpm, required int maxBpm}) {
  final reserve = math.max(20, maxBpm - restingBpm);
  return math
      .max(85, math.max(restingBpm + 25, restingBpm + 0.3 * reserve))
      .round();
}

/// Keytel et al. (2005) gross energy, kcal/min, without VO₂max.
double keytelKcalPerMinute(double bpm, BodyProfile profile) {
  final w = profile.weightKg!;
  final a = profile.age!.toDouble();
  final kj = profile.sex == BiologicalSex.male
      ? -55.0969 + 0.6309 * bpm + 0.1988 * w + 0.2017 * a
      : -20.4022 + 0.4472 * bpm - 0.1263 * w + 0.074 * a;
  return math.max(0, kj / 4.184);
}

/// Per-minute energy fusion for one local date.
///
/// Each awake minute takes exactly one active-energy source, in order:
/// logged strength session (Compendium MET) → HR above FLEX (Keytel net of
/// RMR) → ambulatory steps (net walking cost) → awake allowance. Sleeping
/// minutes add nothing above RMR. No minute is counted twice.
DayEnergy? estimateDayEnergy({
  required BodyProfile profile,
  required DateTime date,
  required DateTime now,
  required List<TimedValue> cleanedMinutes,
  required List<StepBucket> stepBuckets,
  required List<AsleepInterval> sleep,
  required double restingBpm,
  required int maxBpm,
  Iterable<StrengthSession> strengthSessions = const [],
  Iterable<({DateTime start, DateTime end})> workoutWindows = const [],
  double? intakeKcal,
}) {
  if (!profile.hasEnergyInputs) return null;
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = DateTime(date.year, date.month, date.day + 1);
  final end = now.isBefore(dayEnd) ? now : dayEnd;
  if (!end.isAfter(dayStart)) return null;
  final minutes = end.difference(dayStart).inMinutes;
  final rmr = restingMetabolicRate(profile);
  final rmrPerMinute = rmr / 1440;
  final flex = flexHeartRate(restingBpm: restingBpm, maxBpm: maxBpm);
  final weight = profile.weightKg!;
  final stride =
      profile.heightCm! /
      100 *
      (profile.sex == BiologicalSex.male ? 0.415 : 0.413);

  final startMinute = dayStart.millisecondsSinceEpoch ~/ 60000;
  final hrByMinute = <int, double>{};
  for (final sample in cleanedMinutes) {
    final minute = sample.at.millisecondsSinceEpoch ~/ 60000 - startMinute;
    if (minute >= 0 && minute < minutes) hrByMinute[minute] = sample.value;
  }

  final asleep = List<bool>.filled(minutes, false);
  for (final interval in sleep) {
    final from = interval.start.millisecondsSinceEpoch ~/ 60000 - startMinute;
    final to = interval.end.millisecondsSinceEpoch ~/ 60000 - startMinute;
    for (var m = math.max(0, from); m < math.min(minutes, to); m++) {
      asleep[m] = true;
    }
  }

  final strengthMet = List<double>.filled(minutes, 0);
  for (final session in strengthSessions) {
    final from = session.start.millisecondsSinceEpoch ~/ 60000 - startMinute;
    for (
      var m = math.max(0, from);
      m < math.min(minutes, from + session.durationMinutes);
      m++
    ) {
      strengthMet[m] = session.met;
    }
  }

  // Step energy per minute, after the phantom-step filter.
  final stepEnergy = List<double>.filled(minutes, 0);
  var counted = 0;
  var filtered = 0;
  for (final bucket in stepBuckets) {
    final from = bucket.start.millisecondsSinceEpoch ~/ 60000 - startMinute;
    if (from < 0 || from >= minutes || bucket.steps <= 0) continue;
    final to = math.min(minutes, from + 5);
    var hrSum = 0.0;
    var hrCount = 0;
    for (var m = from; m < to; m++) {
      final hr = hrByMinute[m];
      if (hr != null) {
        hrSum += hr;
        hrCount++;
      }
    }
    final bucketHr = hrCount == 0 ? null : hrSum / hrCount;
    final ambulatory =
        bucket.steps >= ambulatoryBucketSteps ||
        (bucket.steps >= confirmedBucketSteps &&
            bucketHr != null &&
            bucketHr >= restingBpm + confirmedBucketHrRise);
    if (!ambulatory) {
      filtered += bucket.steps;
      continue;
    }
    counted += bucket.steps;
    final kcal = bucket.steps * stride / 1000 * weight * walkingNetKcalPerKgKm;
    for (var m = from; m < to; m++) {
      stepEnergy[m] += kcal / (to - from);
    }
  }

  final inWorkout = List<bool>.filled(minutes, false);
  for (final window in workoutWindows) {
    final from = window.start.millisecondsSinceEpoch ~/ 60000 - startMinute;
    final to = window.end.millisecondsSinceEpoch ~/ 60000 - startMinute;
    for (var m = math.max(0, from); m < math.min(minutes, to); m++) {
      inWorkout[m] = true;
    }
  }

  // Length of the consecutive run of minutes at or above FLEX, so a
  // sustained bout can be told apart from a one-minute blip.
  final aboveFlexRun = List<int>.filled(minutes, 0);
  for (var m = 0; m < minutes; m++) {
    final hr = hrByMinute[m];
    if (hr == null || hr < flex) continue;
    var start = m;
    while (start > 0 && (hrByMinute[start - 1] ?? 0) >= flex) {
      start--;
    }
    var end = m;
    while (end < minutes - 1 && (hrByMinute[end + 1] ?? 0) >= flex) {
      end++;
    }
    for (var j = start; j <= end; j++) {
      aboveFlexRun[j] = end - start + 1;
    }
    m = end;
  }

  var heart = 0.0, steps = 0.0, strength = 0.0, awake = 0.0;
  var heartMinutes = 0;
  final reserve = math.max(20.0, maxBpm - restingBpm);
  var lastHardMinute = -1000;
  for (var m = 0; m < minutes; m++) {
    if (strengthMet[m] > 0) {
      // Corrected METs (2024 Compendium): METs are multiples of the
      // person's own resting rate, not the 3.5 ml/kg/min convention, which
      // overstates lifting energy for lean, muscular users.
      strength += (strengthMet[m] - 1) * rmrPerMinute;
      continue;
    }
    if (asleep[m]) continue;
    final hr = hrByMinute[m];
    if (hr != null && hr >= flex) {
      final hrr = (hr - restingBpm) / reserve;
      final keytelNet = math.max(
        0.0,
        keytelKcalPerMinute(hr, profile) - rmrPerMinute,
      );
      if (hrr >= 0.5) {
        // Real exercise: Keytel was derived in this range.
        lastHardMinute = m;
        heart += keytelNet;
        heartMinutes++;
        continue;
      }
      // Between FLEX and 50 % HRR (easy walking, chores, stairs) Keytel
      // overstates cost roughly twice over, so it is damped to half. With
      // steps, the larger of step cost and damped HR is used (stairs and
      // hills cost more than level walking). Without steps, damped HR counts
      // inside a workout, just after a hard bout, or in a sustained bout of
      // 10+ minutes above FLEX (unlogged cycling or rowing); isolated
      // minutes fall through to the daily-living allowance.
      final damped = keytelNet * 0.5;
      if (stepEnergy[m] > 0) {
        if (damped > stepEnergy[m]) {
          heart += damped;
          heartMinutes++;
          continue;
        }
      } else if (inWorkout[m] ||
          m - lastHardMinute <= 10 ||
          aboveFlexRun[m] >= 10) {
        heart += damped;
        heartMinutes++;
        continue;
      }
    }
    if (stepEnergy[m] > 0) {
      steps += stepEnergy[m];
      continue;
    }
    awake += awakeAllowance * rmrPerMinute;
  }

  return DayEnergy(
    date: dayStart,
    restingKcal: rmrPerMinute * minutes,
    heartKcal: heart,
    stepKcal: steps,
    strengthKcal: strength,
    awakeKcal: awake,
    countedSteps: counted,
    filteredSteps: filtered,
    flexBpm: flex,
    heartMinutes: heartMinutes,
    minutesElapsed: minutes,
    complete: !now.isBefore(dayEnd),
    rmrMethod: rmrMethodLabel(profile),
    intakeKcal: intakeKcal,
  );
}

class EnergyBalance {
  const EnergyBalance({
    required this.today,
    required this.history,
    required this.rmr,
    this.deviceTotalToday,
  });

  final DayEnergy today;

  /// Previous complete days with at least 12 h of HR coverage.
  final List<DayEnergy> history;
  final double rmr;
  final int? deviceTotalToday;

  double get projectedToday => today.projectedTotalKcal(rmr);

  /// Average total expenditure on complete, well-covered days: a practical
  /// maintenance-intake starting point.
  double? get maintenanceKcal => history.length < 3
      ? null
      : history.fold<double>(0, (s, d) => s + d.totalKcal) / history.length;

  /// Device total minus Becel so far; positive means the device is higher.
  double? get deviceDelta =>
      deviceTotalToday == null ? null : deviceTotalToday! - today.totalKcal;
}

DateTime localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
