import 'dart:math' as math;

import 'heart_signal.dart';
import 'profile.dart';

enum MetricConfidence { high, medium, low }

extension MetricConfidenceLabel on MetricConfidence {
  String get label => switch (this) {
    MetricConfidence.high => 'Higher confidence',
    MetricConfidence.medium => 'Moderate confidence',
    MetricConfidence.low => 'Low confidence',
  };

  String get shortLabel => switch (this) {
    MetricConfidence.high => 'HIGH',
    MetricConfidence.medium => 'MEDIUM',
    MetricConfidence.low => 'LOW',
  };
}

/// Resting-HR cardio-fitness estimate (Uth et al., 2004).
///
/// VO₂max ≈ 15.3 × HRmax ÷ HRrest. With a measured HRmax the error is about
/// ±10 %; with an age-predicted HRmax (±10 bpm) it roughly doubles. Becel
/// therefore shows a range, never a single "fitness age".
class CardioFitness {
  const CardioFitness({
    required this.vo2Max,
    required this.low,
    required this.high,
    required this.maxHrSource,
    required this.category,
  });

  final double vo2Max;
  final double low;
  final double high;
  final MaxHrSource maxHrSource;

  /// Age/sex fitness band for the whole range: one band, two adjacent bands
  /// ("Fair to Good"), or null when the range is too wide to call.
  final String? category;

  MetricConfidence get confidence => maxHrSource == MaxHrSource.predicted
      ? MetricConfidence.low
      : MetricConfidence.medium;
}

CardioFitness? estimateCardioFitness({
  required BodyProfile? profile,
  required MaxHeartRate? maxHr,
  required double? restingBpm,
}) {
  if (maxHr == null || restingBpm == null || restingBpm < 30) return null;
  final vo2 = 15.3 * maxHr.bpm / restingBpm;
  if (vo2 < 15 || vo2 > 90) return null;
  final error = maxHr.source == MaxHrSource.predicted ? 0.20 : 0.10;
  final low = vo2 * (1 - error);
  final high = vo2 * (1 + error);
  final from = _band(low, profile);
  final to = _band(high, profile);
  return CardioFitness(
    vo2Max: vo2,
    low: low,
    high: high,
    maxHrSource: maxHr.source,
    category: from == to
        ? _bandNames[from]
        : to - from == 1
        ? '${_bandNames[from]} to ${_bandNames[to].toLowerCase()}'
        : null,
  );
}

const _bandNames = ['Below average', 'Fair', 'Good', 'Excellent', 'Superior'];

/// Coarse ACSM-style bands for adults 30–39; shifts ~3 ml/kg/min per decade.
/// Returns an index into [_bandNames].
int _band(double vo2, BodyProfile? profile) {
  final age = profile?.age ?? 35;
  final female = profile?.sex == BiologicalSex.female;
  final shift = (age - 35) / 10 * 3 + (female ? 7 : 0);
  final adjusted = vo2 + math.max(-12, math.min(12, shift));
  if (adjusted >= 52) return 4;
  if (adjusted >= 46) return 3;
  if (adjusted >= 41) return 2;
  if (adjusted >= 36) return 1;
  return 0;
}
