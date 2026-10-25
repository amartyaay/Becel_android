import 'dart:math' as math;

import 'estimates.dart';
import 'profile.dart';
import 'strength.dart';

/// Banister TRIMP scale constant mapping daily load onto 0–21.
///
/// strain = 21 × (1 − e^(−TRIMP / k)). With k = 90 a light day (~25 TRIMP)
/// reads ~5, an hour of steady running (~100) ~14, and a long hard day
/// (~250) ~19.7. The curve is logarithmic in effort, like WHOOP's scale:
/// each extra point is harder to earn.
const strainScaleK = 90.0;
const strainMax = 21.0;

/// Below 30 % heart-rate reserve, minutes are ambient (standing, talking,
/// digestion) and are not counted as training load.
const strainFloorHrr = 0.30;

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

/// Banister TRIMP per minute at heart-rate-reserve fraction [hrr].
/// Men: 0.64·e^(1.92x); women: 0.86·e^(1.67x) (Banister 1991).
double banisterTrimpPerMinute(double hrr, BiologicalSex? sex) {
  final x = hrr.clamp(0.0, 1.0);
  if (x < strainFloorHrr) return 0;
  return sex == BiologicalSex.female
      ? x * 0.86 * math.exp(1.67 * x)
      : x * 0.64 * math.exp(1.92 * x);
}

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
  });

  /// ACSM intensity minutes: moderate 40–59 % HRR, vigorous ≥ 60 % HRR.
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
}) {
  final today = _localDay(now);
  final first = today.subtract(Duration(days: days - 1));
  final reserve = math.max(20.0, maxBpm - restingBpm);
  final cardio = <DateTime, double>{};
  final coverage = <DateTime, double>{};
  final zones = <DateTime, List<double>>{};
  final peaks = <DateTime, int>{};
  final moderate = <DateTime, double>{};
  final vigorous = <DateTime, double>{};
  final perMinute = <int, double>{};

  for (var index = 1; index < cleanedMinutes.length; index++) {
    final previous = cleanedMinutes[index - 1];
    final current = cleanedMinutes[index];
    final gap = current.at.difference(previous.at).inSeconds / 60;
    if (gap <= 0 || gap > 3) continue;
    final day = _localDay(current.at);
    if (day.isBefore(first) || current.at.isAfter(now)) continue;
    final bpm = (previous.value + current.value) / 2;
    final hrr = (bpm - restingBpm) / reserve;
    final load = banisterTrimpPerMinute(hrr, sex) * gap;
    cardio[day] = (cardio[day] ?? 0) + load;
    perMinute[current.at.millisecondsSinceEpoch ~/ 60000] = load;
    coverage[day] = (coverage[day] ?? 0) + gap;
    if (hrr >= 0.6) {
      vigorous[day] = (vigorous[day] ?? 0) + gap;
    } else if (hrr >= 0.4) {
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

  // Strength sessions: add whatever sRPE load the heart rate missed.
  final strength = <DateTime, double>{};
  for (final session in strengthSessions) {
    final day = _localDay(session.start);
    if (day.isBefore(first) || session.start.isAfter(now)) continue;
    var captured = 0.0;
    final startMinute = session.start.millisecondsSinceEpoch ~/ 60000;
    for (var m = 0; m < session.durationMinutes; m++) {
      captured += perMinute[startMinute + m] ?? 0;
    }
    final expected = session.srpeLoad * srpeToTrimp;
    strength[day] = (strength[day] ?? 0) + math.max(0, expected - captured);
  }

  return [
    for (var offset = 0; offset < days; offset++)
      () {
        final date = first.add(Duration(days: offset));
        return DayStrain(
          date: date,
          cardioTrimp: cardio[date] ?? 0,
          strengthTrimp: strength[date] ?? 0,
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
      'Needs 14 days of wear to compare short- and long-term load.',
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
TrainingLoad trainingLoad(List<DayStrain> days) {
  const acuteLambda = 2 / (7 + 1);
  const chronicLambda = 2 / (28 + 1);
  final covered = days.where((day) => day.hasData).length;
  double? acute;
  double? chronic;
  for (final day in days) {
    final load = day.trimp;
    acute = acute == null
        ? load
        : acuteLambda * load + (1 - acuteLambda) * acute;
    chronic = chronic == null
        ? load
        : chronicLambda * load + (1 - chronicLambda) * chronic;
  }
  acute ??= 0;
  chronic ??= 0;
  final last7 = days.length <= 7 ? days : days.sublist(days.length - 7);
  final weekly = last7.fold<double>(0, (sum, day) => sum + day.trimp);
  final mean = weekly / math.max(1, last7.length);
  final variance = last7.isEmpty
      ? 0.0
      : last7.fold<double>(
              0,
              (sum, day) => sum + math.pow(day.trimp - mean, 2),
            ) /
            last7.length;
  final sd = math.sqrt(variance);
  final monotony = sd < 1 ? null : mean / sd;
  final ratio = covered < 14 || chronic < 5 ? null : acute / chronic;
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
    coveredDays: covered,
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

StrainTarget strainTarget({
  required int? recovery,
  required TrainingLoad? load,
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
  return StrainTarget(low: low, high: high, label: label, reason: reason);
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
