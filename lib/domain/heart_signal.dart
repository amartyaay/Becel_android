import 'dart:math' as math;

import 'estimates.dart';

/// Minute-resolution heart rate after artifact rejection.
class CleanHeartRate {
  const CleanHeartRate({required this.samples, required this.corrected});

  final List<TimedValue> samples;

  /// Minutes replaced by the local median because they were isolated spikes.
  final int corrected;
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
    'Z5 VO₂max',
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
