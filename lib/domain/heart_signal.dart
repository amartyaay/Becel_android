import 'dart:math' as math;

import 'energy.dart' show StepBucket;
import 'estimates.dart';

/// Minute-resolution heart rate after artifact rejection.
class CleanHeartRate {
  const CleanHeartRate({
    required this.samples,
    required this.corrected,
    this.cadenceLocked = 0,
  });

  final List<TimedValue> samples;

  /// Minutes replaced by the local median because they were isolated spikes.
  final int corrected;

  /// Minutes dropped because HR was locked onto step cadence.
  final int cadenceLocked;

  int get artifactMinutes => corrected + cadenceLocked;
}

/// Rejects optical-HR artifacts with a centred Hampel filter.
///
/// Wrist optical sensors can lock onto cadence or ambient light and read
/// 20–40 bpm high for a minute or two. A sample is replaced by the local
/// median when it sits more than 3 scaled MADs *and* more than 15 bpm away
/// from the median of its ±[halfWindow] neighbours, so genuine sustained
/// intervals survive while isolated spikes do not.
CleanHeartRate cleanHeartRate(
  List<TimedValue> raw, {
  int halfWindow = 3,
  double minDeviationBpm = 15,
}) {
  final valid = [
    for (final sample in raw)
      if (sample.value >= 30 && sample.value <= 225) sample,
  ]..sort((a, b) => a.at.compareTo(b.at));
  if (valid.length < 2 * halfWindow + 1) {
    return CleanHeartRate(samples: valid, corrected: 0);
  }
  final cleaned = <TimedValue>[];
  var corrected = 0;
  for (var index = 0; index < valid.length; index++) {
    final from = math.max(0, index - halfWindow);
    final to = math.min(valid.length - 1, index + halfWindow);
    final window = <double>[];
    for (var j = from; j <= to; j++) {
      // Only neighbours within ±halfWindow minutes belong to the same bout.
      if (valid[j].at.difference(valid[index].at).inMinutes.abs() <=
          halfWindow) {
        window.add(valid[j].value);
      }
    }
    if (window.length < 5) {
      cleaned.add(valid[index]);
      continue;
    }
    final median = medianOf(window);
    final mad = medianOf([for (final v in window) (v - median).abs()]);
    final deviation = (valid[index].value - median).abs();
    if (deviation > math.max(minDeviationBpm, 3 * 1.4826 * mad)) {
      cleaned.add(TimedValue(at: valid[index].at, value: median));
      corrected++;
    } else {
      cleaned.add(valid[index]);
    }
  }
  return CleanHeartRate(samples: cleaned, corrected: corrected);
}

/// Removes stretches where the optical sensor locked onto step cadence.
///
/// Wrist PPG can lock onto arm swing and report cadence as heart rate,
/// typically for 5–20 minutes, which a short Hampel window cannot catch. A
/// lock needs all three: HR jumps ≥ 25 bpm within ~2 minutes, then tracks
/// step cadence (±5) for at least five minutes, then falls ≥ 20 bpm within
/// a minute while cadence carries on. Real efforts (run starts, intervals)
/// can jump and sit near cadence, but when they end the steps end too, so
/// they are kept. Flagged minutes are dropped, never replaced.
CleanHeartRate excludeCadenceLock(
  CleanHeartRate input,
  List<StepBucket> steps, {
  double jumpBpm = 25,
  double tolerance = 5,
  double exitDropBpm = 20,
  int minMinutes = 5,
}) {
  if (steps.isEmpty || input.samples.length < 10) return input;
  final cadence = <int, double>{};
  for (final bucket in steps) {
    final start = bucket.start.millisecondsSinceEpoch ~/ 60000;
    for (var m = 0; m < 5; m++) {
      cadence[start + m] = bucket.steps / 5;
    }
  }
  final samples = input.samples;
  final excluded = <int>{};
  var index = 3;
  while (index < samples.length) {
    final at = samples[index].at;
    final before = [
      for (var j = index - 3; j < index; j++)
        if (at.difference(samples[j].at).inMinutes <= 3) samples[j].value,
    ];
    final jumped =
        before.isNotEmpty && samples[index].value - medianOf(before) >= jumpBpm;
    if (!jumped) {
      index++;
      continue;
    }
    var end = index;
    while (end < samples.length) {
      final minute = samples[end].at.millisecondsSinceEpoch ~/ 60000;
      final spm = cadence[minute];
      if (spm == null || spm < 50) break;
      if ((samples[end].value - spm).abs() > tolerance) break;
      end++;
    }
    // A sensor lock ends with an instant fall to the true rate while the
    // person keeps moving. Stopping a real effort also drops HR fast (1-min
    // HR recovery is often 20–40 bpm), but cadence stops with it, so the
    // exit minute must keep ≥ 90 % of the bout's cadence.
    double? boutCadence;
    if (end > index) {
      var sum = 0.0;
      for (var j = index; j < end; j++) {
        sum += cadence[samples[j].at.millisecondsSinceEpoch ~/ 60000] ?? 0;
      }
      boutCadence = sum / (end - index);
    }
    final exitCadence = end < samples.length
        ? cadence[samples[end].at.millisecondsSinceEpoch ~/ 60000]
        : null;
    final abruptExit =
        end < samples.length &&
        boutCadence != null &&
        exitCadence != null &&
        exitCadence >= 0.9 * boutCadence &&
        samples[end].at.difference(samples[end - 1].at).inMinutes <= 2 &&
        samples[end - 1].value - samples[end].value >= exitDropBpm;
    if (end - index >= minMinutes && abruptExit) {
      for (var j = index; j < end; j++) {
        excluded.add(j);
      }
      index = end;
    } else {
      index++;
    }
  }
  if (excluded.isEmpty) return input;
  return CleanHeartRate(
    samples: [
      for (var j = 0; j < samples.length; j++)
        if (!excluded.contains(j)) samples[j],
    ],
    corrected: input.corrected,
    cadenceLocked: input.cadenceLocked + excluded.length,
  );
}

enum MaxHrSource { tested, observed, predicted }

class MaxHeartRate {
  const MaxHeartRate({
    required this.bpm,
    required this.source,
    required this.predictedBpm,
    this.observedBpm,
  });

  final int bpm;
  final MaxHrSource source;
  final int predictedBpm;
  final int? observedBpm;

  String get sourceLabel => switch (source) {
    MaxHrSource.tested => 'your tested max',
    MaxHrSource.observed => 'highest sustained HR seen in 28 days',
    MaxHrSource.predicted => 'age prediction (Tanaka)',
  };
}

/// Personal maximum heart rate.
///
/// Priority: user-entered tested max → highest value held for at least
/// three consecutive minutes in cleaned data (if above the age prediction) →
/// Tanaka's 208 − 0.7 × age. Age predictions carry roughly ±10 bpm error,
/// which can shift every zone; observed peaks fix that for trained users.
MaxHeartRate? personalMaxHeartRate({
  required int? age,
  int? tested,
  List<TimedValue> cleanedMinutes = const [],
}) {
  if (age == null || age < 13 || age > 100) {
    if (tested != null && tested >= 120 && tested <= 230) {
      return MaxHeartRate(
        bpm: tested,
        source: MaxHrSource.tested,
        predictedBpm: tested,
      );
    }
    return null;
  }
  final predicted = (208 - 0.7 * age).round();
  if (tested != null && tested >= 120 && tested <= 230) {
    return MaxHeartRate(
      bpm: tested,
      source: MaxHrSource.tested,
      predictedBpm: predicted,
    );
  }
  int? observed;
  for (var index = 2; index < cleanedMinutes.length; index++) {
    final a = cleanedMinutes[index - 2];
    final c = cleanedMinutes[index];
    if (c.at.difference(a.at).inMinutes > 3) continue;
    final sustained = math.min(
      a.value,
      math.min(cleanedMinutes[index - 1].value, c.value),
    );
    if (observed == null || sustained > observed) observed = sustained.round();
  }
  // Cap implausible values: more than 15 bpm above prediction needs a test.
  if (observed != null && observed > predicted) {
    return MaxHeartRate(
      bpm: math.min(observed, predicted + 15),
      source: MaxHrSource.observed,
      predictedBpm: predicted,
      observedBpm: observed,
    );
  }
  return MaxHeartRate(
    bpm: predicted,
    source: MaxHrSource.predicted,
    predictedBpm: predicted,
    observedBpm: observed,
  );
}

/// Five Karvonen (heart-rate-reserve) training zones.
class HeartZones {
  const HeartZones({required this.restingBpm, required this.maxBpm});

  final double restingBpm;
  final int maxBpm;

  static const lowerBounds = [0.50, 0.60, 0.70, 0.80, 0.90];
  static const names = [
    'Z1 Recovery',
    'Z2 Endurance',
    'Z3 Tempo',
    'Z4 Threshold',
    'Z5 Max',
  ];

  double get reserve => math.max(20, maxBpm - restingBpm);

  double fraction(double bpm) => (bpm - restingBpm) / reserve;

  int bpmAt(double fraction) => (restingBpm + fraction * reserve).round();

  /// Zone index 0–4, or -1 below Z1.
  int zoneOf(double bpm) {
    final f = fraction(bpm);
    for (var index = lowerBounds.length - 1; index >= 0; index--) {
      if (f >= lowerBounds[index]) return index;
    }
    return -1;
  }

  String rangeLabel(int zone) {
    final low = bpmAt(lowerBounds[zone]);
    final high = zone == 4 ? maxBpm : bpmAt(lowerBounds[zone + 1]) - 1;
    return '$low–$high bpm';
  }
}

double medianOf(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}
