import 'dart:math' as math;

import '../data/health_connect_service.dart';
import 'estimates.dart';
import 'heart_signal.dart';

const defaultSleepNeedMinutes = 480;

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
/// can be logged as light sleep. Becel finds the sleeping heart-rate floor
/// for the night (20th percentile) and moves onset forward to the first
/// 5-minute run at or below floor + 8 bpm, trimming at most 2 hours. A
/// user-entered onset always wins.
AdjustedNight adjustOnset(
  SleepNight night, {
  required List<TimedValue> cleanedMinutes,
  DateTime? userOnset,
}) {
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
  if (inNight.length < 120) {
    return AdjustedNight(
      night: night,
      onset: night.start,
      asleepMinutes: night.minutes,
      onsetSource: OnsetSource.device,
    );
  }
  final sorted = inNight.map((s) => s.value).toList()..sort();
  final floor = sorted[(sorted.length * 0.2).floor()];
  final threshold = floor + 8;
  final limit = night.start.add(const Duration(hours: 2));
  var run = 0;
  DateTime? onset;
  for (final sample in inNight) {
    if (sample.at.isAfter(limit)) break;
    if (sample.value <= threshold) {
      run++;
      if (run >= 5) {
        onset = sample.at.subtract(const Duration(minutes: 4));
        break;
      }
    } else {
      run = 0;
    }
  }
  // Only correct when it matters (> 15 minutes) so normal latency is kept.
  if (onset == null || onset.difference(night.start).inMinutes <= 15) {
    return AdjustedNight(
      night: night,
      onset: night.start,
      asleepMinutes: night.minutes,
      onsetSource: OnsetSource.device,
    );
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
  });

  final AdjustedNight? lastNight;

  /// Main sleeps (≥ 3 h) in the last 7 days, oldest first.
  final List<AdjustedNight> nights;
  final int baselineNeed;
  final int strainNeed;
  final int debtNeed;
  final int debtMinutes;
  final int? midpointSdMinutes;
  final DateTime? recommendedBedtime;
  final DateTime? typicalWake;

  int get needTonight => baselineNeed + strainNeed + debtNeed;

  /// Last night against what was needed going into it (baseline + debt).
  int? get performancePercent {
    final night = lastNight;
    if (night == null) return null;
    return (night.asleepMinutes / math.max(1, baselineNeed + debtNeed) * 100)
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
}) {
  final baseline = (baselineNeedMinutes ?? defaultSleepNeedMinutes)
      .clamp(360, 600)
      .toInt();
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
    if (existing == null || session.minutes > existing.minutes)
      byDate[key] = session;
  }
  final nights = [
    for (final session in byDate.values)
      adjustOnset(
        session,
        cleanedMinutes: cleanedMinutes,
        userOnset: userOnsets[sleepKey(session)],
      ),
  ]..sort((a, b) => a.night.end.compareTo(b.night.end));

  final last =
      nights.isEmpty ||
          now.difference(nights.last.night.end) > const Duration(hours: 20)
      ? null
      : nights.last;

  // Debt from the three nights before tonight.
  final recent = nights.length <= 3
      ? nights
      : nights.sublist(nights.length - 3);
  final shortfall = recent.fold<int>(
    0,
    (sum, night) => sum + math.max(0, baseline - night.asleepMinutes),
  );
  final debtNeed = math.min(60, (shortfall / 3).round());
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
    strainNeed: strainNeed,
    debtNeed: debtNeed,
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
