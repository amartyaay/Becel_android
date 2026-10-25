import 'dart:math' as math;

import 'energy.dart';
import 'estimates.dart';
import 'heart_signal.dart';
import 'sleep_coach.dart';
import 'strain.dart';
import 'strength.dart';

/// Several physiological signals moving the wrong way at once.
///
/// One signal off is noise; RHR up with HRV down, or with a respiratory or
/// skin-temperature rise, is a common pattern before illness, after heavy
/// alcohol, in heat, or with accumulated fatigue. Becel names the signals,
/// not a cause.
class BodyAlert {
  const BodyAlert({required this.signals});

  final List<String> signals;

  String get title => 'Your body is under extra strain';
  String get detail =>
      '${signals.join(' · ')}. Common causes: oncoming illness, alcohol, '
      'heat, travel, or accumulated fatigue. Keep today easy and recheck '
      'tomorrow.';
}

BodyAlert? detectBodyAlert({
  required RecoveryEstimate? recovery,
  double? respiratoryDelta,
  double? skinTempDelta,
}) {
  final signals = <String>[];
  var rhrUp = false;
  if (recovery != null) {
    if (recovery.restingHrChange >= 5 || recovery.restingHrZ >= 2) {
      rhrUp = true;
      signals.add('Resting HR +${recovery.restingHrChange.round()} bpm');
    }
    if (recovery.hrvZ <= -1.5) {
      signals.add('HRV ${recovery.hrvChangePercent.round()}% vs baseline');
    }
  }
  if (respiratoryDelta != null && respiratoryDelta >= 1.0) {
    signals.add('Breathing +${respiratoryDelta.toStringAsFixed(1)}/min');
  }
  if (skinTempDelta != null && skinTempDelta >= 0.5) {
    signals.add('Skin temp +${skinTempDelta.toStringAsFixed(1)} °C');
  }
  final triggered = (rhrUp && signals.length >= 2) || signals.length >= 3;
  return triggered ? BodyAlert(signals: signals) : null;
}

enum PlanTone { push, train, recover, rest }

enum PlanKind { cardio, lift, mobility }

/// One concrete thing to do today.
class PlanItem {
  const PlanItem.cardio(this.label) : kind = PlanKind.cardio;
  const PlanItem.lift(this.label) : kind = PlanKind.lift;
  const PlanItem.mobility(this.label) : kind = PlanKind.mobility;

  final PlanKind kind;
  final String label;
}

class DailyPlan {
  const DailyPlan({
    required this.tone,
    required this.headline,
    required this.session,
    required this.target,
    required this.notes,
    this.prescription = const [],
  });

  final PlanTone tone;
  final String headline;

  /// What to do in the gym or on the road today, in one sentence.
  final String session;
  final StrainTarget target;

  /// At most three short, specific notes. No filler.
  final List<String> notes;

  /// Concrete sessions for today, with heart-rate ranges from the user's
  /// own zones when known (e.g. "45–60 min Z2 · 128–141 bpm").
  final List<PlanItem> prescription;
}

DailyPlan buildDailyPlan({
  required RecoveryEstimate? recovery,
  required TrainingLoad? load,
  required SleepCoach sleep,
  required BodyAlert? alert,
  required List<MuscleVolume> muscleVolume,
  required bool logsStrength,
  required DateTime now,
  double? ambientTrimp,
  HrvTrend? hrvTrend,
  HeartZones? zones,
  bool zonesApproximate = false,
  double? strainToday,
  double? yesterdayTrainingStrain,
}) {
  final score = recovery?.score;
  // A 7-day HRV average below the normal range means accumulated fatigue
  // that one good night does not undo (Plews 2013; Buchheit 2014): cap the
  // day at yellow.
  final trendLow = hrvTrend?.state == HrvTrendState.below;
  final nightBand = recovery?.trainingBand;
  final trainingBand = trendLow && nightBand == RecoveryBand.green
      ? RecoveryBand.yellow
      : nightBand;
  // The prescription follows the evidence band, not the raw %.
  final bandScore = switch (trainingBand) {
    RecoveryBand.green => 80,
    RecoveryBand.yellow => 50,
    RecoveryBand.red => 20,
    null => null,
  };
  var target = strainTarget(
    recovery: bandScore,
    load: load,
    ambient: ambientTrimp,
  );
  final notes = <String>[];

  PlanTone tone;
  String headline;
  String session;
  if (alert != null) {
    tone = PlanTone.rest;
    headline = 'Back off today';
    session = 'Walk, mobility, or full rest. Skip intervals and top sets.';
    target = const StrainTarget(
      low: 0,
      high: 8,
      label: 'Rest',
      reason: 'Multiple signals suggest your body is fighting something.',
    );
  } else if (score == null) {
    tone = PlanTone.train;
    headline = 'Train by feel';
    session =
        'Recovery is calibrating. Keep hard work to RPE 7–8 until it is ready.';
  } else if (trainingBand == RecoveryBand.green &&
      (yesterdayTrainingStrain ?? 0) >= 14) {
    // Hard days need a day between them (polarised training); a green
    // morning after a strain-14+ day trains, but not at intervals again.
    tone = PlanTone.train;
    headline = 'Recovered, but yesterday was hard';
    session = 'Steady Z2 or a moderate lift. Save intervals for tomorrow.';
    notes.add(
      'Yesterday reached strain ${yesterdayTrainingStrain!.toStringAsFixed(1)}: '
      'space hard days.',
    );
  } else if (trainingBand == RecoveryBand.green) {
    tone = PlanTone.push;
    headline = 'Green light: go hard';
    session =
        'Good day for intervals, a tempo run, or heavy compound lifts near '
        'RPE 8–9.';
  } else if (trainingBand == RecoveryBand.yellow) {
    tone = PlanTone.train;
    headline = 'Train, but control intensity';
    session =
        'Z2 cardio or technique-focused lifting at RPE 7 or below. Save max efforts.';
  } else {
    tone = PlanTone.recover;
    headline = 'Recovery day';
    session = 'Z1 walk, easy spin, or mobility. Protect tonight’s sleep.';
  }

  if (trendLow && alert == null) {
    notes.add(
      'Your 7-day HRV is below its normal range'
      '${nightBand == RecoveryBand.green ? ', so today is capped at controlled training despite a good night' : ''}.',
    );
  }

  if (load != null && load.status == LoadStatus.spike) {
    notes.add(
      'Load spike: this week is ${((load.acwr! - 1) * 100).round()}% above '
      'your 4-week base.',
    );
  } else if (load?.monotony != null && load!.monotony! > 2) {
    notes.add(
      'Training is monotonous (${load.monotony!.toStringAsFixed(1)}). Make '
      'hard days harder and easy days easier.',
    );
  }

  final bedtime = sleep.recommendedBedtime;
  if (bedtime != null) {
    final debt = sleep.debtNeed > 0 ? ' incl. ${sleep.debtNeed} min debt' : '';
    notes.add(
      'Bed by ${_clock(bedtime)} for ${_duration(sleep.needTonight)} of '
      'sleep$debt.',
    );
  }

  if (logsStrength && tone != PlanTone.rest) {
    final trained = muscleVolume.where((m) => m.sets > 0).toList();
    final lagging = [
      for (final muscle in muscleVolume)
        if (muscle.muscle != Muscle.core && muscle.sets < 10) muscle,
    ]..sort((a, b) => a.sets.compareTo(b.sets));
    if (trained.isNotEmpty && lagging.isNotEmpty) {
      final names = lagging.take(2).map((m) => m.muscle.label).join(' and ');
      notes.add(
        '$names under 10 hard sets this week. Prioritise them next session.',
      );
    }
  }

  // With an age-predicted max HR (±10 bpm) the ranges are approximate.
  final approx = zonesApproximate ? '~' : '';
  String range(double from, double to) => zones == null
      ? ''
      : ' · $approx${zones.bpmAt(from)}–${zones.bpmAt(to)} bpm';
  final prescription = switch (tone) {
    PlanTone.push => [
      PlanItem.cardio('Intervals 4–6 × 4 min Z4${range(0.8, 0.9)}'),
      const PlanItem.lift('Heavy compounds · RPE 8–9'),
    ],
    PlanTone.train => [
      // Easy aerobic work sits below the first ventilatory threshold;
      // 55–65 % HRR keeps most people there.
      PlanItem.cardio('45–60 min Z2${range(0.55, 0.65)}'),
      const PlanItem.lift('Lift · RPE 7 or below'),
    ],
    PlanTone.recover => [
      PlanItem.cardio(
        '20–40 min Z1${zones == null ? '' : ' · under $approx${zones.bpmAt(0.55)} bpm'}',
      ),
      const PlanItem.mobility('Mobility 10–15 min'),
    ],
    PlanTone.rest => [const PlanItem.mobility('Walk or full rest')],
  };

  // Timing: hard work ending within ~1 h of bed delays sleep (Stutz et al.,
  // 2019), and once today's target is met the job is done.
  final windDown =
      bedtime != null &&
      now.isAfter(bedtime.subtract(const Duration(minutes: 150))) &&
      now.isBefore(bedtime.add(const Duration(hours: 3)));
  // On recover/rest days the band is a ceiling, not a goal.
  final targetMet =
      (tone == PlanTone.push || tone == PlanTone.train) &&
      strainToday != null &&
      strainToday >= target.low;
  var finalHeadline = headline;
  var finalPrescription = prescription;
  if (alert == null && targetMet) {
    finalHeadline = 'Target reached';
    finalPrescription = [
      const PlanItem.mobility('Done for today · easy walk or stretch'),
    ];
  } else if (alert == null && windDown) {
    finalHeadline = 'Wind down';
    finalPrescription = [
      const PlanItem.mobility('Easy walk or stretch only'),
      PlanItem.mobility('Bed by ${_clock(bedtime)}'),
    ];
  }

  return DailyPlan(
    tone: tone,
    headline: finalHeadline,
    session: session,
    target: target,
    notes: notes.take(3).toList(),
    prescription: finalPrescription,
  );
}

/// What Becel would change next week, chosen from the weakest link.
class WeeklyFocus {
  const WeeklyFocus({required this.title, required this.body});

  final String title;
  final String body;
}

class WeeklyReview {
  const WeeklyReview({
    required this.start,
    required this.end,
    required this.averageRecovery,
    required this.recoveryDays,
    required this.strainByDay,
    required this.load,
    required this.averageSleep,
    required this.sleepConsistency,
    required this.sleepDebt,
    required this.strengthSessions,
    required this.strengthMinutes,
    required this.adjustedSteps,
    required this.filteredSteps,
    required this.averageKcal,
    required this.focus,
  });

  final DateTime start;
  final DateTime end;
  final int? averageRecovery;
  final int recoveryDays;
  final List<DayStrain> strainByDay;
  final TrainingLoad? load;
  final int? averageSleep;
  final int? sleepConsistency;
  final int sleepDebt;
  final int strengthSessions;
  final int strengthMinutes;
  final int? adjustedSteps;
  final int? filteredSteps;
  final int? averageKcal;
  final WeeklyFocus focus;

  double get averageStrain => strainByDay.isEmpty
      ? 0
      : strainByDay.fold<double>(0, (s, d) => s + d.strain) /
            strainByDay.length;
}

WeeklyReview buildWeeklyReview({
  required List<RecoveryHistoryPoint> recoveryHistory,
  required List<DayStrain> strainDays,
  required TrainingLoad? load,
  required SleepCoach sleep,
  required List<StrengthSession> strengthSessions,
  required List<DayEnergy> energyDays,
  required DateTime now,
}) {
  final end = DateTime(now.year, now.month, now.day);
  final start = end.subtract(const Duration(days: 6));
  final scores = [
    for (final point in recoveryHistory)
      if (!point.date.isBefore(start) && point.readiness?.estimate != null)
        point.readiness!.estimate!.score,
  ];
  final week = [
    for (final day in strainDays)
      if (!day.date.isBefore(start)) day,
  ];
  final sessions = [
    for (final session in strengthSessions)
      if (!session.start.isBefore(start)) session,
  ];
  final weekEnergy = [
    for (final day in energyDays)
      if (!day.date.isBefore(start)) day,
  ];
  final counted = weekEnergy.fold<int>(0, (s, d) => s + d.countedSteps);
  final filtered = weekEnergy.fold<int>(0, (s, d) => s + d.filteredSteps);
  final complete = weekEnergy.where((d) => d.complete).toList();

  final averageRecovery = scores.isEmpty
      ? null
      : (scores.reduce((a, b) => a + b) / scores.length).round();
  final focus = _weeklyFocus(
    averageRecovery: averageRecovery,
    load: load,
    sleep: sleep,
    sessions: sessions,
  );

  return WeeklyReview(
    start: start,
    end: end,
    averageRecovery: averageRecovery,
    recoveryDays: scores.length,
    strainByDay: week,
    load: load,
    averageSleep: sleep.averageAsleep,
    sleepConsistency: sleep.consistencyPercent,
    sleepDebt: sleep.debtMinutes,
    strengthSessions: sessions.length,
    strengthMinutes: sessions.fold(0, (s, x) => s + x.durationMinutes),
    adjustedSteps: weekEnergy.isEmpty ? null : counted,
    filteredSteps: weekEnergy.isEmpty ? null : filtered,
    averageKcal: complete.isEmpty
        ? null
        : (complete.fold<double>(0, (s, d) => s + d.totalKcal) /
                  complete.length)
              .round(),
    focus: focus,
  );
}

WeeklyFocus _weeklyFocus({
  required int? averageRecovery,
  required TrainingLoad? load,
  required SleepCoach sleep,
  required List<StrengthSession> sessions,
}) {
  final status = load?.status;
  if (status == LoadStatus.spike || status == LoadStatus.overreaching) {
    return const WeeklyFocus(
      title: 'Absorb the load',
      body:
          'Acute load is well above your 4-week base. Keep volume, drop '
          'intensity on two sessions, and let recovery catch up.',
    );
  }
  final average = sleep.averageAsleep;
  if (average != null && average < sleep.baselineNeed - 45) {
    return WeeklyFocus(
      title: 'Close the sleep gap',
      body:
          'You averaged ${_duration(average)} against a ${_duration(sleep.baselineNeed)} '
          'need. Sleep is the cheapest performance gain: move bedtime 30 min '
          'earlier on training nights.',
    );
  }
  if (sleep.midpointSdMinutes != null && sleep.midpointSdMinutes! > 45) {
    return WeeklyFocus(
      title: 'Anchor your sleep timing',
      body:
          'Your sleep midpoint moved ±${sleep.midpointSdMinutes} min. Irregular '
          'timing blunts HRV recovery even when total sleep is fine. Fix wake '
          'time first.',
    );
  }
  if (averageRecovery != null && averageRecovery < 45) {
    return const WeeklyFocus(
      title: 'Recovery is lagging',
      body:
          'Average recovery stayed yellow-to-red. Swap one hard session for Z2 '
          'and keep alcohol and late meals away from training nights.',
    );
  }
  if (status == LoadStatus.detraining) {
    return const WeeklyFocus(
      title: 'Room to build',
      body:
          'Load is under your recent base and recovery is holding. Add one '
          'session or 10–15% volume.',
    );
  }
  if (sessions.isEmpty) {
    return const WeeklyFocus(
      title: 'Add two strength sessions',
      body:
          'No strength workouts synced this week. Two sessions of compound '
          'lifts protect muscle and bone alongside cardio. Start them as a '
          'workout on your Fitbit Air or in Google Health so Becel can count '
          'them.',
    );
  }
  return const WeeklyFocus(
    title: 'Hold the line',
    body:
        'Load, sleep, and recovery are balanced. Repeat the week, adding '
        'about 5–10% more training time or one harder session.',
  );
}

/// Plain-language weekly summary that can be shared without a server.
String weeklySummaryText(WeeklyReview review) {
  final buffer = StringBuffer()
    ..writeln(
      'Becel week · ${_shortDate(review.start)}–${_shortDate(review.end)}',
    )
    ..writeln(
      'Recovery: ${review.averageRecovery == null ? '—' : '${review.averageRecovery}% avg'} '
      '(${review.recoveryDays} days)',
    )
    ..writeln(
      'Strain: ${review.averageStrain.toStringAsFixed(1)} avg/day · load '
      '${review.load?.status.label ?? '—'}'
      '${review.load?.acwr == null ? '' : ' (ACWR ${review.load!.acwr!.toStringAsFixed(2)})'}',
    )
    ..writeln(
      'Sleep: ${review.averageSleep == null ? '—' : _duration(review.averageSleep!)} avg'
      '${review.sleepConsistency == null ? '' : ' · ${review.sleepConsistency}% consistent'}',
    )
    ..writeln(
      'Strength: ${review.strengthSessions} sessions · ${review.strengthMinutes} min',
    );
  if (review.averageKcal != null) {
    buffer.writeln('Energy: ~${review.averageKcal} kcal/day (Becel estimate)');
  }
  buffer
    ..writeln()
    ..writeln('Focus: ${review.focus.title}. ${review.focus.body}');
  return buffer.toString();
}

/// CSV of the week's daily values with provenance columns.
String weeklyCsv({
  required WeeklyReview review,
  required List<RecoveryHistoryPoint> recoveryHistory,
  required List<DayEnergy> energyDays,
  required DateTime now,
}) {
  final rows = <List<String>>[
    [
      'date',
      'recovery_pct',
      'strain_0_21',
      'trimp',
      'strength_trimp',
      'hr_coverage_min',
      'sleep_asleep_min',
      'kcal_total_becel',
      'steps_counted',
      'steps_filtered',
    ],
  ];
  for (final day in review.strainByDay) {
    final key = _dateKey(day.date);
    RecoveryHistoryPoint? point;
    for (final p in recoveryHistory) {
      if (_dateKey(p.date) == key) point = p;
    }
    DayEnergy? energy;
    for (final e in energyDays) {
      if (_dateKey(e.date) == key) energy = e;
    }
    rows.add([
      key,
      point?.readiness?.estimate?.score.toString() ?? '',
      day.hasData ? day.strain.toStringAsFixed(1) : '',
      day.trimp.toStringAsFixed(1),
      day.strengthTrimp.toStringAsFixed(1),
      day.coverageMinutes.round().toString(),
      point?.sleepMinutes?.toString() ?? '',
      energy?.totalKcal.round().toString() ?? '',
      energy?.countedSteps.toString() ?? '',
      energy?.filteredSteps.toString() ?? '',
    ]);
  }
  rows.add([
    '# exported ${now.toIso8601String()} · source: Fitbit Air via Health Connect; values computed on device by Becel',
  ]);
  return rows.map(_csvRow).join('\n');
}

String _csvRow(List<String> values) =>
    values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');

String _dateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _clock(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final suffix = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:${local.minute.toString().padLeft(2, '0')} $suffix';
}

String _duration(int minutes) {
  final value = minutes.abs();
  if (value < 60) return '${value}m';
  final hours = value ~/ 60;
  final remainder = value % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String _shortDate(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = time.toLocal();
  return '${local.day} ${months[local.month - 1]}';
}

int maxInt(int a, int b) => math.max(a, b);
