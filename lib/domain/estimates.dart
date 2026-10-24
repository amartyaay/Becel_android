import 'dart:math' as math;

/// Numeric Health Connect sample with its source timestamp preserved.
class TimedValue {
  const TimedValue({required this.at, required this.value});

  final DateTime at;
  final double value;
}

const sleepDurationMethod =
    'Sleep duration progress against the adult 7-hour minimum reference. Stages are '
    'shown for context, not scored because wrist-based stage estimates are '
    'not precise enough to grade a night.';

const recoveryMethod =
    'Experimental personal trend: 40% sleep-duration progress, 35% RMSSD HRV, and '
    '25% resting heart rate. HRV readings must fall inside recorded asleep '
    'stages. Daily resting-HR readings are aligned by local date with the '
    'selected sleep session. Both signals are compared with their own matched '
    'values from the previous 14 local dates; each needs 10 baseline dates. '
    'A yellow label means fewer than 2 current HRV readings, no current daily '
    'RHR reading, or an incomplete 14-date baseline for '
    'at least one signal. Its 0-100 mapping and 40/35/25 weights are '
    'experimental product heuristics, not validated measures of readiness or '
    'performance. Use this only as a within-person trend.';

const activityMethod =
    'Becel HR estimate: moderate-equivalent minutes from Fitbit Air heart-rate '
    'samples over the last 7 local days, compared with a 150-minute adult aerobic '
    'reference. Adult recommendations also include 2 days of muscle strengthening; '
    'Becel does not track those sessions. Intensity '
    'uses age-predicted maximum heart rate and your latest resting reading '
    '(up to 36 hours old) for all 7 dates. Moderate minutes count once; vigorous '
    'minutes count twice. This estimates intensity from pulse; it does not '
    'confirm exercise. Missing wear time can lower the total.';

const activityAerobicReferenceMinutes = 150;
const recoveryBaselineWindowDays = 14;
const recoveryMinimumBaselineNights = 10;

/// Shows progress against the seven-hour adult minimum reference.
///
/// Seven hours is an evidence-based minimum reference for adults, not a
/// personalized sleep prescription. Longer sleep is not penalized.
int? sleepDurationProgressPercent({required int minutes}) {
  if (minutes <= 0) return null;
  return (minutes / 420 * 100).round().clamp(0, 100);
}

class SleepWindow {
  const SleepWindow({
    required this.start,
    required this.end,
    required this.sleepMinutes,
    required this.asleepIntervals,
  });

  final DateTime start;
  final DateTime end;
  final int sleepMinutes;
  final List<AsleepInterval> asleepIntervals;
}

class AsleepInterval {
  const AsleepInterval({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);
}

class RecoveryEstimate {
  const RecoveryEstimate({
    required this.score,
    required this.sleepComponent,
    required this.hrvComponent,
    required this.restingHrComponent,
    required this.hrvCurrent,
    required this.hrvAt,
    required this.hrvSampleCount,
    required this.hrvBaseline,
    required this.restingHrCurrent,
    required this.restingHrAt,
    required this.restingHrSampleCount,
    required this.restingHrBaseline,
    required this.hrvBaselineDays,
    required this.restingHrBaselineDays,
  });

  final int score;
  final int sleepComponent;
  final int hrvComponent;
  final int restingHrComponent;
  final double hrvCurrent;
  final DateTime hrvAt;
  final int hrvSampleCount;
  final double hrvBaseline;
  final double restingHrCurrent;
  final DateTime restingHrAt;
  final int restingHrSampleCount;
  final double restingHrBaseline;
  final int hrvBaselineDays;
  final int restingHrBaselineDays;
}

class RecoveryReadiness {
  const RecoveryReadiness({
    required this.hasSleepSession,
    required this.hrvCurrentSampleCount,
    required this.restingHrCurrentSampleCount,
    required this.hrvBaselineNights,
    required this.restingHrBaselineNights,
    required this.limitedSamples,
    required this.estimate,
  });

  final bool hasSleepSession;
  final int hrvCurrentSampleCount;
  final int restingHrCurrentSampleCount;
  final int hrvBaselineNights;
  final int restingHrBaselineNights;
  final bool limitedSamples;
  final RecoveryEstimate? estimate;
}

class RecoveryHistoryPoint {
  const RecoveryHistoryPoint({
    required this.date,
    this.readiness,
    this.session,
  });

  final DateTime date;
  final RecoveryReadiness? readiness;
  final SleepWindow? session;

  int? get sleepMinutes => session?.sleepMinutes;
}

/// Recalculates the same experimental estimate for each selected sleep date.
/// Missing sessions or insufficient baseline signals remain gaps in history.
List<RecoveryHistoryPoint> recoveryHistory({
  required List<TimedValue> hrvSamples,
  required List<TimedValue> restingHrSamples,
  required List<SleepWindow> sleepWindows,
  required DateTime now,
  int days = 14,
}) {
  if (days <= 0) return const [];
  final today = _localDay(now);
  final points = <RecoveryHistoryPoint>[];
  for (var offset = days - 1; offset >= 0; offset--) {
    final date = today.subtract(Duration(days: offset));
    final sessions =
        sleepWindows
            .where(
              (window) =>
                  window.sleepMinutes >= 180 && _localDay(window.end) == date,
            )
            .toList()
          ..sort((a, b) => b.sleepMinutes.compareTo(a.sleepMinutes));
    if (sessions.isEmpty) {
      points.add(RecoveryHistoryPoint(date: date));
      continue;
    }
    final session = sessions.first;
    final endOfDate = DateTime(
      date.year,
      date.month,
      date.day + 1,
    ).subtract(const Duration(microseconds: 1));
    final readiness = recoveryReadiness(
      hrvSamples: hrvSamples,
      restingHrSamples: restingHrSamples,
      sleepMinutes: session.sleepMinutes,
      sleepStart: session.start,
      sleepEnd: session.end,
      asleepIntervals: session.asleepIntervals,
      sleepWindows: sleepWindows,
      now: offset == 0 && now.isBefore(endOfDate) ? now : endOfDate,
    );
    points.add(
      RecoveryHistoryPoint(date: date, readiness: readiness, session: session),
    );
  }
  return points;
}

/// Estimates recovery from sleep-stage HRV and sleep-date resting-HR readings.
RecoveryReadiness recoveryReadiness({
  required List<TimedValue> hrvSamples,
  required List<TimedValue> restingHrSamples,
  required int? sleepMinutes,
  required DateTime? sleepStart,
  required DateTime? sleepEnd,
  required List<AsleepInterval> asleepIntervals,
  required List<SleepWindow> sleepWindows,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final sleepProgress = sleepDurationProgressPercent(
    minutes: sleepMinutes ?? 0,
  );
  final hasSleepSession =
      sleepProgress != null && sleepStart != null && sleepEnd != null;
  if (!hasSleepSession) {
    return const RecoveryReadiness(
      hasSleepSession: false,
      hrvCurrentSampleCount: 0,
      restingHrCurrentSampleCount: 0,
      hrvBaselineNights: 0,
      restingHrBaselineNights: 0,
      limitedSamples: false,
      estimate: null,
    );
  }
  final currentSleepEnd = sleepEnd;
  final currentSleepDay = _localDay(currentSleepEnd);
  final hrv = _currentAndBaselineByAsleepStages(
    hrvSamples,
    reference,
    currentSleepDay: currentSleepDay,
    currentEnd: currentSleepEnd,
    currentAsleepIntervals: asleepIntervals,
    sleepWindows: sleepWindows,
    minValue: 5,
    maxValue: 250,
  );
  final restingHr = _currentAndBaselineBySleepDate(
    restingHrSamples,
    reference,
    currentSleepDay: currentSleepDay,
    sleepWindows: sleepWindows,
    minValue: 30,
    maxValue: 120,
  );
  final hrvCurrentSampleCount = hrv.currentSampleCount;
  final restingHrCurrentSampleCount = restingHr.currentSampleCount;
  final hrvBaselineNights = hrv.baselineNights;
  final restingHrBaselineNights = restingHr.baselineNights;
  final limitedSamples =
      hrvCurrentSampleCount < 2 ||
      restingHrCurrentSampleCount < 1 ||
      hrvBaselineNights < recoveryBaselineWindowDays ||
      restingHrBaselineNights < recoveryBaselineWindowDays;
  final hrvCurrent = hrv.current;
  final restingHrCurrent = restingHr.current;
  if (hrvCurrent == null ||
      restingHrCurrent == null ||
      hrvBaselineNights < recoveryMinimumBaselineNights ||
      restingHrBaselineNights < recoveryMinimumBaselineNights) {
    return RecoveryReadiness(
      hasSleepSession: true,
      hrvCurrentSampleCount: hrvCurrentSampleCount,
      restingHrCurrentSampleCount: restingHrCurrentSampleCount,
      hrvBaselineNights: hrvBaselineNights,
      restingHrBaselineNights: restingHrBaselineNights,
      limitedSamples: limitedSamples,
      estimate: null,
    );
  }

  final hrvBaseline = _median(hrv.baseline.map(math.log).toList());
  final hrvMad = _median(
    hrv.baseline.map((value) => (math.log(value) - hrvBaseline).abs()).toList(),
  );
  final restingHrBaseline = _median(restingHr.baseline);
  final restingHrMad = _median(
    restingHr.baseline
        .map((value) => (value - restingHrBaseline).abs())
        .toList(),
  );

  // MAD is robust to isolated noisy nights. Floors avoid a zero denominator
  // when rounded device values repeat across several days.
  final hrvZ = _clamp(
    (math.log(hrvCurrent) - hrvBaseline) / math.max(0.10, 1.4826 * hrvMad),
    -2,
    2,
  );
  final restingHrZ = _clamp(
    (restingHrCurrent - restingHrBaseline) /
        math.max(2.0, 1.4826 * restingHrMad),
    -2,
    2,
  );
  final hrvScore = (50 + hrvZ * 25).round().clamp(0, 100);
  final restingHrScore = (50 - restingHrZ * 25).round().clamp(0, 100);
  final score = (sleepProgress * 0.40 + hrvScore * 0.35 + restingHrScore * 0.25)
      .round()
      .clamp(0, 100);

  final estimate = RecoveryEstimate(
    score: score,
    sleepComponent: sleepProgress,
    hrvComponent: hrvScore,
    restingHrComponent: restingHrScore,
    hrvCurrent: hrvCurrent,
    hrvAt: hrv.at,
    hrvSampleCount: hrv.currentSampleCount,
    hrvBaseline: math.exp(hrvBaseline),
    restingHrCurrent: restingHrCurrent,
    restingHrAt: restingHr.at,
    restingHrSampleCount: restingHr.currentSampleCount,
    restingHrBaseline: restingHrBaseline,
    hrvBaselineDays: hrv.baselineNights,
    restingHrBaselineDays: restingHr.baselineNights,
  );
  return RecoveryReadiness(
    hasSleepSession: true,
    hrvCurrentSampleCount: hrvCurrentSampleCount,
    restingHrCurrentSampleCount: restingHrCurrentSampleCount,
    hrvBaselineNights: hrvBaselineNights,
    restingHrBaselineNights: restingHrBaselineNights,
    limitedSamples: limitedSamples,
    estimate: estimate,
  );
}

class _CurrentBaseline {
  const _CurrentBaseline({
    required this.current,
    required this.at,
    required this.currentSampleCount,
    required this.baseline,
    required this.baselineNights,
  });

  final double? current;
  final DateTime at;
  final int currentSampleCount;
  final List<double> baseline;
  final int baselineNights;
}

_CurrentBaseline _currentAndBaselineByAsleepStages(
  List<TimedValue> samples,
  DateTime now, {
  required DateTime currentSleepDay,
  required DateTime currentEnd,
  required List<AsleepInterval> currentAsleepIntervals,
  required List<SleepWindow> sleepWindows,
  required double minValue,
  required double maxValue,
}) {
  final recent = _validSamples(
    samples,
    asleepIntervals: currentAsleepIntervals,
    latest: now,
    minValue: minValue,
    maxValue: maxValue,
  )..sort((a, b) => b.at.compareTo(a.at));
  final current = recent.isEmpty
      ? null
      : _median(recent.map((s) => s.value).toList());
  final currentAt = recent.isEmpty ? currentEnd : recent.first.at;
  final windowsByDay = _baselineSleepWindowsByDate(
    sleepWindows,
    currentSleepDay,
  );
  final baseline = <double>[];
  for (final windows in windowsByDay.values) {
    windows.sort((a, b) => b.sleepMinutes.compareTo(a.sleepMinutes));
    final window = windows.first;
    final values = _validSamples(
      samples,
      asleepIntervals: window.asleepIntervals,
      latest: now,
      minValue: minValue,
      maxValue: maxValue,
    ).map((sample) => sample.value).toList();
    if (values.isNotEmpty) baseline.add(_median(values));
  }

  return _CurrentBaseline(
    current: current,
    at: currentAt,
    currentSampleCount: recent.length,
    baseline: baseline,
    baselineNights: baseline.length,
  );
}

_CurrentBaseline _currentAndBaselineBySleepDate(
  List<TimedValue> samples,
  DateTime now, {
  required DateTime currentSleepDay,
  required List<SleepWindow> sleepWindows,
  required double minValue,
  required double maxValue,
}) {
  final samplesByDate = <DateTime, List<TimedValue>>{};
  for (final sample in samples) {
    if (sample.value < minValue ||
        sample.value > maxValue ||
        sample.at.isAfter(now)) {
      continue;
    }
    (samplesByDate[_localDay(sample.at)] ??= []).add(sample);
  }

  final current = [...?samplesByDate[currentSleepDay]]
    ..sort((a, b) => b.at.compareTo(a.at));
  final windowsByDay = _baselineSleepWindowsByDate(
    sleepWindows,
    currentSleepDay,
  );
  final baseline = <double>[];
  for (final day in windowsByDay.keys) {
    final values = samplesByDate[day];
    if (values != null && values.isNotEmpty) {
      baseline.add(_median(values.map((sample) => sample.value).toList()));
    }
  }

  return _CurrentBaseline(
    current: current.isEmpty
        ? null
        : _median(current.map((sample) => sample.value).toList()),
    at: current.isEmpty ? now : current.first.at,
    currentSampleCount: current.length,
    baseline: baseline,
    baselineNights: baseline.length,
  );
}

Map<DateTime, List<SleepWindow>> _baselineSleepWindowsByDate(
  List<SleepWindow> sleepWindows,
  DateTime currentSleepDay,
) {
  final firstBaselineDay = DateTime(
    currentSleepDay.year,
    currentSleepDay.month,
    currentSleepDay.day - recoveryBaselineWindowDays,
  );
  final windowsByDay = <DateTime, List<SleepWindow>>{};
  for (final window in sleepWindows) {
    if (window.sleepMinutes < 180) continue;
    final day = _localDay(window.end);
    if (!day.isBefore(currentSleepDay) || day.isBefore(firstBaselineDay)) {
      continue;
    }
    (windowsByDay[day] ??= []).add(window);
  }
  for (final windows in windowsByDay.values) {
    windows.sort((a, b) => b.sleepMinutes.compareTo(a.sleepMinutes));
  }
  return windowsByDay;
}

List<TimedValue> _validSamples(
  List<TimedValue> samples, {
  required List<AsleepInterval> asleepIntervals,
  required DateTime latest,
  required double minValue,
  required double maxValue,
}) => samples
    .where(
      (sample) =>
          sample.value >= minValue &&
          sample.value <= maxValue &&
          asleepIntervals.any((interval) => interval.contains(sample.at)) &&
          !sample.at.isAfter(latest),
    )
    .toList();

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[middle];
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

double _clamp(double value, double min, double max) =>
    value.clamp(min, max).toDouble();

class ActivityEstimate {
  const ActivityEstimate({
    required this.age,
    required this.estimatedMaxHrBpm,
    required this.restingHrBpm,
    required this.restingHrAt,
    required this.moderateMinutes,
    required this.vigorousMinutes,
    required this.usableDays,
    this.dailyDates = const [],
    this.dailyEquivalentMinutes = const [],
    this.dailyCoverageMinutes = const [],
    required this.zoneMinutes,
    required this.zoneRanges,
  });

  final int age;
  final int estimatedMaxHrBpm;
  final double restingHrBpm;
  final DateTime restingHrAt;
  final double moderateMinutes;
  final double vigorousMinutes;
  final int usableDays;
  final List<String> dailyDates;
  final List<double?> dailyEquivalentMinutes;
  final List<double> dailyCoverageMinutes;
  final List<double> zoneMinutes;
  final List<String> zoneRanges;

  double get equivalentMinutes => moderateMinutes + 2 * vigorousMinutes;

  int get displayedEquivalentMinutes => equivalentMinutes.floor();

  int get progressPercent =>
      (displayedEquivalentMinutes * 100 ~/ activityAerobicReferenceMinutes)
          .clamp(0, 100)
          .toInt();

  int get minutesToAerobicReference =>
      displayedEquivalentMinutes < activityAerobicReferenceMinutes
      ? activityAerobicReferenceMinutes - displayedEquivalentMinutes
      : 0;

  int get minutesAboveAerobicReference =>
      displayedEquivalentMinutes > activityAerobicReferenceMinutes
      ? displayedEquivalentMinutes - activityAerobicReferenceMinutes
      : 0;
}
