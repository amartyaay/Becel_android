import 'package:becel/data/health_connect_service.dart';
import 'package:becel/domain/estimates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recoveryReadiness', () {
    test('neutral personal signals produce a transparent 70-point index', () {
      final result = _estimate();
      final estimate = result.estimate!;

      expect(estimate.score, 70);
      expect(estimate.sleepComponent, 100);
      expect(estimate.hrvComponent, 50);
      expect(estimate.restingHrComponent, 50);
      expect(estimate.hrvBaselineDays, 10);
      expect(estimate.restingHrBaselineDays, 10);
      expect(result.limitedSamples, isTrue);
    });

    test('favorable signals can reach 100 on the displayed scale', () {
      final result = _estimate(currentHrv: 100, currentRestingHr: 50);

      expect(result.estimate?.hrvComponent, 100);
      expect(result.estimate?.restingHrComponent, 100);
      expect(result.estimate?.score, 100);
    });

    test('requires ten distinct historical nights per signal', () {
      final result = _estimate(historicalNights: 9);

      expect(result.estimate, isNull);
      expect(result.hrvBaselineNights, 9);
      expect(result.restingHrBaselineNights, 9);
    });

    test(
      'ignores current readings outside recorded asleep-stage intervals',
      () {
        final result = _estimate(currentHrvOutsideSleep: true);

        expect(result.hrvCurrentSampleCount, 0);
        expect(result.estimate, isNull);
      },
    );

    test('aligns daily resting HR by sleep-end date, not sleep stage', () {
      final result = _estimate(
        currentRestingHrOutsideSleep: true,
        historicalRestingHrOutsideSleep: true,
      );

      expect(result.restingHrCurrentSampleCount, 1);
      expect(result.restingHrBaselineNights, 10);
      expect(result.estimate, isNotNull);
    });

    test('marks a one-reading current signal as limited data', () {
      final result = _estimate(currentHrvSamples: 1);

      expect(result.estimate, isNotNull);
      expect(result.limitedSamples, isTrue);
    });

    test('accepts one daily resting-HR reading as complete current coverage', () {
      final result = _estimate(
        historicalNights: 14,
        currentRestingHrSamples: 1,
      );

      expect(result.restingHrCurrentSampleCount, 1);
      expect(result.estimate, isNotNull);
      expect(result.limitedSamples, isFalse);
    });

    test('requires a current daily resting-HR reading', () {
      final result = _estimate(currentRestingHrSamples: 0);

      expect(result.restingHrCurrentSampleCount, 0);
      expect(result.estimate, isNull);
      expect(result.limitedSamples, isTrue);
    });

    test('clears the limited-data label with complete 14-night coverage', () {
      final result = _estimate(historicalNights: 14);

      expect(result.estimate, isNotNull);
      expect(result.limitedSamples, isFalse);
    });
  });

  test('selected session is the longest qualifying session ending in 24h', () {
    final now = DateTime.now();
    final shorterAndNewer = _night(
      now.subtract(const Duration(hours: 4)),
      now.subtract(const Duration(minutes: 30)),
      minutes: 210,
    );
    final longerSession = _night(
      now.subtract(const Duration(hours: 7)),
      now.subtract(const Duration(hours: 1)),
      minutes: 300,
    );
    final detail = SleepDetail(
      status: 'ready',
      granted: const [],
      sessions: [shorterAndNewer, longerSession],
    );

    expect(detail.selectedRecentSession, same(longerSession));
  });
}

RecoveryReadiness _estimate({
  int historicalNights = 10,
  double currentHrv = 50,
  double currentRestingHr = 60,
  int currentHrvSamples = 2,
  int currentRestingHrSamples = 1,
  bool currentHrvOutsideSleep = false,
  bool currentRestingHrOutsideSleep = false,
  bool historicalRestingHrOutsideSleep = false,
}) {
  final today = DateTime.now();
  final now = DateTime(today.year, today.month, today.day, 18);
  final currentStart = DateTime(today.year, today.month, today.day);
  final currentEnd = currentStart.add(const Duration(hours: 8));
  final currentInterval = AsleepInterval(start: currentStart, end: currentEnd);
  final hrvSamples = <TimedValue>[];
  final restingHrSamples = <TimedValue>[];
  final windows = <SleepWindow>[];

  for (var dayOffset = 1; dayOffset <= historicalNights; dayOffset++) {
    final end = DateTime(today.year, today.month, today.day - dayOffset, 7);
    final start = end.subtract(const Duration(hours: 8));
    final interval = AsleepInterval(start: start, end: end);
    final sampleAt = end.subtract(const Duration(hours: 4));
    windows.add(
      SleepWindow(
        start: start,
        end: end,
        sleepMinutes: 420,
        asleepIntervals: [interval],
      ),
    );
    hrvSamples.add(TimedValue(at: sampleAt, value: 50));
    restingHrSamples.add(
      TimedValue(
        at: historicalRestingHrOutsideSleep
            ? end.add(const Duration(hours: 1))
            : sampleAt,
        value: 60,
      ),
    );
  }

  for (var index = 0; index < currentHrvSamples; index++) {
    hrvSamples.add(
      TimedValue(
        at: currentHrvOutsideSleep
            ? currentEnd.add(Duration(minutes: index + 1))
            : currentStart.add(Duration(hours: 2 + index)),
        value: currentHrv,
      ),
    );
  }
  for (var index = 0; index < currentRestingHrSamples; index++) {
    restingHrSamples.add(
      TimedValue(
        at: currentRestingHrOutsideSleep
            ? currentStart.add(Duration(hours: 12 + index))
            : currentStart.add(Duration(hours: 2 + index)),
        value: currentRestingHr,
      ),
    );
  }

  return recoveryReadiness(
    hrvSamples: hrvSamples,
    restingHrSamples: restingHrSamples,
    sleepMinutes: 420,
    sleepStart: currentStart,
    sleepEnd: currentEnd,
    asleepIntervals: [currentInterval],
    sleepWindows: windows,
    now: now,
  );
}

SleepNight _night(DateTime start, DateTime end, {required int minutes}) =>
    SleepNight(
      start: start,
      end: end,
      minutes: minutes,
      awakeMinutes: 0,
      lightMinutes: minutes,
      deepMinutes: 0,
      remMinutes: 0,
      asleepIntervals: const [],
    );
