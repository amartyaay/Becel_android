import 'dart:math' as math;

/// Numeric Health Connect sample with its source timestamp preserved.
class TimedValue {
  const TimedValue({required this.at, required this.value});

  final DateTime at;
  final double value;
}

/// Single source of truth for recovery weights, shown verbatim in the app.
abstract final class RecoveryModel {
  static const hrvWeight = 0.55;
  static const restingHrWeight = 0.25;
  static const sleepWeight = 0.20;

  /// SD of the weighted sum of the three unit z-scores. HRV and resting HR
  /// are not independent (r ≈ −0.4 to −0.6 within a person; Buchheit 2014),
  /// so with ρ = 0.5 between HRV z and −RHR z:
  /// √(0.55² + 0.25² + 0.20² + 2·0.55·0.25·0.5) ≈ 0.74. Using the independent
  /// value (0.64) made the bands fire more often than stated.
  static const compositeScale = 0.74;

  /// Sleep below this share of need is penalised even if it is typical for
  /// you: chronic short sleep should never read as neutral.
  static const shortSleepPercent = 75;

  /// Score = 100 × Φ(slope × composite z): a typical morning for you
  /// (z = 0) reads 50 %. The bands are evidence thresholds, so the number,
  /// colour, word, and training advice can never disagree: green (≥ 67 %)
  /// is z ≥ +0.5 (clearly better than usual), red (≤ 25 %) is z ≤ −0.75.
  static const offset = 0.0;
  static const slope = 0.9;

  static const green = 67;
  static const red = 25;

  static String get weightsLabel =>
      'HRV ${(hrvWeight * 100).round()}% · resting HR '
      '${(restingHrWeight * 100).round()}% · sleep vs need '
      '${(sleepWeight * 100).round()}%';
}

/// Built from [RecoveryModel] so the explanation can never drift from the
/// arithmetic.
final recoveryMethod =
    'Recovery compares last night with your own 28-day baseline. Overnight '
    'HRV (ln RMSSD, only readings inside asleep stages) and morning resting '
    'heart rate become robust z-scores (median and MAD). Sleep, as a share '
    'of the need going into that night, is compared with your own last 28 '
    'nights the same way; under ${RecoveryModel.shortSleepPercent}% of need '
    'always counts against you, and meeting your need never does. The '
    'weighted z-scores (${RecoveryModel.weightsLabel}), scaled for HRV and '
    'resting HR moving together, are '
    'mapped to 0–100% with a normal curve centred on your typical morning, '
    'which reads 50%. ${RecoveryModel.green}% or more means clearly better '
    'than usual (go hard); ${RecoveryModel.red}% or less means clearly worse '
    '(recover). HRV counts at most +1.5 SD, and not at all when resting HR '
    'is also high. A respiratory-rate rise of 1+ breath/min or skin '
    'temperature 0.5 °C+ above baseline lowers the score. Scores start '
    'after $recoveryMinimumBaselineNights baseline nights and are marked '
    'provisional until $recoveryFullBaselineNights.';

const activityMethod =
    'Moderate-equivalent minutes from Fitbit Air heart rate over the last 7 '
    'local days. Moderate = 40–59% of heart-rate reserve, vigorous 60%+ '
    '(ACSM); vigorous minutes count twice toward the 150-minute aerobic '
    'guideline. Missing wear time can lower the total.';

const activityAerobicReferenceMinutes = 150;
const recoveryBaselineWindowDays = 28;
const recoveryMinimumBaselineNights = 4;
const recoveryFullBaselineNights = 10;

/// Shows progress against the seven-hour adult minimum reference.
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

enum RecoveryBand { red, yellow, green }

RecoveryBand recoveryBandOf(int score) => score >= RecoveryModel.green
    ? RecoveryBand.green
    : score > RecoveryModel.red
    ? RecoveryBand.yellow
    : RecoveryBand.red;

class RecoveryEstimate {
  const RecoveryEstimate({
    required this.score,
    required this.hrvZ,
    required this.restingHrZ,
    required this.sleepZ,
    required this.contextAdjustment,
    this.composite,
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
    required this.sleepPercentOfNeed,
    this.contextReasons = const [],
  });

  final int score;
  final double hrvZ;

  /// Positive = resting HR higher than usual (worse).
  final double restingHrZ;
  final double sleepZ;

  /// Composite-z shift from check-in and respiratory/temperature signals.
  final double contextAdjustment;

  /// Weighted composite in SD units (0 = a typical morning for you).
  final double? composite;

  /// Prescription band. Since the % scale is centred on your typical
  /// morning, this is the same as [band]: one mapping everywhere.
  RecoveryBand get trainingBand => band;

  final List<String> contextReasons;
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
  final int sleepPercentOfNeed;

  RecoveryBand get band => recoveryBandOf(score);
  bool get provisional =>
      math.min(hrvBaselineDays, restingHrBaselineDays) <
      recoveryFullBaselineNights;

  /// Signed contribution of each signal to the composite, in z units.
  double get hrvContribution =>
      RecoveryModel.hrvWeight * hrvZ / RecoveryModel.compositeScale;
  double get restingHrContribution =>
      -RecoveryModel.restingHrWeight *
      restingHrZ /
      RecoveryModel.compositeScale;
  double get sleepContribution =>
      RecoveryModel.sleepWeight * sleepZ / RecoveryModel.compositeScale;

  double get hrvChangePercent => (hrvCurrent / hrvBaseline - 1) * 100;
  double get restingHrChange => restingHrCurrent - restingHrBaseline;
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

  /// Provisional baseline (< 10 nights) or a single current HRV reading.
  final bool limitedSamples;
  final RecoveryEstimate? estimate;

  int get nightsUntilScore => math.max(
    0,
    recoveryMinimumBaselineNights -
        math.min(hrvBaselineNights, restingHrBaselineNights),
  );
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

/// Recalculates recovery for each recent wake date. Missing sessions or
/// thin baselines remain gaps.
List<RecoveryHistoryPoint> recoveryHistory({
  required List<TimedValue> hrvSamples,
  required List<TimedValue> restingHrSamples,
  required List<SleepWindow> sleepWindows,
  required DateTime now,
  int days = 14,
  int sleepNeedMinutes = 480,
  int Function(DateTime date)? sleepNeedFor,
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
      sleepNeedMinutes: sleepNeedFor?.call(date) ?? sleepNeedMinutes,
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

/// Recovery from sleep-stage HRV, wake-date resting HR, and sleep vs need.
RecoveryReadiness recoveryReadiness({
  required List<TimedValue> hrvSamples,
  required List<TimedValue> restingHrSamples,
  required int? sleepMinutes,
  required DateTime? sleepStart,
  required DateTime? sleepEnd,
  required List<AsleepInterval> asleepIntervals,
  required List<SleepWindow> sleepWindows,
  int sleepNeedMinutes = 480,
  double? respiratoryDelta,
  double? skinTempDelta,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final hasSleepSession =
      (sleepMinutes ?? 0) > 0 && sleepStart != null && sleepEnd != null;
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
  final limitedSamples =
      hrv.currentSampleCount < 2 ||
      restingHr.currentSampleCount < 1 ||
      hrv.baselineNights < recoveryFullBaselineNights ||
      restingHr.baselineNights < recoveryFullBaselineNights;
  final hrvCurrent = hrv.current;
  final restingHrCurrent = restingHr.current;
  if (hrvCurrent == null ||
      restingHrCurrent == null ||
      hrv.baselineNights < recoveryMinimumBaselineNights ||
      restingHr.baselineNights < recoveryMinimumBaselineNights) {
    return RecoveryReadiness(
      hasSleepSession: true,
      hrvCurrentSampleCount: hrv.currentSampleCount,
      restingHrCurrentSampleCount: restingHr.currentSampleCount,
      hrvBaselineNights: hrv.baselineNights,
      restingHrBaselineNights: restingHr.baselineNights,
      limitedSamples: limitedSamples,
      estimate: null,
    );
  }

  final logBaseline = hrv.baseline.map(math.log).toList();
  final hrvMedian = _median(logBaseline);
  final hrvMad = _median([for (final v in logBaseline) (v - hrvMedian).abs()]);
  final rhrMedian = _median(restingHr.baseline);
  final rhrMad = _median([
    for (final v in restingHr.baseline) (v - rhrMedian).abs(),
  ]);

  // MAD is robust to isolated noisy nights; floors stop rounded, repeated
  // device values from producing a zero denominator.
  // HRV far above baseline is not "extra recovered": in trained athletes it
  // can mean parasympathetic saturation or early illness (Plews et al.,
  // 2012). The upside is capped at +1.5 SD, and ignored entirely when
  // resting HR is also elevated.
  final restingHrZ = _clamp(
    (restingHrCurrent - rhrMedian) / math.max(2.0, 1.4826 * rhrMad),
    -3,
    3,
  );
  final rawHrvZ = _clamp(
    (math.log(hrvCurrent) - hrvMedian) / math.max(0.10, 1.4826 * hrvMad),
    -3,
    1.5,
  );
  final hrvZ = rawHrvZ > 1 && restingHrZ > 1 ? 0.0 : rawHrvZ;
  final need = math.max(360, sleepNeedMinutes);
  final exactSleepPercent = (sleepMinutes ?? 0) / need * 100;
  final sleepPercent = exactSleepPercent.round();
  // Like HRV and RHR, sleep is scored against your own last 28 nights, so
  // a steady 7 h sleeper is not dragged down every day. Two guards: sleep
  // under 75 % of need is penalised however usual it is, and meeting your
  // need never counts against you.
  final pastPercents = _pastSleepPercents(
    sleepWindows,
    currentSleepDay: currentSleepDay,
    need: need,
  );
  final absoluteZ = (exactSleepPercent - RecoveryModel.shortSleepPercent) / 12;
  double sleepZ;
  if (pastPercents.length >= recoveryMinimumBaselineNights) {
    final median = _median(pastPercents);
    final mad = _median([for (final v in pastPercents) (v - median).abs()]);
    sleepZ = (exactSleepPercent - median) / math.max(6.0, 1.4826 * mad);
    if (absoluteZ < 0) sleepZ = math.min(sleepZ, absoluteZ);
  } else {
    sleepZ = (exactSleepPercent - 85) / 12;
  }
  if (exactSleepPercent >= 100) sleepZ = math.max(sleepZ, 0);
  sleepZ = _clamp(sleepZ, -3, 1.5);

  var adjustment = 0.0;
  final reasons = <String>[];
  if (rawHrvZ > 1 && restingHrZ > 1) {
    reasons.add('HRV and resting HR both high: not counted as a boost');
  }
  if (respiratoryDelta != null && respiratoryDelta >= 1.0) {
    adjustment -= 0.5;
    reasons.add(
      'Respiratory rate +${respiratoryDelta.toStringAsFixed(1)}/min vs baseline',
    );
  }
  if (skinTempDelta != null && skinTempDelta >= 0.5) {
    adjustment -= 0.5;
    reasons.add(
      'Skin temperature +${skinTempDelta.toStringAsFixed(1)} °C vs baseline',
    );
  }

  final composite =
      (RecoveryModel.hrvWeight * hrvZ -
              RecoveryModel.restingHrWeight * restingHrZ +
              RecoveryModel.sleepWeight * sleepZ) /
          RecoveryModel.compositeScale +
      adjustment;
  final score =
      (100 * _normalCdf(RecoveryModel.offset + RecoveryModel.slope * composite))
          .round()
          .clamp(1, 99);

  return RecoveryReadiness(
    hasSleepSession: true,
    hrvCurrentSampleCount: hrv.currentSampleCount,
    restingHrCurrentSampleCount: restingHr.currentSampleCount,
    hrvBaselineNights: hrv.baselineNights,
    restingHrBaselineNights: restingHr.baselineNights,
    limitedSamples: limitedSamples,
    estimate: RecoveryEstimate(
      score: score,
      hrvZ: hrvZ,
      restingHrZ: restingHrZ,
      sleepZ: sleepZ,
      contextAdjustment: adjustment,
      composite: composite,
      contextReasons: reasons,
      hrvCurrent: hrvCurrent,
      hrvAt: hrv.at,
      hrvSampleCount: hrv.currentSampleCount,
      hrvBaseline: math.exp(hrvMedian),
      restingHrCurrent: restingHrCurrent,
      restingHrAt: restingHr.at,
      restingHrSampleCount: restingHr.currentSampleCount,
      restingHrBaseline: rhrMedian,
      hrvBaselineDays: hrv.baselineNights,
      restingHrBaselineDays: restingHr.baselineNights,
      sleepPercentOfNeed: sleepPercent.clamp(0, 150),
    ),
  );
}

enum HrvTrendState { below, within, above }

/// Rolling 7-day ln RMSSD against the prior 28 days ± the smallest
/// worthwhile change (0.5 × SD). Single nights are noisy; the weekly trend
/// is the more reliable signal for training decisions (Plews et al., 2013;
/// Buchheit, 2014).
class HrvTrend {
  const HrvTrend({
    required this.nights,
    required this.rolling,
    required this.baseline,
    required this.swc,
  });

  /// Nightly ln RMSSD for the last 14 wake dates (null = no reading).
  final List<({DateTime date, double? ln})> nights;
  final double rolling;
  final double baseline;
  final double swc;

  HrvTrendState get state => rolling < baseline - swc
      ? HrvTrendState.below
      : rolling > baseline + swc
      ? HrvTrendState.above
      : HrvTrendState.within;

  double get rollingMs => math.exp(rolling);
  double get lowMs => math.exp(baseline - swc);
  double get highMs => math.exp(baseline + swc);
}

HrvTrend? hrvTrend({
  required List<TimedValue> hrvSamples,
  required List<SleepWindow> sleepWindows,
  required DateTime now,
}) {
  final today = _localDay(now);
  final byDate = <DateTime, double>{};
  for (final window in sleepWindows) {
    if (window.sleepMinutes < 180) continue;
    final date = _localDay(window.end);
    if (date.isAfter(today) || today.difference(date).inDays > 35) continue;
    final values = _validSamples(
      hrvSamples,
      asleepIntervals: window.asleepIntervals,
      latest: now,
      minValue: 5,
      maxValue: 250,
    ).map((s) => s.value).toList();
    if (values.isEmpty) continue;
    byDate[date] = math.log(_median(values));
  }
  final recent = <double>[];
  final prior = <double>[];
  for (final entry in byDate.entries) {
    final age = today.difference(entry.key).inDays;
    if (age < 7) {
      recent.add(entry.value);
    } else {
      prior.add(entry.value);
    }
  }
  if (recent.length < 4 || prior.length < 10) return null;
  final mean = prior.reduce((a, b) => a + b) / prior.length;
  final sd = math.sqrt(
    prior.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
        (prior.length - 1),
  );
  return HrvTrend(
    nights: [
      for (var offset = 13; offset >= 0; offset--)
        (
          date: today.subtract(Duration(days: offset)),
          ln: byDate[today.subtract(Duration(days: offset))],
        ),
    ],
    rolling: recent.reduce((a, b) => a + b) / recent.length,
    baseline: mean,
    // Wrist RMSSD is noisier than chest-strap ECG, so the band is at least
    // ±4 % of the baseline.
    swc: math.max(0.04, 0.5 * sd),
  );
}

/// Abramowitz–Stegun 7.1.26 approximation of the standard normal CDF.
double _normalCdf(double x) {
  final t = 1 / (1 + 0.3275911 * x.abs() / math.sqrt2);
  final poly =
      t *
      (0.254829592 +
          t *
              (-0.284496736 +
                  t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))));
  final erf = 1 - poly * math.exp(-(x * x) / 2);
  return x >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
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

/// Sleep as % of [need] for the main sleep (longest per wake date) of each
/// of the 28 days before [currentSleepDay].
List<double> _pastSleepPercents(
  List<SleepWindow> windows, {
  required DateTime currentSleepDay,
  required int need,
}) {
  final first = currentSleepDay.subtract(const Duration(days: 28));
  final longest = <DateTime, int>{};
  for (final window in windows) {
    if (window.sleepMinutes < 180) continue;
    final day = _localDay(window.end);
    if (!day.isBefore(currentSleepDay) || day.isBefore(first)) continue;
    longest[day] = math.max(longest[day] ?? 0, window.sleepMinutes);
  }
  return [for (final minutes in longest.values) minutes / need * 100];
}

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

  /// Upper-bound estimate if days without usable heart-rate coverage matched
  /// the covered days. This is a sensitivity check, not a measurement.
  int get potentialEquivalentMinutes {
    final observed = displayedEquivalentMinutes;
    if (observed <= 0) return 0;
    final covered = usableDays.clamp(1, 7);
    if (covered >= 7) return observed;
    return (equivalentMinutes * 7 / covered).ceil();
  }

  int get minutesToAerobicReference =>
      displayedEquivalentMinutes < activityAerobicReferenceMinutes
      ? activityAerobicReferenceMinutes - displayedEquivalentMinutes
      : 0;

  int get minutesAboveAerobicReference =>
      displayedEquivalentMinutes > activityAerobicReferenceMinutes
      ? displayedEquivalentMinutes - activityAerobicReferenceMinutes
      : 0;
}
