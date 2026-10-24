import 'package:becel/data/health_connect_service.dart';
import 'package:becel/domain/estimates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recoveryReadiness', () {
    test('neutral personal signals produce a transparent 50-point index', () {
      final result = _estimate();
      final estimate = result.estimate!;

      expect(estimate.score, 50);
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

    test(
      'accepts one daily resting-HR reading as complete current coverage',
      () {
        final result = _estimate(
          historicalNights: 14,
          currentRestingHrSamples: 1,
        );

        expect(result.restingHrCurrentSampleCount, 1);
        expect(result.estimate, isNotNull);
        expect(result.limitedSamples, isFalse);
      },
    );

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

    test('sleep duration anchors the window but does not change the score', () {
      final short = _estimate(sleepMinutes: 300);
      final long = _estimate(sleepMinutes: 540);

      expect(short.estimate?.score, 50);
      expect(long.estimate?.score, 50);
      expect(short.estimate?.sleepComponent, lessThan(100));
      expect(long.estimate?.sleepComponent, 100);
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

  test(
    'recovery history keeps missing sessions as gaps and scores by date',
    () {
      final now = DateTime(2026, 10, 24, 18);
      final windows = <SleepWindow>[];
      final hrvSamples = <TimedValue>[];
      final restingHrSamples = <TimedValue>[];
      for (var offset = 0; offset <= 27; offset++) {
        if (offset == 6) continue;
        final end = DateTime(2026, 10, 24 - offset, 7);
        final start = end.subtract(const Duration(hours: 8));
        final interval = AsleepInterval(start: start, end: end);
        windows.add(
          SleepWindow(
            start: start,
            end: end,
            sleepMinutes: 420,
            asleepIntervals: [interval],
          ),
        );
        hrvSamples.add(
          TimedValue(at: start.add(const Duration(hours: 4)), value: 50),
        );
        restingHrSamples.add(
          TimedValue(at: DateTime(end.year, end.month, end.day, 12), value: 60),
        );
      }

      final history = recoveryHistory(
        hrvSamples: hrvSamples,
        restingHrSamples: restingHrSamples,
        sleepWindows: windows,
        now: now,
      );

      expect(history, hasLength(14));
      expect(history[7].date, DateTime(2026, 10, 18));
      expect(history[7].readiness, isNull);
      expect(history.last.date, DateTime(2026, 10, 24));
      expect(history.last.sleepMinutes, 420);
      expect(history.last.readiness?.estimate?.score, 50);
      expect(history.last.readiness?.hrvBaselineNights, 13);
    },
  );

  test('activity total, progress, and remaining minutes share one rule', () {
    final below = _activityEstimate(149.5);
    expect(below.displayedEquivalentMinutes, 149);
    expect(below.potentialEquivalentMinutes, 175);
    expect(below.progressPercent, 99);
    expect(below.minutesToAerobicReference, 1);
    expect(below.minutesAboveAerobicReference, 0);

    final fullCoverage = _activityEstimate(149.5, usableDays: 7);
    expect(fullCoverage.potentialEquivalentMinutes, 149);

    final justOver = _activityEstimate(150.5);
    expect(justOver.displayedEquivalentMinutes, 150);
    expect(justOver.progressPercent, 100);
    expect(justOver.minutesToAerobicReference, 0);
    expect(justOver.minutesAboveAerobicReference, 0);

    final clearlyOver = _activityEstimate(151.5);
    expect(clearlyOver.displayedEquivalentMinutes, 151);
    expect(clearlyOver.minutesAboveAerobicReference, 1);
  });
}

ActivityEstimate _activityEstimate(
  double equivalentMinutes, {
  int usableDays = 6,
}) => ActivityEstimate(
  age: 40,
  estimatedMaxHrBpm: 180,
  restingHrBpm: 60,
  restingHrAt: DateTime(2026, 10, 24),
  moderateMinutes: equivalentMinutes,
  vigorousMinutes: 0,
  usableDays: usableDays,
  zoneMinutes: List.filled(5, 0),
  zoneRanges: List.filled(5, 'n/a'),
);

RecoveryReadiness _estimate({
  int historicalNights = 10,
  double currentHrv = 50,
  double currentRestingHr = 60,
  int currentHrvSamples = 2,
  int currentRestingHrSamples = 1,
  int sleepMinutes = 420,
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
    sleepMinutes: sleepMinutes,
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
