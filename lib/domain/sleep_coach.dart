import 'dart:math' as math;

import '../data/health_connect_service.dart';
import 'estimates.dart';
import 'heart_signal.dart';

const defaultSleepNeedMinutes = 480;

enum BaselineSource { user, learned, standard }

enum OnsetSource { device, heartRate, user }

/// A night with Becel's onset correction applied. Source stages are never
/// edited; only the minutes Becel counts change.
class AdjustedNight {
  const AdjustedNight({
    required this.night,
    required this.onset,
    required this.asleepMinutes,
    required this.onsetSource,
  });

  final SleepNight night;
  final DateTime onset;
  final int asleepMinutes;
  final OnsetSource onsetSource;

  int get trimmedMinutes => math.max(0, night.minutes - asleepMinutes);
  int get inBedMinutes => night.end.difference(night.start).inMinutes;

  /// Asleep ÷ time in bed. Healthy adults typically sit at 85 % or above.
  int get efficiencyPercent => inBedMinutes <= 0
      ? 0
      : (asleepMinutes / inBedMinutes * 100).round().clamp(0, 100);

  List<AsleepInterval> get asleepIntervals => [
    for (final interval in night.asleepIntervals)
      if (interval.end.isAfter(onset))
        AsleepInterval(
          start: interval.start.isBefore(onset) ? onset : interval.start,
          end: interval.end,
        ),
  ];
}

/// Corrects sleep onset logged too early.
///
/// Wrist trackers infer sleep from stillness, so lying still while scrolling
/// can be logged as light sleep. Becel moves onset forward only while heart
/// rate stays at your measured pre-bed *awake* level (median of the 30
/// minutes before the session, minus 5 bpm) and above the night's sleeping
/// floor + 8 bpm, trimming at most 60 minutes. It never trims after hard
/// exercise in the previous 3 hours, when elevated sleeping HR is normal.
AdjustedNight adjustOnset(
  SleepNight night, {
  required List<TimedValue> cleanedMinutes,
  DateTime? userOnset,
  double? hardBpm,
}) {
  AdjustedNight unchanged() => AdjustedNight(
    night: night,
    onset: night.start,
    asleepMinutes: night.minutes,
    onsetSource: OnsetSource.device,
  );
  if (userOnset != null &&
      userOnset.isAfter(night.start) &&
      userOnset.isBefore(night.end)) {
    return AdjustedNight(
      night: night,
      onset: userOnset,
      asleepMinutes: _asleepAfter(night, userOnset),
      onsetSource: OnsetSource.user,
    );
  }
  final inNight = [
    for (final sample in cleanedMinutes)
      if (!sample.at.isBefore(night.start) && sample.at.isBefore(night.end))
        sample,
  ];
  if (inNight.length < 120) return unchanged();
  final preBed = [
    for (final sample in cleanedMinutes)
      if (sample.at.isBefore(night.start) &&
          !sample.at.isBefore(
            night.start.subtract(const Duration(minutes: 30)),
          ))
        sample.value,
  ];
  if (preBed.length < 10) return unchanged();
  if (hardBpm != null &&
      cleanedMinutes.any(
        (s) =>
            s.value >= hardBpm &&
            s.at.isBefore(night.start) &&
            s.at.isAfter(night.start.subtract(const Duration(hours: 3))),
      )) {
    return unchanged();
  }
  final sorted = inNight.map((s) => s.value).toList()..sort();
  final floor = sorted[(sorted.length * 0.2).floor()];
  final awakeLevel = medianOf(preBed) - 5;
  final threshold = math.max(floor + 8, awakeLevel);
  if (awakeLevel <= floor + 8) return unchanged();
  final limit = night.start.add(const Duration(minutes: 60));
  DateTime? onset;
  for (final sample in inNight) {
    if (sample.at.isAfter(limit)) {
      onset = limit;
      break;
    }
    if (sample.value < threshold) {
      onset = sample.at;
      break;
    }
  }
  // Only correct when it matters (> 15 minutes) so normal latency is kept.
  if (onset == null || onset.difference(night.start).inMinutes <= 15) {
    return unchanged();
  }
  return AdjustedNight(
    night: night,
    onset: onset,
    asleepMinutes: _asleepAfter(night, onset),
    onsetSource: OnsetSource.heartRate,
  );
}

int _asleepAfter(SleepNight night, DateTime onset) {
  if (night.asleepIntervals.isEmpty) {
    final trimmed = onset.difference(night.start).inMinutes;
    return math.max(0, night.minutes - trimmed);
  }
  var total = 0;
  for (final interval in night.asleepIntervals) {
    final start = interval.start.isBefore(onset) ? onset : interval.start;
    if (interval.end.isAfter(start)) {
      total += interval.end.difference(start).inMinutes;
    }
  }
  return total;
}

class SleepCoach {
  const SleepCoach({
    required this.lastNight,
    required this.nights,
    required this.baselineNeed,
    required this.strainNeed,
    required this.debtNeed,
    required this.debtMinutes,
    required this.midpointSdMinutes,
    required this.recommendedBedtime,
    required this.typicalWake,
    this.baselineSource = BaselineSource.standard,
    this.debtGoingIn = 0,
  });

  final AdjustedNight? lastNight;

  /// Main sleeps (≥ 3 h) in the last 7 days, oldest first.
  final List<AdjustedNight> nights;
  final int baselineNeed;
  final BaselineSource baselineSource;
  final int strainNeed;

  /// Repayment added to tonight's need (shortfall of the last 3 nights).
  final int debtNeed;

  /// Repayment that applied going into last night (the 3 nights before it).
  /// Last night is graded against this, never against its own shortfall.
  final int debtGoingIn;
  final int debtMinutes;
  final int? midpointSdMinutes;
  final DateTime? recommendedBedtime;
  final DateTime? typicalWake;

  int get needTonight => baselineNeed + strainNeed + debtNeed;
  int get needLastNight => baselineNeed + debtGoingIn;

  /// Last night against what was needed going into it.
  int? get performancePercent {
    final night = lastNight;
    if (night == null) return null;
    return (night.asleepMinutes / math.max(1, needLastNight) * 100)
        .round()
        .clamp(0, 100);
  }

  /// 100 at ≤ 15 min midpoint SD, falling ~1 point per extra minute; 45 min
  /// SD (a common irregularity cut-off) reads ~70.
  int? get consistencyPercent => midpointSdMinutes == null
      ? null
      : (100 - math.max(0, midpointSdMinutes! - 15)).clamp(0, 100).toInt();

  int? get averageAsleep => nights.isEmpty
      ? null
      : (nights.fold<int>(0, (s, n) => s + n.asleepMinutes) / nights.length)
            .round();
}

/// Builds tonight's sleep plan.
///
/// Need = baseline (default 8 h, user-editable) + strain add-on (up to
/// 45 min after a day above strain 10) + repayment of one third of the last
/// 3 nights' shortfall (capped at 60 min). This mirrors how WHOOP and Bevel
/// describe sleep need; the constants are Becel's and are shown in the app.
SleepCoach buildSleepCoach({
  required List<SleepNight> sessions,
  required List<TimedValue> cleanedMinutes,
  required DateTime now,
  double? yesterdayStrain,
  int? baselineNeedMinutes,
  Map<String, DateTime> userOnsets = const {},
  bool correctOnset = true,
  double? hardBpm,
}) {
  // Baseline: the user's setting, else learned from their own upper-quartile
  // main sleep over 28 days (what they get when life allows), clamped to the
  // adult 7–9 h range. A fixed 8 h would put natural 7 h sleepers in
  // permanent "debt".
  // Learn in the same units as debt (onset-corrected minutes), and skip
  // rebound nights that follow a short night (< 6 h), which overstate need.
  // One main sleep per wake date (the longest), so a split night is not
  // counted twice. Newest first, so element i + 1 is the night before i.
  final longestPerDate = <String, SleepNight>{};
  for (final session in sessions) {
    if (session.minutes < 180 ||
        !session.end.isAfter(now.subtract(const Duration(days: 28))) ||
        session.end.isAfter(now)) {
      continue;
    }
    final key = sleepKey(session);
    final existing = longestPerDate[key];
    if (existing == null || session.minutes > existing.minutes) {
      longestPerDate[key] = session;
    }
  }
  final newestFirst = longestPerDate.values.toList()
    ..sort((a, b) => b.end.compareTo(a.end));
  final recentMains = [
    for (final session in newestFirst)
      adjustOnset(
        session,
        cleanedMinutes: correctOnset ? cleanedMinutes : const [],
        hardBpm: hardBpm,
      ).asleepMinutes,
  ];
  final learnFrom = <double>[
    for (var i = 0; i < recentMains.length; i++)
      if (i + 1 >= recentMains.length || recentMains[i + 1] >= 360)
        recentMains[i].toDouble(),
  ]..sort();
  final BaselineSource source;
  final int baseline;
  if (baselineNeedMinutes != null) {
    source = BaselineSource.user;
    baseline = baselineNeedMinutes.clamp(360, 600).toInt();
  } else if (learnFrom.length >= 7) {
    source = BaselineSource.learned;
    baseline = learnFrom[(learnFrom.length * 0.75).floor()]
        .clamp(420, 540)
        .round();
  } else {
    source = BaselineSource.standard;
    baseline = defaultSleepNeedMinutes;
  }
  final cutoff = now.subtract(const Duration(days: 7));
  final mains = [
    for (final session in sessions)
      if (session.minutes >= 180 &&
          session.end.isAfter(cutoff) &&
          !session.end.isAfter(now))
        session,
  ]..sort((a, b) => a.end.compareTo(b.end));
  // One main sleep per wake date: keep the longest.
  final byDate = <String, SleepNight>{};
  for (final session in mains) {
    final key = sleepKey(session);
    final existing = byDate[key];
    if (existing == null || session.minutes > existing.minutes) {
      byDate[key] = session;
    }
  }
  final nights = [
    for (final session in byDate.values)
      adjustOnset(
        session,
        cleanedMinutes: correctOnset ? cleanedMinutes : const [],
        userOnset: userOnsets[sleepKey(session)],
        hardBpm: hardBpm,
      ),
  ]..sort((a, b) => a.night.end.compareTo(b.night.end));

  final last =
      nights.isEmpty ||
          now.difference(nights.last.night.end) > const Duration(hours: 20)
      ? null
      : nights.last;

  int shortfallOf(List<AdjustedNight> list) => list.fold<int>(
    0,
    (sum, night) => sum + math.max(0, baseline - night.asleepMinutes),
  );
  List<AdjustedNight> lastThree(List<AdjustedNight> list) =>
      list.length <= 3 ? list : list.sublist(list.length - 3);
  // Tonight: the three most recent nights. Going into last night: the three
  // before it.
  final shortfall = shortfallOf(lastThree(nights));
  final debtNeed = math.min(60, (shortfall / 3).round());
  final before = last == null ? nights : nights.sublist(0, nights.length - 1);
  final debtGoingIn = math.min(
    60,
    (shortfallOf(lastThree(before)) / 3).round(),
  );
  final strain = yesterdayStrain ?? 0;
  final strainNeed = (math.max(0, strain - 10) / 11 * 45)
      .round()
      .clamp(0, 45)
      .toInt();

  int? midpointSd;
  DateTime? bedtime;
  DateTime? wake;
  if (nights.length >= 3) {
    final midpoints = [
      for (final night in nights)
        _minutesFromNoon(
          night.onset.add(night.night.end.difference(night.onset) ~/ 2),
        ),
    ];
    midpointSd = _sd(midpoints).round();
    final wakes = [
      for (final night in nights) _minutesFromNoon(night.night.end),
    ];
    final typicalWakeMinutes = medianOf(wakes).round();
    final latency = medianOf([
      for (final night in nights)
        (night.inBedMinutes - night.asleepMinutes).toDouble(),
    ]).round();
    final clock = (typicalWakeMinutes + 720) % 1440;
    var nextWake = DateTime(
      now.year,
      now.month,
      now.day,
      clock ~/ 60,
      clock % 60,
    );
    if (!nextWake.isAfter(now)) {
      nextWake = DateTime(
        now.year,
        now.month,
        now.day + 1,
        clock ~/ 60,
        clock % 60,
      );
    }
    wake = nextWake;
    bedtime = nextWake.subtract(
      Duration(
        minutes: baseline + strainNeed + debtNeed + latency.clamp(0, 90),
      ),
    );
  }

  return SleepCoach(
    lastNight: last,
    nights: nights,
    baselineNeed: baseline,
    baselineSource: source,
    strainNeed: strainNeed,
    debtNeed: debtNeed,
    debtGoingIn: debtGoingIn,
    debtMinutes: shortfall,
    midpointSdMinutes: midpointSd,
    recommendedBedtime: bedtime,
    typicalWake: wake,
  );
}

/// Stable key for a main sleep: its local wake date.
String sleepKey(SleepNight night) {
  final local = night.end.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

double _minutesFromNoon(DateTime time) {
  final local = time.toLocal();
  final minutes = local.hour * 60 + local.minute - 720;
  return (minutes < 0 ? minutes + 1440 : minutes).toDouble();
}

double _sd(List<double> values) {
  if (values.length < 2) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.fold<double>(0, (s, v) => s + (v - mean) * (v - mean)) /
      (values.length - 1);
  return math.sqrt(variance);
}
