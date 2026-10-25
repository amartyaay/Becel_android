import 'package:becel/domain/estimates.dart';
import 'package:becel/domain/metrics.dart';
import 'package:becel/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const male = BodyProfile(
    age: 35,
    sex: BiologicalSex.male,
    heightCm: 180,
    weightKg: 80,
  );

  group('estimateDailyEnergy', () {
    test('uses Mifflin-St Jeor resting energy and step-based walking cost', () {
      final estimate = estimateDailyEnergy(
        profile: male,
        todayHeartRate: const [],
        stepCount: 10000,
        now: DateTime(2026, 10, 25, 18),
      )!;

      expect(estimate.basalKcal, 1755);
      expect(estimate.activeKcal, 317);
      expect(estimate.totalKcal, 2072);
      expect(estimate.usedHeartRate, isFalse);
      expect(estimate.confidence, MetricConfidence.medium);
      expect(estimate.lowKcal, lessThan(estimate.totalKcal));
      expect(estimate.highKcal, greaterThan(estimate.totalKcal));
    });

    test('uses heart-rate energy when coverage beats the step estimate', () {
      final start = DateTime(2026, 10, 25, 8);
      final samples = [
        for (var index = 0; index <= 48; index++)
          TimedValue(at: start.add(Duration(minutes: index * 5)), value: 90),
      ];
      final estimate = estimateDailyEnergy(
        profile: male,
        todayHeartRate: samples,
        stepCount: 1000,
        now: DateTime(2026, 10, 25, 18),
      )!;

      expect(estimate.usedHeartRate, isTrue);
      expect(estimate.activeKcal, greaterThan(1000));
      expect(estimate.heartCoverageMinutes, 240);
      expect(estimate.confidence, MetricConfidence.medium);
    });

    test('returns null without a complete body profile', () {
      final estimate = estimateDailyEnergy(
        profile: const BodyProfile(age: 35),
        todayHeartRate: const [],
        stepCount: 5000,
        now: DateTime(2026, 10, 25, 18),
      );

      expect(estimate, isNull);
    });
  });

  group('estimateTrainingLoad', () {
    test('weights minutes by heart-rate reserve across seven days', () {
      final start = DateTime(2026, 10, 19, 8);
      final samples = <TimedValue>[];
      for (var day = 0; day < 7; day++) {
        for (var minute = 0; minute <= 60; minute += 5) {
          samples.add(
            TimedValue(
              at: start.add(Duration(days: day, minutes: minute)),
              value: 170,
            ),
          );
        }
      }
      final load = estimateTrainingLoad(
        weekHeartRate: samples,
        age: 30,
        restingHr: 60,
        now: DateTime(2026, 10, 25, 18),
      )!;

      expect(load.weeklyLoad, closeTo(1680, 0.1));
      expect(load.hardDays, 7);
      expect(load.vigorousMinutes, closeTo(420, 0.1));
      expect(load.coverageHours, closeTo(7, 0.1));
      expect(load.daily, hasLength(7));
      expect(load.confidence, MetricConfidence.medium);
    });

    test('returns null without an age for heart-rate reserve', () {
      final load = estimateTrainingLoad(
        weekHeartRate: const [],
        age: null,
        restingHr: 60,
        now: DateTime(2026, 10, 25, 18),
      );

      expect(load, isNull);
    });
  });

  group('estimateFitnessAge', () {
    test('maps a measured VO2 max to a fitness-age reference', () {
      final estimate = estimateFitnessAge(
        profile: male,
        vo2Max: 45,
        restingHrSamples: const [],
        now: DateTime(2026, 10, 25, 18),
      )!;

      expect(estimate.fitnessAge, 31);
      expect(estimate.deltaYears, -4);
      expect(estimate.vo2MaxEstimated, isFalse);
      expect(estimate.confidence, MetricConfidence.high);
      expect(estimate.lowAge, 28);
      expect(estimate.highAge, 34);
    });

    test('estimates VO2 max from resting heart rate when absent', () {
      final now = DateTime(2026, 10, 25, 18);
      final estimate = estimateFitnessAge(
        profile: const BodyProfile(
          age: 40,
          sex: BiologicalSex.female,
          heightCm: 168,
          weightKg: 62,
        ),
        vo2Max: null,
        restingHrSamples: [
          for (var day = 0; day < 12; day++)
            TimedValue(at: now.subtract(Duration(days: day)), value: 75),
        ],
        now: now,
      )!;

      expect(estimate.vo2MaxEstimated, isTrue);
      expect(estimate.vo2Max, closeTo(36.7, 0.1));
      expect(estimate.fitnessAge, 29);
      expect(estimate.confidence, MetricConfidence.medium);
    });
  });
}
