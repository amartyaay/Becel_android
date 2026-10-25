import 'package:becel/data/health_connect_service.dart';
import 'package:becel/domain/coaching.dart';
import 'package:becel/domain/energy.dart';
import 'package:becel/domain/estimates.dart';
import 'package:becel/domain/heart_signal.dart';
import 'package:becel/domain/profile.dart';
import 'package:becel/domain/sleep_coach.dart';
import 'package:becel/domain/strain.dart';
import 'package:becel/domain/strength.dart';
import 'package:flutter_test/flutter_test.dart';

const athlete = BodyProfile(
  age: 34,
  sex: BiologicalSex.male,
  heightCm: 180,
  weightKg: 82,
);

List<TimedValue> minutes(DateTime start, int count, double Function(int) bpm) =>
    [
      for (var i = 0; i < count; i++)
        TimedValue(
          at: start.add(Duration(minutes: i)),
          value: bpm(i),
        ),
    ];

void main() {
  group('heart signal', () {
    test(
      'Hampel filter removes an isolated 40 bpm spike but keeps intervals',
      () {
        final start = DateTime(2026, 10, 25, 9);
        final samples = minutes(start, 30, (i) => i == 10 ? 150 : 110);
        final cleaned = cleanHeartRate(samples);
        expect(cleaned.corrected, 1);
        expect(cleaned.samples[10].value, 110);

        final intervals = minutes(
          start,
          30,
          (i) => i >= 10 && i < 20 ? 165 : 110,
        );
        expect(cleanHeartRate(intervals).corrected, 0);
      },
    );

    test('cadence lock is dropped only when steps carry on past the fall', () {
      final start = DateTime(2026, 10, 25, 9);
      List<StepBucket> buckets(int Function(int minute) spm) => [
        for (var m = 0; m < 30; m += 5)
          StepBucket(
            start: start.add(Duration(minutes: m)),
            steps: spm(m) * 5,
          ),
      ];

      // Walking at 115 spm throughout; HR locks onto cadence for 10 minutes,
      // then snaps back to the true 80 bpm while the walk continues.
      final locked = excludeCadenceLock(
        CleanHeartRate(
          samples: minutes(start, 30, (i) => i >= 10 && i < 20 ? 115 : 80),
          corrected: 0,
        ),
        buckets((_) => 115),
      );
      expect(locked.cadenceLocked, 10);

      // A real 160 spm run: HR falls 25 bpm in the first minute after
      // stopping, but cadence stops too, so the effort is kept.
      final run = excludeCadenceLock(
        CleanHeartRate(
          samples: minutes(
            start,
            30,
            (i) => i < 10 ? 100 : (i < 20 ? 160 : 135 - (i - 20) * 2.0),
          ),
          corrected: 0,
        ),
        buckets((m) => m >= 10 && m < 20 ? 160 : 0),
      );
      expect(run.cadenceLocked, 0);
    });

    test('observed sustained max replaces a low age prediction, capped', () {
      final start = DateTime(2026, 10, 25, 18);
      final hard = minutes(start, 10, (i) => i >= 4 && i <= 7 ? 191 : 150);
      final max = personalMaxHeartRate(age: 34, cleanedMinutes: hard)!;
      expect(max.predictedBpm, 184);
      expect(max.source, MaxHrSource.observed);
      expect(max.bpm, 191);

      final tested = personalMaxHeartRate(age: 34, tested: 196)!;
      expect(tested.source, MaxHrSource.tested);
      expect(tested.bpm, 196);
    });

    test('Karvonen zones use heart-rate reserve', () {
      const zones = HeartZones(restingBpm: 52, maxBpm: 184);
      expect(zones.bpmAt(0.5), 118);
      expect(zones.zoneOf(150), 2);
      expect(zones.zoneOf(100), -1);
    });
  });

  group('strain', () {
    test('maps TRIMP onto a logarithmic 0–21 scale', () {
      expect(strainFromTrimp(0), 0);
      expect(strainFromTrimp(100), closeTo(11.3, 0.1));
      expect(strainFromTrimp(250), closeTo(17.9, 0.1));
      expect(strainFromTrimp(10000), lessThanOrEqualTo(21));
      expect(strainFromTrimp(400), lessThan(21));
      expect(strainFromTrimp(trimpForStrain(12)), closeTo(12, 0.01));
    });

    test('resting heart rate below 10% HRR adds no load', () {
      expect(banisterTrimpPerMinute(0.05, BiologicalSex.male), 0);
      expect(banisterTrimpPerMinute(0.3, BiologicalSex.male), greaterThan(0.2));
      expect(
        banisterTrimpPerMinute(0.7, BiologicalSex.male),
        closeTo(1.642, 0.005),
      );
      expect(
        banisterTrimpPerMinute(0.7, BiologicalSex.female),
        closeTo(1.836, 0.005),
      );
    });

    test('an hour of steady running reads as a hard day', () {
      final now = DateTime(2026, 10, 25, 20);
      final run = minutes(DateTime(2026, 10, 25, 18), 60, (_) => 145);
      final days = dailyStrain(
        cleanedMinutes: run,
        restingBpm: 52,
        maxBpm: 184,
        sex: BiologicalSex.male,
        now: now,
        days: 1,
      );
      expect(days.single.strain, inInclusiveRange(10, 14));
    });

    test('logged lifting adds the load heart rate missed', () {
      final now = DateTime(2026, 10, 25, 20);
      final lift = StrengthSession(
        id: 'a',
        start: DateTime(2026, 10, 25, 8),
        durationMinutes: 60,
        sessionRpe: 8,
      );
      final easyHr = minutes(lift.start, 60, (_) => 95);
      final days = dailyStrain(
        cleanedMinutes: easyHr,
        restingBpm: 52,
        maxBpm: 184,
        sex: BiologicalSex.male,
        now: now,
        days: 1,
        strengthSessions: [lift],
      );
      expect(days.single.strengthTrimp, greaterThan(60));
      expect(days.single.trimp, closeTo(96, 1));
    });

    test('everyday HR counts toward day strain but not training load', () {
      final now = DateTime(2026, 10, 25, 20);
      // 10 hours at ~20 % HRR: walking around the house, no exercise.
      final ambient = minutes(DateTime(2026, 10, 25, 9), 600, (_) => 78);
      final day = dailyStrain(
        cleanedMinutes: ambient,
        restingBpm: 52,
        maxBpm: 184,
        sex: BiologicalSex.male,
        now: now,
        days: 1,
      ).single;
      expect(day.strain, greaterThan(1));
      expect(day.trainingTrimp, 0);
    });

    test('strain target adds the session to the user\'s everyday strain', () {
      final reference = strainTarget(
        recovery: 50,
        load: null,
        ambient: referenceAmbientTrimp,
      );
      expect(reference.low, 10);
      expect(reference.high, 14);

      // Someone whose ordinary day already reads strain 8 needs a higher
      // band for the same session dose.
      final active = strainTarget(
        recovery: 50,
        load: null,
        ambient: trimpForStrain(8),
      );
      expect(active.low, greaterThan(11));
      expect(active.high, greaterThan(14.5));
      expect(active.high, lessThan(strainMax));
      expect(active.reason, contains('everyday strain'));
    });

    test('brisk walking cadence counts as moderate even at low HRR', () {
      final now = DateTime(2026, 10, 25, 20);
      final start = DateTime(2026, 10, 25, 12);
      final day = dailyStrain(
        cleanedMinutes: minutes(start, 31, (_) => 95),
        restingBpm: 52,
        maxBpm: 184,
        sex: BiologicalSex.male,
        now: now,
        days: 1,
        stepBuckets: [
          for (var i = 0; i < 6; i++)
            StepBucket(start: start.add(Duration(minutes: i * 5)), steps: 550),
        ],
      ).single;
      // 30 intervals; the last falls just after the final step bucket.
      expect(day.moderateMinutes, closeTo(29, 0.5));
    });

    test('ACWR flags a load spike after a quiet month', () {
      final base = DateTime(2026, 10, 1);
      final days = [
        for (var i = 0; i < 28; i++)
          DayStrain(
            date: base.add(Duration(days: i)),
            cardioTrimp: i < 21 ? 40 : 160,
            strengthTrimp: 0,
            coverageMinutes: 1000,
            zoneMinutes: List.filled(5, 0),
            peakBpm: 160,
          ),
      ];
      final load = trainingLoad(days);
      expect(load.status, LoadStatus.spike);
      expect(load.acwr, greaterThan(1.5));
      final target = strainTarget(recovery: 80, load: load);
      expect(target.high, lessThan(18));
    });
  });

  group('energy', () {
    test('sitting at 75 bpm earns no heart-rate calories (FLEX-HR)', () {
      final date = DateTime(2026, 10, 25);
      final now = DateTime(2026, 10, 25, 12);
      final sitting = minutes(DateTime(2026, 10, 25, 8), 240, (_) => 75);
      final day = estimateDayEnergy(
        profile: athlete,
        date: date,
        now: now,
        cleanedMinutes: sitting,
        stepBuckets: const [],
        sleep: [AsleepInterval(start: date, end: DateTime(2026, 10, 25, 7))],
        restingBpm: 52,
        maxBpm: 184,
      )!;
      expect(day.flexBpm, 92);
      // Resting 12 h ≈ 905 kcal, plus a small awake allowance.
      expect(day.heartKcal, 0);
      expect(day.totalKcal, lessThan(1150));
    });

    test('a step-free bout must be clearly above FLEX to earn HR energy', () {
      final date = DateTime(2026, 10, 25);
      final now = DateTime(2026, 10, 25, 12);
      DayEnergy dayWith(double bpm) => estimateDayEnergy(
        profile: athlete,
        date: date,
        now: now,
        cleanedMinutes: [
          ...minutes(DateTime(2026, 10, 25, 8), 60, (_) => 70),
          ...minutes(DateTime(2026, 10, 25, 9), 40, (_) => bpm),
          ...minutes(DateTime(2026, 10, 25, 9, 40), 60, (_) => 70),
        ],
        stepBuckets: const [],
        sleep: [AsleepInterval(start: date, end: DateTime(2026, 10, 25, 7))],
        restingBpm: 52,
        maxBpm: 184,
      )!;
      // A stressful meeting just over FLEX (92): no exercise energy.
      expect(dayWith(97).heartKcal, 0);
      // Forty minutes on an unlogged bike at FLEX + 23: damped HR counts.
      expect(dayWith(115).heartKcal, greaterThan(40));
    });

    test('an easy walk is costed from steps, not inflated by Keytel', () {
      // Real-device case: 92 kg, RHR 66, walking at ~105 bpm (~29% HRR).
      const user = BodyProfile(
        age: 26,
        sex: BiologicalSex.male,
        heightCm: 185,
        weightKg: 92,
      );
      final date = DateTime(2026, 10, 25);
      final now = DateTime(2026, 10, 25, 15);
      final walkStart = DateTime(2026, 10, 25, 14);
      final day = estimateDayEnergy(
        profile: user,
        date: date,
        now: now,
        cleanedMinutes: minutes(walkStart, 40, (_) => 105),
        stepBuckets: [
          for (var i = 0; i < 8; i++)
            StepBucket(
              start: walkStart.add(Duration(minutes: i * 5)),
              steps: 500,
            ),
        ],
        sleep: const [],
        restingBpm: 66,
        maxBpm: 190,
      )!;
      // 4,000 steps × 0.768 m × 92 kg × 0.5 kcal/kg/km ≈ 141 kcal. Each
      // minute takes the larger of step cost and half-Keytel, never full
      // Keytel (~7 kcal/min here), so the walk stays near walking cost.
      expect(day.heartKcal + day.stepKcal, inInclusiveRange(135, 150));
    });

    test('phantom desk steps are filtered; real walking counts', () {
      final date = DateTime(2026, 10, 25);
      final now = DateTime(2026, 10, 25, 12);
      final buckets = [
        for (var i = 0; i < 24; i++)
          StepBucket(
            start: DateTime(2026, 10, 25, 9).add(Duration(minutes: i * 5)),
            steps: 35,
          ),
        StepBucket(start: DateTime(2026, 10, 25, 11), steps: 520),
      ];
      final day = estimateDayEnergy(
        profile: athlete,
        date: date,
        now: now,
        cleanedMinutes: minutes(DateTime(2026, 10, 25, 8), 240, (_) => 70),
        stepBuckets: buckets,
        sleep: const [],
        restingBpm: 52,
        maxBpm: 184,
      )!;
      expect(day.filteredSteps, 840);
      expect(day.countedSteps, 520);
      expect(day.stepKcal, closeTo(520 * 0.747 / 1000 * 82 * 0.5, 0.5));
    });

    test('logged lifting uses Compendium METs instead of inflated HR', () {
      final date = DateTime(2026, 10, 25);
      final now = DateTime(2026, 10, 25, 12);
      final lift = StrengthSession(
        id: 'a',
        start: DateTime(2026, 10, 25, 8),
        durationMinutes: 60,
        sessionRpe: 8,
      );
      final day = estimateDayEnergy(
        profile: athlete,
        date: date,
        now: now,
        cleanedMinutes: minutes(lift.start, 60, (_) => 135),
        stepBuckets: const [],
        sleep: const [],
        restingBpm: 52,
        maxBpm: 184,
        strengthSessions: [lift],
      )!;
      // Corrected METs: (6 − 1) × RMR/min (1780/1440) × 60 ≈ 371 kcal.
      expect(day.strengthKcal, closeTo(370.8, 1));
      expect(day.heartKcal, 0);
    });

    test('logging a small meal never lowers the digestion estimate', () {
      DayEnergy dayWith(double? intake) => DayEnergy(
        date: DateTime(2026, 10, 24),
        restingKcal: 1950,
        heartKcal: 100,
        stepKcal: 150,
        strengthKcal: 0,
        awakeKcal: 300,
        countedSteps: 6000,
        filteredSteps: 0,
        flexBpm: 95,
        heartMinutes: 20,
        minutesElapsed: 1440,
        complete: true,
        rmrMethod: 'Mifflin',
        intakeKcal: intake,
      );
      final none = dayWith(null);
      final snack = dayWith(500);
      final full = dayWith(3200);
      expect(snack.tefKcal, none.tefKcal);
      expect(full.tefKcal, closeTo(320, 0.1));
      expect(none.pal, inInclusiveRange(1.35, 1.55));
    });

    test('Katch–McArdle is used when body fat is known', () {
      const lean = BodyProfile(
        age: 34,
        sex: BiologicalSex.male,
        heightCm: 180,
        weightKg: 82,
        bodyFatPercent: 12,
      );
      expect(restingMetabolicRate(athlete), closeTo(1780, 1));
      expect(restingMetabolicRate(lean), closeTo(370 + 21.6 * 72.16, 1));
    });
  });

  group('sleep coach', () {
    SleepNight night(DateTime start, DateTime end) => SleepNight(
      start: start,
      end: end,
      minutes: end.difference(start).inMinutes,
      awakeMinutes: 0,
      lightMinutes: end.difference(start).inMinutes,
      deepMinutes: 0,
      remMinutes: 0,
      asleepIntervals: [AsleepInterval(start: start, end: end)],
    );

    test('trims onset logged while heart rate was still awake', () {
      final start = DateTime(2026, 10, 24, 23);
      final end = DateTime(2026, 10, 25, 7);
      final hr = [
        ...minutes(start.subtract(const Duration(minutes: 30)), 30, (_) => 75),
        ...minutes(start, 480, (i) => i < 60 ? 72 : 52),
      ];
      final adjusted = adjustOnset(night(start, end), cleanedMinutes: hr);
      expect(adjusted.onsetSource, OnsetSource.heartRate);
      expect(adjusted.trimmedMinutes, inInclusiveRange(55, 65));
    });

    test('a user-entered onset wins', () {
      final start = DateTime(2026, 10, 24, 23);
      final end = DateTime(2026, 10, 25, 7);
      final adjusted = adjustOnset(
        night(start, end),
        cleanedMinutes: const [],
        userOnset: DateTime(2026, 10, 25, 0, 30),
      );
      expect(adjusted.onsetSource, OnsetSource.user);
      expect(adjusted.asleepMinutes, 390);
    });

    test('need grows with strain and short nights', () {
      final now = DateTime(2026, 10, 25, 12);
      final sessions = [
        for (var d = 3; d >= 0; d--)
          night(
            DateTime(2026, 10, 24 - d, 23),
            DateTime(2026, 10, 25 - d, d < 3 ? 5 : 7),
          ),
      ];
      final coach = buildSleepCoach(
        sessions: sessions,
        cleanedMinutes: const [],
        now: now,
        yesterdayStrain: 18,
      );
      expect(coach.baselineNeed, 480);
      expect(coach.strainNeed, 33);
      expect(coach.debtNeed, 60);
      expect(coach.performancePercent, lessThan(80));
      expect(coach.recommendedBedtime, isNotNull);
    });
  });

  group('coaching', () {
    test('body alert needs more than one signal', () {
      expect(detectBodyAlert(recovery: null, respiratoryDelta: 1.2), isNull);
      expect(
        detectBodyAlert(
          recovery: null,
          respiratoryDelta: 1.2,
          skinTempDelta: 0.6,
        ),
        isNull,
      );
    });

    test('estimated 1RM uses reps in reserve and refuses high reps', () {
      expect(estimateOneRepMax(loadKg: 100, reps: 5), closeTo(116.7, 0.1));
      expect(
        estimateOneRepMax(loadKg: 100, reps: 5, rpe: 8),
        closeTo(123.3, 0.1),
      );
      expect(estimateOneRepMax(loadKg: 60, reps: 15), isNull);
    });

    test('fractional sets credit synergists at half a set', () {
      final now = DateTime(2026, 10, 25, 12);
      final session = StrengthSession(
        id: 'b',
        start: DateTime(2026, 10, 24, 8),
        durationMinutes: 60,
        sessionRpe: 8,
        exercises: const [
          ExerciseEntry(
            exerciseId: 'bench_press',
            sets: [
              StrengthSet(reps: 5, loadKg: 100, rpe: 8),
              StrengthSet(reps: 5, loadKg: 100, rpe: 8),
              StrengthSet(reps: 8, loadKg: 60, rpe: 4),
            ],
          ),
        ],
      );
      final volume = weeklyMuscleVolume([session], now: now);
      double sets(Muscle m) => volume.firstWhere((v) => v.muscle == m).sets;
      expect(sets(Muscle.chest), 2);
      expect(sets(Muscle.triceps), 1);
    });
  });
}
