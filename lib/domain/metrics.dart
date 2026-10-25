import 'dart:math' as math;

import 'estimates.dart';
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

class EnergyEstimate {
  const EnergyEstimate({
    required this.basalKcal,
    required this.activeKcal,
    required this.totalKcal,
    required this.lowKcal,
    required this.highKcal,
    required this.heartCoverageMinutes,
    required this.stepCount,
    required this.usedHeartRate,
    required this.confidence,
    required this.method,
    this.deviceActiveKcal,
    this.deviceTotalKcal,
  });

  final int basalKcal;
  final int activeKcal;
  final int totalKcal;
  final int lowKcal;
  final int highKcal;
  final int heartCoverageMinutes;
  final int? stepCount;
  final bool usedHeartRate;
  final MetricConfidence confidence;
  final String method;
  final int? deviceActiveKcal;
  final int? deviceTotalKcal;
}

EnergyEstimate? estimateDailyEnergy({
  required BodyProfile profile,
  required List<TimedValue> todayHeartRate,
  required int? stepCount,
  required DateTime now,
  int? deviceActiveKcal,
  int? deviceTotalKcal,
}) {
  if (!profile.hasEnergyInputs) return null;
  final age = profile.age!;
  final weight = profile.weightKg!;
  final height = profile.heightCm!;
  final sex = profile.sex!;
  final bmr = _mifflinStJeor(
    weight: weight,
    height: height,
    age: age,
    sex: sex,
  );
  final localNow = now.toLocal();
  final start = DateTime(localNow.year, localNow.month, localNow.day);
  final samples = todayHeartRate.where((sample) {
    final at = sample.at.toLocal();
    return !at.isBefore(start) && !at.isAfter(localNow);
  }).toList()..sort((a, b) => a.at.compareTo(b.at));

  final heart = _activeEnergyFromHeartRate(
    samples: samples,
    bmr: bmr,
    weight: weight,
    age: age,
    sex: sex,
  );
  final steps = stepCount == null || stepCount < 0 ? null : stepCount;
  final stepActive = steps == null
      ? 0.0
      : _activeEnergyFromSteps(
          steps: steps,
          weight: weight,
          heightCm: height,
          sex: sex,
        );
  final heartActive = heart.kcal;
  final active = math.max(heartActive, stepActive);
  final coverage = heart.minutes;
  final usedHeartRate = heartActive >= stepActive && coverage >= 30;
  final confidence = coverage >= 480 && steps != null
      ? MetricConfidence.high
      : coverage >= 180 || (steps != null && steps >= 1000)
      ? MetricConfidence.medium
      : MetricConfidence.low;
  final uncertainty =
      active *
          switch (confidence) {
            MetricConfidence.high => 0.12,
            MetricConfidence.medium => 0.20,
            MetricConfidence.low => 0.35,
          } +
      bmr * 0.05;
  final total = (bmr + active).round();
  final method = usedHeartRate
      ? 'Becel estimate: Mifflin–St Jeor resting energy plus net heart-rate '
            'energy from Fitbit Air samples. Gaps use step-based walking cost. '
            'This is an estimate, not a measured calorimeter value.'
      : 'Becel estimate: Mifflin–St Jeor resting energy plus walking energy '
            'from steps, height, and body weight. Heart-rate coverage was too '
            'low to use pulse-based energy for most of today.';

  return EnergyEstimate(
    basalKcal: bmr.round(),
    activeKcal: active.round(),
    totalKcal: total,
    lowKcal: math.max(bmr.round(), (total - uncertainty).round()),
    highKcal: (total + uncertainty).round(),
    heartCoverageMinutes: coverage.round(),
    stepCount: steps,
    usedHeartRate: usedHeartRate,
    confidence: confidence,
    method: method,
    deviceActiveKcal: deviceActiveKcal,
    deviceTotalKcal: deviceTotalKcal,
  );
}

double _mifflinStJeor({
  required double weight,
  required double height,
  required int age,
  required BiologicalSex sex,
}) {
  final base = 10 * weight + 6.25 * height - 5 * age;
  return sex == BiologicalSex.male ? base + 5 : base - 161;
}

({double kcal, double minutes}) _activeEnergyFromHeartRate({
  required List<TimedValue> samples,
  required double bmr,
  required double weight,
  required int age,
  required BiologicalSex sex,
}) {
  var kcal = 0.0;
  var minutes = 0.0;
  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final current = samples[index];
    final gap = current.at.difference(previous.at).inSeconds / 60;
    if (gap < 0.5 || gap > 10) continue;
    final hr = (previous.value + current.value) / 2;
    if (hr < 40 || hr > 220) continue;
    final totalPerMinute = sex == BiologicalSex.male
        ? (-55.0969 + 0.6309 * hr + 0.1988 * weight + 0.2017 * age) / 4.184
        : (-20.4022 + 0.4472 * hr - 0.1263 * weight + 0.074 * age) / 4.184;
    final restingPerMinute = bmr / 1440;
    kcal += math.max(0, totalPerMinute - restingPerMinute) * gap;
    minutes += gap;
  }
  return (kcal: kcal, minutes: minutes);
}

double _activeEnergyFromSteps({
  required int steps,
  required double weight,
  required double heightCm,
  required BiologicalSex sex,
}) {
  final strideMeters =
      heightCm / 100 * (sex == BiologicalSex.male ? 0.415 : 0.413);
  final distanceKm = steps * strideMeters / 1000;
  return 0.53 * weight * distanceKm;
}

class DailyLoad {
  const DailyLoad({
    required this.date,
    required this.load,
    required this.minutes,
    required this.vigorousMinutes,
  });

  final DateTime date;
  final double load;
  final double minutes;
  final double vigorousMinutes;
}

class TrainingLoadEstimate {
  const TrainingLoadEstimate({
    required this.weeklyLoad,
    required this.daily,
    required this.hardDays,
    required this.vigorousMinutes,
    required this.coverageHours,
    required this.confidence,
    required this.method,
  });

  final double weeklyLoad;
  final List<DailyLoad> daily;
  final int hardDays;
  final double vigorousMinutes;
  final double coverageHours;
  final MetricConfidence confidence;
  final String method;
}

TrainingLoadEstimate? estimateTrainingLoad({
  required List<TimedValue> weekHeartRate,
  required int? age,
  required double? restingHr,
  required DateTime now,
  int days = 7,
}) {
  if (age == null || age < 18 || age > 100) return null;
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final first = today.subtract(Duration(days: days - 1));
  final samples = weekHeartRate.where((sample) {
    final at = sample.at.toLocal();
    return !at.isBefore(first) && !at.isAfter(localNow);
  }).toList()..sort((a, b) => a.at.compareTo(b.at));
  if (samples.length < 2) return null;
  final maxHr = 208 - 0.7 * age;
  final rest = (restingHr ?? 60).clamp(30, 100).toDouble();
  final reserve = math.max(20, maxHr - rest);
  final byDay = <DateTime, ({double load, double minutes, double vigorous})>{};
  var coverageMinutes = 0.0;

  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final current = samples[index];
    final gap = current.at.difference(previous.at).inSeconds / 60;
    if (gap < 0.5 || gap > 10) continue;
    final at = current.at.toLocal();
    final day = DateTime(at.year, at.month, at.day);
    final avg = (previous.value + current.value) / 2;
    final intensity = (avg - rest) / reserve;
    final weight = intensity < 0.5
        ? 0
        : intensity < 0.6
        ? 1
        : intensity < 0.7
        ? 2
        : intensity < 0.8
        ? 3
        : intensity < 0.9
        ? 4
        : 5;
    final entry = byDay[day] ?? (load: 0.0, minutes: 0.0, vigorous: 0.0);
    byDay[day] = (
      load: entry.load + gap * weight,
      minutes: entry.minutes + gap,
      vigorous: entry.vigorous + (weight >= 4 ? gap : 0),
    );
    coverageMinutes += gap;
  }

  final daily = <DailyLoad>[];
  for (var offset = 0; offset < days; offset++) {
    final date = first.add(Duration(days: offset));
    final entry = byDay[date];
    daily.add(
      DailyLoad(
        date: date,
        load: entry?.load ?? 0,
        minutes: entry?.minutes ?? 0,
        vigorousMinutes: entry?.vigorous ?? 0,
      ),
    );
  }
  final weeklyLoad = daily.fold<double>(0, (sum, day) => sum + day.load);
  final coverageHours = coverageMinutes / 60;
  final confidence = coverageHours >= 14
      ? MetricConfidence.high
      : coverageHours >= 7
      ? MetricConfidence.medium
      : MetricConfidence.low;

  return TrainingLoadEstimate(
    weeklyLoad: weeklyLoad,
    daily: daily,
    hardDays: daily.where((day) => day.vigorousMinutes >= 20).length,
    vigorousMinutes: daily.fold<double>(
      0,
      (sum, day) => sum + day.vigorousMinutes,
    ),
    coverageHours: coverageHours,
    confidence: confidence,
    method:
        'Becel load: Edwards heart-rate TRIMP over 7 local days. Minutes are '
        'weighted 1–5 by heart-rate reserve using your age and resting heart '
        'rate. It counts pulse intensity, not sport type or strength work.',
  );
}

class FitnessAgeEstimate {
  const FitnessAgeEstimate({
    required this.vo2Max,
    required this.vo2MaxEstimated,
    required this.fitnessAge,
    required this.lowAge,
    required this.highAge,
    required this.chronologicalAge,
    required this.confidence,
    required this.method,
  });

  final double vo2Max;
  final bool vo2MaxEstimated;
  final int fitnessAge;
  final int lowAge;
  final int highAge;
  final int chronologicalAge;
  final MetricConfidence confidence;
  final String method;

  int get deltaYears => fitnessAge - chronologicalAge;
}

FitnessAgeEstimate? estimateFitnessAge({
  required BodyProfile profile,
  required double? vo2Max,
  required List<TimedValue> restingHrSamples,
  required DateTime now,
}) {
  final age = profile.age;
  final sex = profile.sex;
  if (age == null || age < 18 || age > 100 || sex == null) return null;
  final cutoff = now.subtract(const Duration(days: 30));
  final resting = restingHrSamples
      .where(
        (sample) =>
            sample.at.isAfter(cutoff) &&
            sample.value >= 30 &&
            sample.value <= 120,
      )
      .map((sample) => sample.value)
      .toList();
  final measured = vo2Max != null && vo2Max > 10 && vo2Max < 90;
  var value = measured ? vo2Max : null;
  var estimated = false;
  if (value == null && resting.isNotEmpty) {
    final maxHr = 208 - 0.7 * age;
    value = 15.3 * (maxHr / _median(resting));
    estimated = true;
  }
  if (value == null || value < 10 || value > 90) return null;
  final anchor = sex == BiologicalSex.male ? 50.0 : 40.0;
  final slope = sex == BiologicalSex.male ? 0.45 : 0.35;
  final rawAge = 20 + (anchor - value) / slope;
  final fitnessAge = rawAge.round().clamp(18, 100);
  final spread = measured ? 3 : 5;
  final confidence = measured && profile.isComplete
      ? MetricConfidence.high
      : resting.length >= 10
      ? MetricConfidence.medium
      : MetricConfidence.low;

  return FitnessAgeEstimate(
    vo2Max: value,
    vo2MaxEstimated: estimated,
    fitnessAge: fitnessAge,
    lowAge: (fitnessAge - spread).clamp(18, 100),
    highAge: (fitnessAge + spread).clamp(18, 100),
    chronologicalAge: age,
    confidence: confidence,
    method: measured
        ? 'Fitness age is the age whose typical cardiorespiratory fitness '
              'matches your latest Fitbit Air VO₂ max. It is a fitness '
              'reference, not a biological age or health score.'
        : 'VO₂ max was not available, so Becel estimated it from your resting '
              'heart rate and age. Fitness age is the age whose typical '
              'cardiorespiratory fitness matches that estimate. It is a '
              'fitness reference, not a biological age or health score.',
  );
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}
