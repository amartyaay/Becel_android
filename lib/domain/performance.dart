import 'dart:math' as math;

import '../data/health_connect_service.dart';
import 'coaching.dart';
import 'energy.dart';
import 'estimates.dart';
import 'heart_signal.dart';
import 'profile.dart';
import 'sleep_coach.dart';
import 'strain.dart';
import 'strength.dart';

/// Every Becel-calculated metric for one refresh, derived from one set of
/// inputs so no two screens can disagree.
class Performance {
  const Performance({
    required this.now,
    required this.clean,
    required this.restingBpm,
    required this.maxHr,
    required this.zones,
    required this.strainDays,
    required this.load,
    required this.sleep,
    required this.recovery,
    required this.recoveryHistory,
    required this.respiratoryDelta,
    required this.skinTempDelta,
    required this.alert,
    required this.plan,
    required this.energy,
    required this.energyDays,
    required this.muscleVolume,
    required this.lifts,
    required this.strengthSessions,
    required this.weekly,
    this.hrvTrend,
    this.energyMissing = const [],
    this.energyAsOf,
  });

  /// Inputs still needed before calories burned can be shown.
  final List<String> energyMissing;

  /// Calories burned today are calculated up to this time (last band sync).
  final DateTime? energyAsOf;

  /// Rolling 7-day HRV against the prior 28 days, when enough nights exist.
  final HrvTrend? hrvTrend;

  final DateTime now;
  final CleanHeartRate clean;
  final double? restingBpm;
  final MaxHeartRate? maxHr;
  final HeartZones? zones;

  /// Last 28 local dates, oldest first; empty without HR or age.
  final List<DayStrain> strainDays;
  final TrainingLoad? load;
  final SleepCoach sleep;
  final RecoveryReadiness recovery;
  final List<RecoveryHistoryPoint> recoveryHistory;
  final double? respiratoryDelta;
  final double? skinTempDelta;
  final BodyAlert? alert;
  final DailyPlan plan;
  final EnergyBalance? energy;
  final List<DayEnergy> energyDays;
  final List<MuscleVolume> muscleVolume;
  final List<LiftBest> lifts;
  final List<StrengthSession> strengthSessions;
  final WeeklyReview weekly;

  DayStrain? get today => strainDays.isEmpty ? null : strainDays.last;
  DayStrain? get yesterday =>
      strainDays.length < 2 ? null : strainDays[strainDays.length - 2];
  RecoveryEstimate? get recoveryEstimate => recovery.estimate;
}

Performance buildPerformance({
  required HeartDetail? heart,
  required SleepDetail? sleep,
  required BodyDetail? body,
  required ActivityDetail? activity,
  required BodyProfile? profile,
  required int? fallbackAge,
  required List<StrengthSession> strengthSessions,
  required Map<String, DateTime> onsetOverrides,
  required DateTime now,
}) {
  final age = profile?.age ?? fallbackAge;
  final sex = profile?.sex;
  final rawMinutes = heart == null
      ? const <TimedValue>[]
      : heart.minuteSeries.isNotEmpty
      ? heart.minuteSeries
      : [
          for (final sample in heart.weeklySeries)
            TimedValue(at: sample.at, value: sample.bpm.toDouble()),
        ];
  final stepBuckets = heart?.stepBuckets ?? const <StepBucket>[];
  final clean = excludeCadenceLock(cleanHeartRate(rawMinutes), stepBuckets);
  final sessions = sleep?.sessions ?? const <SleepNight>[];
  final workouts = activity?.workouts ?? const <WorkoutEntry>[];
  final workoutWindows = [
    for (final workout in workouts)
      (
        start: workout.start,
        end: workout.start.add(Duration(minutes: workout.minutes)),
      ),
  ];

  // Resting HR: latest record within 72 h, else the sleeping-HR floor.
  double? resting;
  final restingSamples = [...?heart?.restingHrSamples]
    ..sort((a, b) => a.at.compareTo(b.at));
  for (final sample in restingSamples.reversed) {
    if (now.difference(sample.at) <= const Duration(hours: 72) &&
        sample.value >= 30 &&
        sample.value <= 120) {
      resting = sample.value;
      break;
    }
  }
  if (resting == null && restingSamples.isNotEmpty) {
    resting = medianOf([for (final s in restingSamples) s.value]);
  }

  final maxHr = personalMaxHeartRate(
    age: age,
    tested: profile?.maxHrOverride,
    cleanedMinutes: clean.samples,
  );
  final zones = resting == null || maxHr == null
      ? null
      : HeartZones(restingBpm: resting, maxBpm: maxHr.bpm);

  // Synced lifting carries no RPE (read-only), so estimate it from how much
  // of the session heart rate spent at 50 %+ of reserve.
  final lifts = [
    for (final session in strengthSessions)
      zones == null
          ? session
          : estimateSessionRpe(session, clean.samples, zones),
  ];

  final strainDays = zones == null
      ? const <DayStrain>[]
      : dailyStrain(
          cleanedMinutes: clean.samples,
          restingBpm: zones.restingBpm,
          maxBpm: zones.maxBpm,
          sex: sex,
          now: now,
          days: loadWindowDays,
          strengthSessions: lifts,
          stepBuckets: stepBuckets,
          workoutWindows: workoutWindows,
        );
  final load = strainDays.isEmpty ? null : trainingLoad(strainDays, today: now);
  // Sleep need responds to training, not to a day of walking around.
  final yesterdayStrain = strainDays.length < 2
      ? null
      : strainDays[strainDays.length - 2].trainingStrain;

  final correctOnset = profile?.correctSleepOnset ?? true;
  final hardBpm = zones?.bpmAt(0.6).toDouble();
  final coach = buildSleepCoach(
    sessions: sessions,
    cleanedMinutes: clean.samples,
    now: now,
    yesterdayStrain: yesterdayStrain,
    baselineNeedMinutes: profile?.sleepNeedMinutes,
    userOnsets: onsetOverrides,
    correctOnset: correctOnset,
    hardBpm: hardBpm,
  );
  // Today's score and the history bars use the same onset-corrected
  // windows and the same baseline need, so they stay comparable.
  final adjustedWindows = [
    for (final session in sessions)
      if (session.minutes >= 180)
        () {
          final adjusted = adjustOnset(
            session,
            cleanedMinutes: correctOnset ? clean.samples : const [],
            userOnset: onsetOverrides[sleepKey(session)],
            hardBpm: hardBpm,
          );
          return SleepWindow(
            start: adjusted.onset,
            end: session.end,
            sleepMinutes: adjusted.asleepMinutes,
            asleepIntervals: adjusted.asleepIntervals,
          );
        }(),
  ];

  final respiratoryDelta =
      body?.respiratoryRate != null && body?.respiratoryBaseline != null
      ? body!.respiratoryRate! - body.respiratoryBaseline!
      : null;
  final skinTempDelta = body?.skinTempDeviationC;
  final night = coach.lastNight;
  final recovery = heart == null
      ? const RecoveryReadiness(
          hasSleepSession: false,
          hrvCurrentSampleCount: 0,
          restingHrCurrentSampleCount: 0,
          hrvBaselineNights: 0,
          restingHrBaselineNights: 0,
          limitedSamples: false,
          estimate: null,
        )
      : recoveryReadiness(
          hrvSamples: heart.hrvSamples,
          restingHrSamples: heart.restingHrSamples,
          sleepMinutes: night?.asleepMinutes,
          // Same "need going into last night" the Sleep ring grades against.
          sleepNeedMinutes: coach.needLastNight,
          sleepStart: night?.onset,
          sleepEnd: night?.night.end,
          asleepIntervals: night?.asleepIntervals ?? const <AsleepInterval>[],
          sleepWindows: adjustedWindows,
          respiratoryDelta: respiratoryDelta,
          skinTempDelta: skinTempDelta,
          now: now,
        );
  // Each past night is graded against the need going into it (baseline plus
  // a third of the three earlier nights' shortfall, capped at 60 min), and
  // today uses exactly the ring's need, so today's bar equals the ring.
  final longestByWakeDate = <DateTime, SleepWindow>{};
  for (final window in adjustedWindows) {
    // Sleep times arrive in UTC; key by the local wake date.
    final end = window.end.toLocal();
    final day = DateTime(end.year, end.month, end.day);
    final existing = longestByWakeDate[day];
    if (existing == null || window.sleepMinutes > existing.sleepMinutes) {
      longestByWakeDate[day] = window;
    }
  }
  final todayDate = DateTime(now.year, now.month, now.day);
  int needGoingInto(DateTime date) {
    if (date == todayDate && coach.lastNight != null) {
      return coach.needLastNight;
    }
    final earlier = [
      for (final entry in longestByWakeDate.entries)
        if (entry.key.isBefore(date) &&
            !entry.key.isBefore(date.subtract(const Duration(days: 7))))
          entry,
    ]..sort((a, b) => a.key.compareTo(b.key));
    final lastThree = earlier.length <= 3
        ? earlier
        : earlier.sublist(earlier.length - 3);
    final shortfall = lastThree.fold<int>(
      0,
      (sum, e) => sum + math.max(0, coach.baselineNeed - e.value.sleepMinutes),
    );
    return coach.baselineNeed + math.min(60, (shortfall / 3).round());
  }

  final history = heart == null || sleep == null
      ? const <RecoveryHistoryPoint>[]
      : recoveryHistory(
          hrvSamples: heart.hrvSamples,
          restingHrSamples: heart.restingHrSamples,
          sleepWindows: adjustedWindows,
          now: now,
          sleepNeedMinutes: coach.baselineNeed,
          sleepNeedFor: needGoingInto,
        );
  final trend = heart == null
      ? null
      : hrvTrend(
          hrvSamples: heart.hrvSamples,
          sleepWindows: adjustedWindows,
          now: now,
        );
  final alert = detectBodyAlert(
    recovery: recovery.estimate,
    respiratoryDelta: respiratoryDelta,
    skinTempDelta: skinTempDelta,
  );
  final muscleVolume = weeklyMuscleVolume(lifts, now: now);
  final plan = buildDailyPlan(
    recovery: recovery.estimate,
    load: load,
    sleep: coach,
    alert: alert,
    muscleVolume: muscleVolume,
    logsStrength: lifts.isNotEmpty,
    now: now,
    ambientTrimp: ambientTrimp(strainDays, today: now),
    hrvTrend: trend,
    zones: zones,
    zonesApproximate: maxHr?.source == MaxHrSource.predicted,
    strainToday: strainDays.isEmpty ? null : strainDays.last.strain,
    yesterdayTrainingStrain: strainDays.length < 2
        ? null
        : strainDays[strainDays.length - 2].trainingStrain,
  );

  // Calories burned are shown only when every input is present, and only up
  // to the last minute the band actually synced, so the number never runs
  // ahead of real data.
  final today0 = _day(now);
  TimedValue? lastToday;
  for (final sample in clean.samples.reversed) {
    if (!sample.at.isAfter(now)) {
      if (!sample.at.isBefore(today0)) lastToday = sample;
      break;
    }
  }
  final energyMissing = <String>[
    if (profile?.age == null) 'age',
    if (profile?.sex == null) 'sex',
    if (profile?.weightKg == null) 'weight',
    if (profile?.heightCm == null) 'height',
    if (resting == null) 'resting heart rate',
    if (lastToday == null) 'today’s heart rate',
  ];
  final energyAsOf = lastToday?.at.add(const Duration(minutes: 1));

  // Energy for the last 7 local dates, today last.
  final energyDays = <DayEnergy>[];
  if (energyMissing.isEmpty &&
      profile != null &&
      profile.hasEnergyInputs &&
      zones != null) {
    final asleep = [
      for (final night in coach.nights) ...night.asleepIntervals,
      // Older nights outside the coach window still mark sleeping minutes.
      for (final session in sessions)
        if (session.end.isBefore(now.subtract(const Duration(days: 7))))
          ...session.asleepIntervals,
    ];
    final today = DateTime(now.year, now.month, now.day);
    final intakeByDate = <String, double?>{
      for (var i = 0; i < (activity?.intakeDates.length ?? 0); i++)
        activity!.intakeDates[i]: i < activity.intakeKcalByDay.length
            ? activity.intakeKcalByDay[i]
            : null,
    };
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      final day = estimateDayEnergy(
        profile: profile,
        date: date,
        now: offset == 0 && energyAsOf != null ? energyAsOf : now,
        cleanedMinutes: clean.samples,
        stepBuckets: stepBuckets,
        sleep: asleep,
        restingBpm: zones.restingBpm,
        maxBpm: zones.maxBpm,
        strengthSessions: lifts,
        workoutWindows: workoutWindows,
        intakeKcal: intakeByDate[sleepKeyOf(date)],
      );
      if (day != null) energyDays.add(day);
    }
  }
  EnergyBalance? energy;
  if (energyDays.isNotEmpty && energyDays.last.date == _day(now)) {
    final history = [
      for (final day in energyDays)
        if (day.complete && _coverage(clean.samples, day.date) >= 12 * 60) day,
    ];
    energy = EnergyBalance(
      today: energyDays.last,
      history: history,
      rmr: restingMetabolicRate(profile!),
      deviceTotalToday: activity?.caloriesTotalToday,
    );
  }

  final weekly = buildWeeklyReview(
    recoveryHistory: history,
    strainDays: strainDays,
    load: load,
    sleep: coach,
    strengthSessions: lifts,
    energyDays: energyDays,
    now: now,
  );

  return Performance(
    now: now,
    clean: clean,
    restingBpm: resting,
    maxHr: maxHr,
    zones: zones,
    strainDays: strainDays,
    load: load,
    sleep: coach,
    hrvTrend: trend,
    energyMissing: energyMissing,
    energyAsOf: energyAsOf,
    recovery: recovery,
    recoveryHistory: history,
    respiratoryDelta: respiratoryDelta,
    skinTempDelta: skinTempDelta,
    alert: alert,
    plan: plan,
    energy: energy,
    energyDays: energyDays,
    muscleVolume: muscleVolume,
    lifts: liftBests(lifts),
    strengthSessions: lifts,
    weekly: weekly,
  );
}

/// Days of heart rate used for strain and load. 56 gives the 28-day chronic
/// average a full window to settle before it is shown.
const loadWindowDays = 56;

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String sleepKeyOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Minutes of usable HR on a local date.
int _coverage(List<TimedValue> samples, DateTime date) {
  final start = date.millisecondsSinceEpoch;
  final end = DateTime(
    date.year,
    date.month,
    date.day + 1,
  ).millisecondsSinceEpoch;
  var count = 0;
  for (final sample in samples) {
    final at = sample.at.millisecondsSinceEpoch;
    if (at >= start && at < end) count++;
  }
  return math.min(count, 1440);
}

/// Session RPE for a synced lifting session that carries none.
///
/// Foster's session RPE tracks internal load in resistance training, and in
/// those sessions it rises with the share of time spent at high heart rate
/// (work sets vs rest). Becel maps the fraction of covered minutes at 50 %+
/// of heart-rate reserve onto CR-10: 0 % → 4 (light), ~30 % → 6.5,
/// ~60 %+ → 9 (very hard). With under half the session covered by heart
/// rate it falls back to 6 (moderate).
StrengthSession estimateSessionRpe(
  StrengthSession session,
  List<TimedValue> cleanedMinutes,
  HeartZones zones,
) {
  var covered = 0;
  var hard = 0;
  final hardBpm = zones.bpmAt(0.5);
  for (final sample in cleanedMinutes) {
    if (sample.at.isBefore(session.start) || !sample.at.isBefore(session.end)) {
      continue;
    }
    covered++;
    if (sample.value >= hardBpm) hard++;
  }
  final rpe = covered < session.durationMinutes / 2
      ? 6.0
      : (4 + 8.3 * hard / covered).clamp(4.0, 9.0);
  return StrengthSession(
    id: session.id,
    start: session.start,
    durationMinutes: session.durationMinutes,
    sessionRpe: (rpe * 2).round() / 2,
    exercises: session.exercises,
    note: session.note,
  );
}
