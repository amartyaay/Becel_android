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
  });

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
  required Set<String> checkInTags,
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
  final clean = cleanHeartRate(rawMinutes);
  final sessions = sleep?.sessions ?? const <SleepNight>[];

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

  final strainDays = zones == null
      ? const <DayStrain>[]
      : dailyStrain(
          cleanedMinutes: clean.samples,
          restingBpm: zones.restingBpm,
          maxBpm: zones.maxBpm,
          sex: sex,
          now: now,
          days: 28,
          strengthSessions: strengthSessions,
        );
  final load = strainDays.isEmpty ? null : trainingLoad(strainDays);
  final yesterdayStrain = strainDays.length < 2
      ? null
      : strainDays[strainDays.length - 2].strain;

  final coach = buildSleepCoach(
    sessions: sessions,
    cleanedMinutes: clean.samples,
    now: now,
    yesterdayStrain: yesterdayStrain,
    baselineNeedMinutes: profile?.sleepNeedMinutes,
    userOnsets: onsetOverrides,
  );

  final respiratoryDelta =
      body?.respiratoryRate != null && body?.respiratoryBaseline != null
      ? body!.respiratoryRate! - body.respiratoryBaseline!
      : null;
  final skinTempDelta = body?.skinTempDeviationC;
  final needGoingIn = coach.baselineNeed + coach.debtNeed;
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
          sleepNeedMinutes: needGoingIn,
          sleepStart: night?.onset,
          sleepEnd: night?.night.end,
          asleepIntervals: night?.asleepIntervals ?? const <AsleepInterval>[],
          sleepWindows: sleep?.sleepWindows ?? const <SleepWindow>[],
          checkInTags: checkInTags,
          respiratoryDelta: respiratoryDelta,
          skinTempDelta: skinTempDelta,
          now: now,
        );
  final history = heart == null || sleep == null
      ? const <RecoveryHistoryPoint>[]
      : recoveryHistory(
          hrvSamples: heart.hrvSamples,
          restingHrSamples: heart.restingHrSamples,
          sleepWindows: sleep.sleepWindows,
          now: now,
          sleepNeedMinutes: coach.baselineNeed,
        );
  final alert = detectBodyAlert(
    recovery: recovery.estimate,
    respiratoryDelta: respiratoryDelta,
    skinTempDelta: skinTempDelta,
  );
  final muscleVolume = weeklyMuscleVolume(strengthSessions, now: now);
  final plan = buildDailyPlan(
    recovery: recovery.estimate,
    load: load,
    sleep: coach,
    alert: alert,
    checkInTags: checkInTags,
    muscleVolume: muscleVolume,
    logsStrength: strengthSessions.isNotEmpty,
    now: now,
  );

  // Energy for the last 7 local dates, today last.
  final energyDays = <DayEnergy>[];
  if (profile != null && profile.hasEnergyInputs && zones != null) {
    final asleep = [
      for (final night in coach.nights) ...night.asleepIntervals,
      // Older nights outside the coach window still mark sleeping minutes.
      for (final session in sessions)
        if (session.end.isBefore(now.subtract(const Duration(days: 7))))
          ...session.asleepIntervals,
    ];
    final today = DateTime(now.year, now.month, now.day);
    for (var offset = 6; offset >= 0; offset--) {
      final date = today.subtract(Duration(days: offset));
      final day = estimateDayEnergy(
        profile: profile,
        date: date,
        now: now,
        cleanedMinutes: clean.samples,
        stepBuckets: heart?.stepBuckets ?? const <StepBucket>[],
        sleep: asleep,
        restingBpm: zones.restingBpm,
        maxBpm: zones.maxBpm,
        strengthSessions: strengthSessions,
      );
      if (day != null) energyDays.add(day);
    }
  }
  EnergyBalance? energy;
  if (energyDays.isNotEmpty && energyDays.last.date == _day(now)) {
    final history = [
      for (final day in energyDays)
        if (day.complete && day.heartMinutes + day.countedSteps ~/ 100 > 0)
          if (_coverage(clean.samples, day.date) >= 12 * 60) day,
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
    strengthSessions: strengthSessions,
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
    recovery: recovery,
    recoveryHistory: history,
    respiratoryDelta: respiratoryDelta,
    skinTempDelta: skinTempDelta,
    alert: alert,
    plan: plan,
    energy: energy,
    energyDays: energyDays,
    muscleVolume: muscleVolume,
    lifts: liftBests(strengthSessions),
    strengthSessions: strengthSessions,
    weekly: weekly,
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

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
