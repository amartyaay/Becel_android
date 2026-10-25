import 'dart:math' as math;

import 'energy.dart';
import 'estimates.dart';
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

class DailyPlan {
  const DailyPlan({
    required this.tone,
    required this.headline,
    required this.session,
    required this.target,
    required this.notes,
  });

  final PlanTone tone;
  final String headline;

  /// What to do in the gym or on the road today, in one sentence.
  final String session;
  final StrainTarget target;

  /// At most three short, specific notes. No filler.
  final List<String> notes;
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

  return DailyPlan(
    tone: tone,
    headline: headline,
    session: session,
    target: target,
    notes: notes.take(3).toList(),
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
