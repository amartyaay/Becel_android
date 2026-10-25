import 'dart:math' as math;

import 'energy.dart' show StepBucket;
import 'estimates.dart';
import 'profile.dart';
import 'strength.dart';

/// Banister TRIMP scale constant mapping daily load onto 0–21.
///
/// strain = 21 × (1 − e^(−TRIMP / k)). With k = 130 and load counted from
/// 10 % HRR, an ordinary day of moving around reads ~5–7, a brisk 45-minute
/// walk adds ~1–2, an hour of running lands ~14–15, a 75-minute tempo ~16,
/// and only an extreme day passes 19. The curve is logarithmic in effort,
/// like WHOOP's scale: each extra point is harder to earn.
const strainScaleK = 130.0;
const strainMax = 21.0;

/// Load counts from 10 % heart-rate reserve. Below that is rest; above it,
/// everyday movement (walking, chores, stairs) builds a small baseline the
/// way WHOOP's day strain does. A 30 % floor, tried first, scored real
/// walks at zero for users with a higher resting HR.
const strainFloorHrr = 0.10;

/// Session-RPE units to Banister-TRIMP equivalence for resistance work.
///
/// HR under-represents lifting load (short sets, long rests). Foster's sRPE
/// (RPE × minutes) tracks internal load in strength sessions; 0.2 × sRPE
/// puts a 60-min RPE-8 session (480 AU) at ~96 TRIMP, similar to a hard
/// hour of steady cardio.
const srpeToTrimp = 0.2;

double strainFromTrimp(double trimp) =>
    strainMax * (1 - math.exp(-math.max(0, trimp) / strainScaleK));

double trimpForStrain(double strain) =>
    -strainScaleK *
    math.log(1 - (strain.clamp(0, strainMax - 0.01) / strainMax));

/// Banister TRIMP per minute at heart-rate-reserve fraction [hrr], minus
/// its value at the 30 % floor so load rises continuously from zero instead
/// of jumping at the threshold.
/// Men: 0.64·e^(1.92x); women: 0.86·e^(1.67x) (Banister 1991).
double banisterTrimpPerMinute(double hrr, BiologicalSex? sex) {
  final x = hrr.clamp(0.0, 1.0);
  if (x <= strainFloorHrr) return 0;
  double raw(double v) => sex == BiologicalSex.female
      ? v * 0.86 * math.exp(1.67 * v)
      : v * 0.64 * math.exp(1.92 * v);
  return raw(x) - raw(strainFloorHrr);
}

/// Training-load floor: only effort at or above 30 % HRR (light-to-moderate
/// exercise and up) feeds acute/chronic load and monotony. Ambient daily
/// heart rate would otherwise pad every day equally, inflating Foster's
/// monotony and pulling ACWR toward 1 (a real deload would look mild).
const trainingFloorHrr = 0.30;

double trainingTrimpPerMinute(double hrr, BiologicalSex? sex) {
  final x = hrr.clamp(0.0, 1.0);
  if (x <= trainingFloorHrr) return 0;
  double raw(double v) => sex == BiologicalSex.female
      ? v * 0.86 * math.exp(1.67 * v)
      : v * 0.64 * math.exp(1.92 * v);
  return raw(x) - raw(trainingFloorHrr);
}

/// Walking cadence thresholds (Tudor-Locke et al., CADENCE-Adults 2018):
/// ~100 steps/min ≈ 3 METs (moderate), ~130 steps/min ≈ 6 METs (vigorous).
const moderateCadence = 100.0;
const vigorousCadence = 130.0;

class DayStrain {
  const DayStrain({
    required this.date,
    required this.cardioTrimp,
    required this.strengthTrimp,
    required this.coverageMinutes,
    required this.zoneMinutes,
    required this.peakBpm,
    this.moderateMinutes = 0,
    this.vigorousMinutes = 0,
    double? trainingTrimp,
    double? trainingStrengthTrimp,
  }) : trainingTrimp = trainingTrimp ?? cardioTrimp,
       trainingStrengthTrimp = trainingStrengthTrimp ?? strengthTrimp;

  /// Load from effort at or above 30 % HRR only (what training-load maths
  /// uses). Day strain ([trimp]) also includes everyday movement.
  final double trainingTrimp;

  /// Strength top-up measured against [trainingTrimp]'s 30 % floor.
  final double trainingStrengthTrimp;

  double get loadTrimp => trainingTrimp + trainingStrengthTrimp;

  /// Intensity minutes: moderate = 40–59 % HRR or ≥ 100 steps/min,
  /// vigorous = ≥ 60 % HRR or ≥ 130 steps/min.
  final double moderateMinutes;
  final double vigorousMinutes;
  double get aerobicEquivalentMinutes => moderateMinutes + 2 * vigorousMinutes;

  final DateTime date;
  final double cardioTrimp;

  /// Extra load from logged strength sessions beyond what HR captured.
  final double strengthTrimp;
  final double coverageMinutes;

  /// Minutes in Karvonen zones Z1–Z5 (50/60/70/80/90 % HRR).
  final List<double> zoneMinutes;
  final int? peakBpm;

  double get trimp => cardioTrimp + strengthTrimp;
  double get strain => strainFromTrimp(trimp);
  bool get hasData => coverageMinutes >= 60 || strengthTrimp > 0;
}

/// Daily strain for each local date from [first] through [now].
///
/// Uses cleaned minute HR; gaps longer than 3 minutes are not filled, so
/// unworn time is never counted as effort.
List<DayStrain> dailyStrain({
  required List<TimedValue> cleanedMinutes,
  required double restingBpm,
  required int maxBpm,
  required BiologicalSex? sex,
  required DateTime now,
  required int days,
  Iterable<StrengthSession> strengthSessions = const [],
  Iterable<StepBucket> stepBuckets = const [],
}) {
  final today = _localDay(now);
  final first = today.subtract(Duration(days: days - 1));
  final reserve = math.max(20.0, maxBpm - restingBpm);
  final cadence = <int, double>{};
  for (final bucket in stepBuckets) {
    final start = bucket.start.millisecondsSinceEpoch ~/ 60000;
    for (var m = 0; m < 5; m++) {
      cadence[start + m] = bucket.steps / 5;
    }
  }
  final training = <DateTime, double>{};
  final cardio = <DateTime, double>{};
  final coverage = <DateTime, double>{};
  final zones = <DateTime, List<double>>{};
  final peaks = <DateTime, int>{};
  final moderate = <DateTime, double>{};
  final vigorous = <DateTime, double>{};
  final perMinute = <int, double>{};
  final perMinuteTraining = <int, double>{};

  for (var index = 1; index < cleanedMinutes.length; index++) {
    final previous = cleanedMinutes[index - 1];
    final current = cleanedMinutes[index];
    final gap = current.at.difference(previous.at).inSeconds / 60;
    if (gap <= 0) continue;
    final day = _localDay(current.at);
    if (day.isBefore(first) || current.at.isAfter(now)) continue;
    // Wear coverage tolerates the sparse resting sampling of wrist HR (up
    // to 10 minutes between samples); load needs dense samples (≤ 3 min).
    if (gap <= 10) coverage[day] = (coverage[day] ?? 0) + gap;
    if (gap > 3) continue;
    final bpm = (previous.value + current.value) / 2;
    final hrr = (bpm - restingBpm) / reserve;
    final load = banisterTrimpPerMinute(hrr, sex) * gap;
    cardio[day] = (cardio[day] ?? 0) + load;
    final trainingLoadPart = trainingTrimpPerMinute(hrr, sex) * gap;
    training[day] = (training[day] ?? 0) + trainingLoadPart;
    perMinute[current.at.millisecondsSinceEpoch ~/ 60000] = load;
    perMinuteTraining[current.at.millisecondsSinceEpoch ~/ 60000] =
        trainingLoadPart;
    final spm = cadence[current.at.millisecondsSinceEpoch ~/ 60000] ?? 0;
    if (hrr >= 0.6 || spm >= vigorousCadence) {
      vigorous[day] = (vigorous[day] ?? 0) + gap;
    } else if (hrr >= 0.4 || spm >= moderateCadence) {
      moderate[day] = (moderate[day] ?? 0) + gap;
    }
    final zone = _zoneIndex(hrr);
    if (zone >= 0) {
      (zones[day] ??= List<double>.filled(5, 0))[zone] += gap;
    }
    if (current.value.round() > (peaks[day] ?? 0)) {
      peaks[day] = current.value.round();
    }
  }

  // Strength sessions: add whatever sRPE load the heart rate missed. Day
  // strain and training load count HR from different floors, so each tops
  // up against what its own floor captured.
  final strength = <DateTime, double>{};
  final strengthTraining = <DateTime, double>{};
  for (final session in strengthSessions) {
    final day = _localDay(session.start);
    if (day.isBefore(first) || session.start.isAfter(now)) continue;
    var captured = 0.0;
    var capturedTraining = 0.0;
    final startMinute = session.start.millisecondsSinceEpoch ~/ 60000;
    for (var m = 0; m < session.durationMinutes; m++) {
      captured += perMinute[startMinute + m] ?? 0;
      capturedTraining += perMinuteTraining[startMinute + m] ?? 0;
    }
    final expected = session.srpeLoad * srpeToTrimp;
    strength[day] = (strength[day] ?? 0) + math.max(0, expected - captured);
    strengthTraining[day] =
        (strengthTraining[day] ?? 0) + math.max(0, expected - capturedTraining);
  }

  return [
    for (var offset = 0; offset < days; offset++)
      () {
        final date = first.add(Duration(days: offset));
        return DayStrain(
          date: date,
          cardioTrimp: cardio[date] ?? 0,
          trainingTrimp: training[date] ?? 0,
          strengthTrimp: strength[date] ?? 0,
          trainingStrengthTrimp: strengthTraining[date] ?? 0,
          coverageMinutes: coverage[date] ?? 0,
          zoneMinutes: zones[date] ?? List<double>.filled(5, 0),
          peakBpm: peaks[date],
          moderateMinutes: moderate[date] ?? 0,
          vigorousMinutes: vigorous[date] ?? 0,
        );
      }(),
  ];
}

/// Cardio strain for one workout window, from cleaned minute HR.
class SessionStrain {
  const SessionStrain({
    required this.strain,
    required this.trimp,
    required this.averageBpm,
    required this.peakBpm,
    required this.minutes,
  });

  final double strain;
  final double trimp;
  final int? averageBpm;
  final int? peakBpm;
  final int minutes;
}

SessionStrain sessionStrain({
  required List<TimedValue> cleanedMinutes,
  required DateTime start,
  required DateTime end,
  required double restingBpm,
  required int maxBpm,
  required BiologicalSex? sex,
}) {
  final reserve = math.max(20.0, maxBpm - restingBpm);
  var trimp = 0.0;
  var sum = 0.0;
  var count = 0;
  var peak = 0.0;
  for (final sample in cleanedMinutes) {
    if (sample.at.isBefore(start) || !sample.at.isBefore(end)) continue;
    trimp += banisterTrimpPerMinute((sample.value - restingBpm) / reserve, sex);
    sum += sample.value;
    count++;
    peak = math.max(peak, sample.value);
  }
  return SessionStrain(
    strain: strainFromTrimp(trimp),
    trimp: trimp,
    averageBpm: count == 0 ? null : (sum / count).round(),
    peakBpm: count == 0 ? null : peak.round(),
    minutes: count,
  );
}

int _zoneIndex(double hrr) {
  if (hrr >= 0.9) return 4;
  if (hrr >= 0.8) return 3;
  if (hrr >= 0.7) return 2;
  if (hrr >= 0.6) return 1;
  if (hrr >= 0.5) return 0;
  return -1;
}

enum LoadStatus {
  calibrating,
  detraining,
  maintaining,
  productive,
  overreaching,
  spike,
}

extension LoadStatusLabel on LoadStatus {
  String get label => switch (this) {
    LoadStatus.calibrating => 'Calibrating',
    LoadStatus.detraining => 'Detraining',
    LoadStatus.maintaining => 'Maintaining',
    LoadStatus.productive => 'Productive',
    LoadStatus.overreaching => 'Overreaching',
    LoadStatus.spike => 'Load spike',
  };

  String get advice => switch (this) {
    LoadStatus.calibrating =>
      'Needs 21 well-worn days to compare short- and long-term load.',
    LoadStatus.detraining =>
      'This week is well below your usual load. Fitness will drift down if it continues.',
    LoadStatus.maintaining =>
      'Load is a little under your norm. Fine for a lighter or deload week.',
    LoadStatus.productive =>
      'Load is building steadily within your usual range.',
    LoadStatus.overreaching =>
      'Load is climbing faster than your base. Plan an easier day in the next 48 h.',
    LoadStatus.spike =>
      'This week is >50 % above your 4-week norm. Pull back intensity before adding more.',
  };
}

class TrainingLoad {
  const TrainingLoad({
    required this.days,
    required this.acute,
    required this.chronic,
    required this.acwr,
    required this.form,
    required this.monotony,
    required this.weeklyTrimp,
    required this.status,
    required this.coveredDays,
  });

  final List<DayStrain> days;

  /// 7-day EWMA of daily TRIMP (fatigue).
  final double acute;

  /// 28-day EWMA of daily TRIMP (fitness).
  final double chronic;

  /// acute ÷ chronic (Williams et al., 2017 EWMA method).
  final double? acwr;

  /// chronic − acute; positive = fresh, negative = fatigued.
  final double form;

  /// Foster monotony: 7-day mean ÷ SD of daily load. > 2 is monotonous.
  final double? monotony;
  final double weeklyTrimp;
  final LoadStatus status;
  final int coveredDays;

  double get acuteStrain => strainFromTrimp(acute);
  double get chronicStrain => strainFromTrimp(chronic);
}

/// Exponentially weighted acute and chronic load.
///
/// The acute:chronic ratio is a load-change indicator. Its value for
/// predicting injury is debated (Impellizzeri et al., 2020), so Becel uses it
/// only to describe how this week compares with your recent base.
/// Days with less wear than this carry the averages forward instead of
/// entering as zero load (an unworn day is unknown, not a rest day).
const loadCoverageMinutes = 12 * 60;

/// Covered days needed before the acute:chronic ratio is shown.
const loadMinimumCoveredDays = 21;

TrainingLoad trainingLoad(List<DayStrain> days, {DateTime? today}) {
  const acuteLambda = 2 / (7 + 1);
  const chronicLambda = 2 / (28 + 1);
  // Today is unfinished: including it would drag acute load down every
  // morning. Load is computed through yesterday.
  final cutoff = today == null
      ? null
      : DateTime(today.year, today.month, today.day);
  final complete = [
    for (final day in days)
      if (cutoff == null || day.date.isBefore(cutoff)) day,
  ];
  bool wellWorn(DayStrain day) =>
      day.coverageMinutes >= loadCoverageMinutes || day.strengthTrimp > 0;
  final covered = complete.where(wellWorn).toList();
  if (covered.isEmpty) {
    return TrainingLoad(
      days: days,
      acute: 0,
      chronic: 0,
      acwr: null,
      form: 0,
      monotony: null,
      weeklyTrimp: 0,
      status: LoadStatus.calibrating,
      coveredDays: 0,
    );
  }
  // Seed both averages with the mean of the first covered fortnight rather
  // than one arbitrary first day.
  final seedDays = covered.take(14).toList();
  final seed =
      seedDays.fold<double>(0, (s, d) => s + d.loadTrimp) / seedDays.length;
  var acute = seed;
  var chronic = seed;
  for (final day in complete) {
    if (!wellWorn(day)) continue;
    acute = acuteLambda * day.loadTrimp + (1 - acuteLambda) * acute;
    chronic = chronicLambda * day.loadTrimp + (1 - chronicLambda) * chronic;
  }
  final last7 = covered.length <= 7
      ? covered
      : covered.sublist(covered.length - 7);
  final weekly = last7.fold<double>(0, (sum, day) => sum + day.loadTrimp);
  final mean = weekly / math.max(1, last7.length);
  final variance = last7.isEmpty
      ? 0.0
      : last7.fold<double>(
              0,
              (sum, day) => sum + math.pow(day.loadTrimp - mean, 2),
            ) /
            last7.length;
  final sd = math.sqrt(variance);
  final monotony = sd < 1 || last7.length < 5 ? null : mean / sd;
  final ratio = covered.length < loadMinimumCoveredDays || chronic < 5
      ? null
      : acute / chronic;
  final status = ratio == null
      ? LoadStatus.calibrating
      : ratio < 0.8
      ? LoadStatus.detraining
      : ratio < 1.0
      ? LoadStatus.maintaining
      : ratio <= 1.3
      ? LoadStatus.productive
      : ratio <= 1.5
      ? LoadStatus.overreaching
      : LoadStatus.spike;
  return TrainingLoad(
    days: days,
    acute: acute,
    chronic: chronic,
    acwr: ratio,
    form: chronic - acute,
    monotony: monotony,
    weeklyTrimp: weekly,
    status: status,
    coveredDays: covered.length,
  );
}

/// Recommended strain range for today from recovery and recent load.
class StrainTarget {
  const StrainTarget({
    required this.low,
    required this.high,
    required this.label,
    required this.reason,
  });

  final double low;
  final double high;
  final String label;
  final String reason;
}

/// Everyday (non-training) strain the target bands assume: strain 5.
final referenceAmbientTrimp = trimpForStrain(5);

/// The user's typical non-training TRIMP: median over the last 28 fully
/// covered days before today (needs 7). Null when there is too little data.
double? ambientTrimp(List<DayStrain> days, {required DateTime today}) {
  final day = _localDay(today);
  final values = [
    for (final d in days)
      if (d.date.isBefore(day) &&
          !d.date.isBefore(day.subtract(const Duration(days: 28))) &&
          d.coverageMinutes >= loadCoverageMinutes)
        math.max(0.0, d.cardioTrimp - d.trainingTrimp),
  ]..sort();
  if (values.length < 7) return null;
  final mid = values.length ~/ 2;
  return values.length.isOdd
      ? values[mid]
      : (values[mid - 1] + values[mid]) / 2;
}

StrainTarget strainTarget({
  required int? recovery,
  required TrainingLoad? load,
  double? ambient,
}) {
  var (low, high, label) = switch (recovery) {
    null => (8.0, 13.0, 'Moderate'),
    >= 67 => (14.0, 18.0, 'Push'),
    >= 34 => (10.0, 14.0, 'Train'),
    _ => (4.0, 9.0, 'Recover'),
  };
  var reason = recovery == null
      ? 'Recovery is still calibrating, so the target is moderate.'
      : recovery >= 67
      ? 'Recovery is high: a hard session is well supported.'
      : recovery >= 34
      ? 'Recovery is moderate: train, but keep intensity controlled.'
      : 'Recovery is low: keep it to Z1–Z2 or mobility.';
  final status = load?.status;
  if (status == LoadStatus.spike || status == LoadStatus.overreaching) {
    low = math.max(4, low - 3);
    high = math.max(low + 3, high - 3);
    reason =
        '$reason Load is above your 4-week base, so the target is trimmed.';
  } else if (status == LoadStatus.detraining &&
      recovery != null &&
      recovery >= 34) {
    high = math.min(strainMax - 1, high + 1);
    reason = '$reason You have room to build: load is below your base.';
  }
  // The bands are "everyday strain 5 + a session". Day strain includes
  // everyday movement, so shift them on the TRIMP scale by how much more or
  // less the user moves outside training; the session dose stays the same.
  if (ambient != null) {
    final shift = ambient - referenceAmbientTrimp;
    double adjust(double strain) => strainFromTrimp(
      math.max(0, trimpForStrain(strain) + shift),
    ).clamp(0.0, strainMax - 0.5);
    final newLow = (adjust(low) * 2).round() / 2;
    final newHigh = math.max(newLow + 2, (adjust(high) * 2).round() / 2);
    if ((newLow - low).abs() >= 0.5 || (newHigh - high).abs() >= 0.5) {
      reason =
          '$reason Adjusted for your everyday strain of '
          '${strainFromTrimp(ambient).toStringAsFixed(1)}.';
    }
    low = newLow;
    high = newHigh;
  }
  return StrainTarget(low: low, high: high, label: label, reason: reason);
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
