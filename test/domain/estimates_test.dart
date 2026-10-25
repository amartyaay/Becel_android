import 'package:becel/data/health_connect_service.dart';
import 'package:becel/domain/estimates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recoveryReadiness', () {
    test('a typical morning reads 50 %, the middle of the scale', () {
      // Same HRV, resting HR, and sleep (420 min) as the user's usual night.
      final result = _estimate(sleepMinutes: 420);
      final estimate = result.estimate!;

      expect(estimate.sleepPercentOfNeed, 88);
      expect(estimate.sleepZ, 0);
      expect(estimate.hrvZ, 0);
      expect(estimate.restingHrZ, 0);
      expect(estimate.score, 50);
      expect(estimate.band, RecoveryBand.yellow);
      expect(estimate.hrvBaselineDays, 10);
      expect(estimate.provisional, isFalse);
    });

    test('sleep is scored against your own usual night, with guards', () {
      // A steady 7 h sleeper is not penalised for being a 7 h sleeper.
      expect(_estimate(sleepMinutes: 420).estimate!.sleepZ, 0);
      // An hour short of usual counts against recovery.
      expect(_estimate(sleepMinutes: 360).estimate!.sleepZ, lessThan(-1));
      // Sleeping longer than usual helps.
      expect(_estimate(sleepMinutes: 480).estimate!.sleepZ, greaterThan(0));
    });

    test('favourable signals reach the green band', () {
      final result = _estimate(currentHrv: 100, currentRestingHr: 50);

      expect(result.estimate!.hrvZ, 1.5);
      expect(result.estimate!.restingHrZ, -3);
      expect(result.estimate!.score, greaterThanOrEqualTo(95));
      expect(result.estimate!.band, RecoveryBand.green);
    });

    test('suppressed HRV and raised resting HR land in the red band', () {
      final result = _estimate(currentHrv: 35, currentRestingHr: 66);

      expect(result.estimate!.band, RecoveryBand.red);
    });

    test('a provisional score starts after four baseline nights', () {
      expect(_estimate(historicalNights: 3).estimate, isNull);
      expect(_estimate(historicalNights: 3).nightsUntilScore, 1);
      final provisional = _estimate(historicalNights: 4);
      expect(provisional.estimate, isNotNull);
      expect(provisional.estimate!.provisional, isTrue);
      expect(provisional.limitedSamples, isTrue);
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

    test('short sleep lowers recovery; long sleep is never penalised', () {
      final short = _estimate(sleepMinutes: 300);
      final neutral = _estimate(sleepMinutes: 408);
      final long = _estimate(sleepMinutes: 640);

      expect(short.estimate!.score, lessThan(neutral.estimate!.score));
      expect(
        long.estimate!.score,
        greaterThanOrEqualTo(neutral.estimate!.score),
      );
    });

    test('very high HRV is capped and not rewarded when resting HR is up', () {
      final high = _estimate(currentHrv: 100);
      expect(high.estimate!.hrvZ, 1.5);
      final both = _estimate(currentHrv: 100, currentRestingHr: 66);
      expect(both.estimate!.hrvZ, 0);
      expect(both.estimate!.contextReasons, isNotEmpty);
    });

    test('a respiratory or temperature rise lowers the score', () {
      final none = _estimate();
      final febrile = _estimate(respiratoryDelta: 1.4, skinTempDelta: 0.7);

      expect(febrile.estimate!.score, lessThan(none.estimate!.score - 15));
      expect(febrile.estimate!.contextReasons, hasLength(2));
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
      expect(history.last.readiness?.estimate, isNotNull);
      // 28-day window: offsets 1–27 minus the missing night 6.
      expect(history.last.readiness?.hrvBaselineNights, 26);
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
  double? respiratoryDelta,
  double? skinTempDelta,
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
    respiratoryDelta: respiratoryDelta,
    skinTempDelta: skinTempDelta,
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
