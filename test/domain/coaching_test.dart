import 'package:becel/domain/coaching.dart';
import 'package:becel/domain/estimates.dart';
import 'package:becel/domain/sleep_coach.dart';
import 'package:becel/domain/strain.dart';
import 'package:becel/domain/strength.dart';
import 'package:flutter_test/flutter_test.dart';

RecoveryEstimate _recovery(
  int score, {
  double hrvZ = 0,
  double rhrZ = 0,
  double rhrChange = 0,
}) => RecoveryEstimate(
  score: score,
  hrvZ: hrvZ,
  restingHrZ: rhrZ,
  sleepZ: 0,
  contextAdjustment: 0,
  hrvCurrent: 60 * (1 + hrvZ * 0.1),
  hrvAt: DateTime(2026, 10, 25, 3),
  hrvSampleCount: 4,
  hrvBaseline: 60,
  restingHrCurrent: 52 + rhrChange,
  restingHrAt: DateTime(2026, 10, 25, 6),
  restingHrSampleCount: 1,
  restingHrBaseline: 52,
  hrvBaselineDays: 14,
  restingHrBaselineDays: 14,
  sleepPercentOfNeed: 95,
);

const _emptySleep = SleepCoach(
  lastNight: null,
  nights: [],
  baselineNeed: 480,
  strainNeed: 0,
  debtNeed: 0,
  debtMinutes: 0,
  midpointSdMinutes: null,
  recommendedBedtime: null,
  typicalWake: null,
);

DailyPlan _plan({RecoveryEstimate? recovery, BodyAlert? alert}) =>
    buildDailyPlan(
      recovery: recovery,
      load: null,
      sleep: _emptySleep,
      alert: alert,
      muscleVolume: const [],
      logsStrength: false,
      now: DateTime(2026, 10, 25, 8),
    );

void main() {
  group('daily plan', () {
    test('green recovery means push with a high strain target', () {
      final plan = _plan(recovery: _recovery(82));
      expect(plan.tone, PlanTone.push);
      expect(plan.target.low, 14);
      expect(plan.headline, contains('go hard'));
    });

    test('yellow controls intensity; red recovers', () {
      expect(_plan(recovery: _recovery(50)).tone, PlanTone.train);
      expect(_plan(recovery: _recovery(25)).tone, PlanTone.recover);
      expect(_plan(recovery: _recovery(25)).target.high, lessThanOrEqualTo(9));
    });

    test('push needs clear evidence, not just a 67 % reading', () {
      RecoveryEstimate withComposite(int score, double z) => RecoveryEstimate(
        score: score,
        hrvZ: 0,
        restingHrZ: 0,
        sleepZ: 0,
        contextAdjustment: 0,
        composite: z,
        hrvCurrent: 60,
        hrvAt: DateTime(2026, 10, 25, 3),
        hrvSampleCount: 4,
        hrvBaseline: 60,
        restingHrCurrent: 52,
        restingHrAt: DateTime(2026, 10, 25, 6),
        restingHrSampleCount: 1,
        restingHrBaseline: 52,
        hrvBaselineDays: 14,
        restingHrBaselineDays: 14,
        sleepPercentOfNeed: 90,
      );
      expect(_plan(recovery: withComposite(67, 0.1)).tone, PlanTone.train);
      expect(_plan(recovery: withComposite(80, 0.6)).tone, PlanTone.push);
      expect(_plan(recovery: withComposite(25, -0.8)).tone, PlanTone.recover);
    });

    test('a body alert overrides a green score', () {
      final alert = detectBodyAlert(
        recovery: _recovery(70, hrvZ: -2, rhrZ: 2.5, rhrChange: 7),
      );
      expect(alert, isNotNull);
      expect(alert!.signals, hasLength(2));
      expect(_plan(recovery: _recovery(70), alert: alert).target.high, 8);
    });

    test('calibrating recovery gives a moderate, explained target', () {
      final plan = _plan();
      expect(plan.headline, 'Train by feel');
      expect(plan.target.reason, contains('calibrating'));
    });
  });

  group('weekly review', () {
    test('a load spike outranks everything else', () {
      final days = [
        for (var i = 0; i < 28; i++)
          DayStrain(
            date: DateTime(2026, 9, 28).add(Duration(days: i)),
            cardioTrimp: i < 21 ? 30 : 150,
            strengthTrimp: 0,
            coverageMinutes: 1000,
            zoneMinutes: List.filled(5, 0),
            peakBpm: 170,
          ),
      ];
      final review = buildWeeklyReview(
        recoveryHistory: const [],
        strainDays: days,
        load: trainingLoad(days),
        sleep: _emptySleep,
        strengthSessions: const [],
        energyDays: const [],
        now: DateTime(2026, 10, 25, 12),
      );
      expect(review.focus.title, 'Absorb the load');
      expect(review.strainByDay, hasLength(7));
      expect(weeklySummaryText(review), contains('Load spike'));
    });

    test('with no lifts logged the focus asks for them', () {
      final review = buildWeeklyReview(
        recoveryHistory: const [],
        strainDays: const [],
        load: null,
        sleep: _emptySleep,
        strengthSessions: const [],
        energyDays: const [],
        now: DateTime(2026, 10, 25, 12),
      );
      expect(review.focus.title, 'Add two strength sessions');
    });

    test('CSV has one row per day with provenance', () {
      final days = [
        for (var i = 0; i < 7; i++)
          DayStrain(
            date: DateTime(2026, 10, 19).add(Duration(days: i)),
            cardioTrimp: 50,
            strengthTrimp: i == 2 ? 30 : 0,
            coverageMinutes: 1000,
            zoneMinutes: List.filled(5, 0),
            peakBpm: 150,
          ),
      ];
      final review = buildWeeklyReview(
        recoveryHistory: const [],
        strainDays: days,
        load: trainingLoad(days),
        sleep: _emptySleep,
        strengthSessions: [
          StrengthSession(
            id: 'x',
            start: DateTime(2026, 10, 21, 8),
            durationMinutes: 50,
            sessionRpe: 8,
          ),
        ],
        energyDays: const [],
        now: DateTime(2026, 10, 25, 12),
      );
      final csv = weeklyCsv(
        review: review,
        recoveryHistory: const [],
        energyDays: const [],
        now: DateTime(2026, 10, 25, 12),
      );
      final lines = csv.split('\n');
      expect(lines.first, contains('strain_0_21'));
      expect(lines, hasLength(9));
      expect(csv, contains('"2026-10-21"'));
      expect(csv, contains('Health Connect'));
      expect(review.strengthSessions, 1);
    });
  });
}
