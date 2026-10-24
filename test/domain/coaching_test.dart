import 'package:becel/data/health_connect_service.dart';
import 'package:becel/domain/coaching.dart';
import 'package:becel/domain/estimates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSleepTrend', () {
    test('averages qualifying nights and excludes naps', () {
      final now = DateTime(2026, 3, 10, 12);
      final sessions = [
        for (var offset = 0; offset < 7; offset++)
          _night(end: DateTime(2026, 3, 10 - offset, 7), minutes: 420),
        _night(end: DateTime(2026, 3, 10, 14), minutes: 90),
      ];

      final trend = buildSleepTrend(sessions, now: now);

      expect(trend.nights, 7);
      expect(trend.averageMinutes, 420);
      expect(trend.averageInBedMinutes, 480);
      expect(trend.bedtimeSpreadMinutes, 0);
      expect(trend.isWithinAdultRange, isTrue);
    });

    test('reports the previous week only as a descriptive delta', () {
      final now = DateTime(2026, 3, 10, 12);
      final sessions = [
        for (var offset = 0; offset < 7; offset++)
          _night(end: DateTime(2026, 3, 10 - offset, 7), minutes: 420),
        for (var offset = 7; offset < 14; offset++)
          _night(end: DateTime(2026, 3, 10 - offset, 7), minutes: 360),
      ];

      final trend = buildSleepTrend(sessions, now: now);

      expect(trend.averageMinutes, 420);
      expect(trend.previousAverageMinutes, 360);
      expect(trend.sleepDeltaMinutes, 60);
    });
  });

  group('buildFocusRecommendation', () {
    const goodSleep = SleepTrend(
      nights: 7,
      averageMinutes: 430,
      averageInBedMinutes: 480,
      averageBedtimeMinutes: 1380,
      bedtimeSpreadMinutes: 20,
      previousAverageMinutes: 425,
    );
    const shortSleep = SleepTrend(
      nights: 7,
      averageMinutes: 330,
      averageInBedMinutes: 380,
      averageBedtimeMinutes: 1380,
      bedtimeSpreadMinutes: 30,
      previousAverageMinutes: 340,
    );
    const irregularSleep = SleepTrend(
      nights: 7,
      averageMinutes: 430,
      averageInBedMinutes: 480,
      averageBedtimeMinutes: 1380,
      bedtimeSpreadMinutes: 120,
      previousAverageMinutes: 425,
    );

    test('an unwell check-in overrides every measured signal', () {
      final focus = buildFocusRecommendation(
        sleep: shortSleep,
        strengthDays: 0,
        activity: _activity(60),
        checkInTags: const {'unwell'},
      );

      expect(focus.kind, FocusKind.recover);
      expect(focus.title, 'Make today lighter');
      expect(focus.body, contains('not a diagnosis'));
    });

    test('short sleep comes before strength and aerobic targets', () {
      final focus = buildFocusRecommendation(
        sleep: shortSleep,
        strengthDays: 0,
        activity: _activity(60),
      );

      expect(focus.kind, FocusKind.sleepDuration);
      expect(focus.actionLabel, 'Open sleep');
    });

    test('strength is the first weekly target once sleep is adequate', () {
      final focus = buildFocusRecommendation(
        sleep: goodSleep,
        strengthDays: 1,
        activity: _activity(60),
      );

      expect(focus.kind, FocusKind.strength);
      expect(focus.actionLabel, 'Log strength');
    });

    test('bedtime spread follows strength when sleep is adequate', () {
      final focus = buildFocusRecommendation(
        sleep: irregularSleep,
        strengthDays: 2,
        activity: _activity(60),
      );

      expect(focus.kind, FocusKind.sleepRegularity);
      expect(focus.body, contains('varied by'));
    });

    test('aerobic follows sleep and strength targets', () {
      final focus = buildFocusRecommendation(
        sleep: goodSleep,
        strengthDays: 2,
        activity: _activity(149.5),
      );

      expect(focus.kind, FocusKind.aerobic);
      expect(focus.body, contains('149 of 150'));
    });

    test('maintains a week that already meets the targets', () {
      final focus = buildFocusRecommendation(
        sleep: goodSleep,
        strengthDays: 2,
        activity: _activity(160),
      );

      expect(focus.kind, FocusKind.maintain);
      expect(focus.actionLabel, 'Review the week');
    });
  });

  test('strength days count manual logs and synced workouts once', () {
    final now = DateTime(2026, 3, 10, 12);
    final days = strengthDaysInWindow(
      workouts: [
        StrengthCandidate(at: DateTime(2026, 3, 9, 18), type: 'Strength'),
        StrengthCandidate(at: DateTime(2026, 3, 9, 19), type: 'Yoga'),
        StrengthCandidate(at: DateTime(2026, 3, 2, 18), type: 'Weights'),
        StrengthCandidate(at: DateTime(2026, 2, 1, 18), type: 'Weights'),
      ],
      loggedDays: [DateTime(2026, 3, 9), DateTime(2026, 3, 8)],
      now: now,
    );

    expect(days, 2);
    expect(isStrengthType('Resistance training'), isTrue);
    expect(isStrengthType('Running'), isFalse);
  });

  test('weekly review and exports share the displayed values', () {
    final now = DateTime(2026, 3, 10, 12);
    final sessions = [
      for (var offset = 0; offset < 7; offset++)
        _night(end: DateTime(2026, 3, 10 - offset, 7), minutes: 420),
    ];
    final review = buildWeeklyReview(
      sleepSessions: sessions,
      workouts: const <StrengthCandidate>[],
      loggedStrengthDays: [DateTime(2026, 3, 8)],
      activity: _activity(149.5),
      recoveryHistory: const <RecoveryHistoryPoint>[],
      steps: const [1000, 2000],
      checkInTags: const {'unwell'},
      now: now,
    );

    expect(review.sleep.averageMinutes, 420);
    expect(review.strengthDays, 1);
    expect(review.aerobicMinutes, 149);
    expect(review.aerobicPotentialMinutes, 175);
    expect(review.stepsTotal, 3000);
    expect(review.recoveryMornings, 0);
    expect(review.focus.kind, FocusKind.recover);

    final summary = weeklySummaryText(review: review, now: now);
    expect(summary, contains('Sleep: 7h average over 7 nights'));
    expect(summary, contains('Aerobic: 149 of 150'));
    expect(summary, contains('up to 175 with fuller wear'));
    expect(summary, contains('Strength: 1 of 2 days'));
    expect(summary, contains('Wellness context only'));

    final csv = weeklyCsv(review: review, now: now);
    expect(csv, contains('"aerobic_observed","149"'));
    expect(csv, contains('"aerobic_potential","175"'));
    expect(csv, contains('"strength_days","1"'));
    expect(csv, contains('"source"'));
  });
}

ActivityEstimate _activity(double minutes) => ActivityEstimate(
  age: 40,
  estimatedMaxHrBpm: 180,
  restingHrBpm: 60,
  restingHrAt: DateTime(2026, 3, 10),
  moderateMinutes: minutes,
  vigorousMinutes: 0,
  usableDays: 6,
  zoneMinutes: List.filled(5, 0),
  zoneRanges: List.filled(5, 'n/a'),
);

SleepNight _night({required DateTime end, required int minutes}) {
  final start = end.subtract(Duration(minutes: minutes + 60));
  return SleepNight(
    start: start,
    end: end,
    minutes: minutes,
    awakeMinutes: 0,
    lightMinutes: minutes,
    deepMinutes: 0,
    remMinutes: 0,
    asleepIntervals: [AsleepInterval(start: start, end: end)],
  );
}
