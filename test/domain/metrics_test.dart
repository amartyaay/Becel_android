import 'package:becel/domain/heart_signal.dart';
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

  test('cardio fitness is a range that widens with a predicted max', () {
    final predicted = estimateCardioFitness(
      profile: male,
      maxHr: const MaxHeartRate(
        bpm: 184,
        source: MaxHrSource.predicted,
        predictedBpm: 184,
      ),
      restingBpm: 52,
    )!;
    expect(predicted.vo2Max, closeTo(54.1, 0.1));
    expect(predicted.high - predicted.low, closeTo(54.1 * 0.4, 0.2));
    expect(predicted.confidence, MetricConfidence.low);
    expect(predicted.category, 'Superior');

    final tested = estimateCardioFitness(
      profile: male,
      maxHr: const MaxHeartRate(
        bpm: 190,
        source: MaxHrSource.tested,
        predictedBpm: 184,
      ),
      restingBpm: 60,
    )!;
    expect(tested.high - tested.low, closeTo(tested.vo2Max * 0.2, 0.2));
    expect(tested.confidence, MetricConfidence.medium);
  });

  test('cardio fitness needs a resting heart rate', () {
    expect(
      estimateCardioFitness(profile: male, maxHr: null, restingBpm: 55),
      isNull,
    );
  });
}
