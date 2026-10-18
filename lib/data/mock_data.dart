import 'dart:math';

import '../domain/models.dart';

/// Deterministic mock data used for design iteration until Health Connect
/// ingestion lands (Phase 1). Replace with real repositories behind the same
/// getters.
abstract final class MockData {
  static final DateTime today = DateTime(2026, 10, 18);

  static final List<DailyScores> scores30 = _generateScores();

  static DailyScores get todayScores => scores30.last;

  static List<double> series(int Function(DailyScores s) pick) =>
      scores30.map((s) => pick(s).toDouble()).toList();

  static List<double> get recoverySeries => series((s) => s.recovery);
  static List<double> get sleepSeries => series((s) => s.sleepScore);
  static List<double> get strainSeries => series((s) => s.strain);
  static List<double> get stressSeries => series((s) => s.stress);
  static List<double> get energySeries => series((s) => s.energyBank);

  static const List<SleepSegment> lastNightSegments = [
    SleepSegment(SleepStage.awake, 4),
    SleepSegment(SleepStage.core, 92),
    SleepSegment(SleepStage.deep, 48),
    SleepSegment(SleepStage.core, 118),
    SleepSegment(SleepStage.rem, 24),
    SleepSegment(SleepStage.core, 64),
    SleepSegment(SleepStage.deep, 26),
    SleepSegment(SleepStage.rem, 52),
    SleepSegment(SleepStage.awake, 6),
    SleepSegment(SleepStage.core, 42),
    SleepSegment(SleepStage.rem, 44),
  ];

  static int segmentMinutes(SleepStage stage) => lastNightSegments
      .where((s) => s.stage == stage)
      .fold(0, (sum, s) => sum + s.minutes);

  static List<TimelineEvent> get timeline => [
    TimelineEvent(
      kind: TimelineEventKind.sleep,
      title: 'Sleep',
      subtitle: '7h 52m · Score 88',
      time: DateTime(today.year, today.month, today.day, 23, 14),
    ),
    TimelineEvent(
      kind: TimelineEventKind.drink,
      title: 'Water',
      subtitle: '500 ml',
      time: DateTime(today.year, today.month, today.day, 7, 30),
    ),
    TimelineEvent(
      kind: TimelineEventKind.meal,
      title: 'Breakfast',
      subtitle: '420 kcal · Oatmeal & berries',
      time: DateTime(today.year, today.month, today.day, 8, 12),
    ),
    TimelineEvent(
      kind: TimelineEventKind.workout,
      title: 'Outdoor Run',
      subtitle: '5.2 km · 32m · Strain 12.4',
      time: DateTime(today.year, today.month, today.day, 9, 05),
    ),
    TimelineEvent(
      kind: TimelineEventKind.drink,
      title: 'Coffee',
      subtitle: '95 mg caffeine',
      time: DateTime(today.year, today.month, today.day, 10, 40),
    ),
    TimelineEvent(
      kind: TimelineEventKind.meal,
      title: 'Lunch',
      subtitle: '560 kcal · Chicken bowl',
      time: DateTime(today.year, today.month, today.day, 12, 45),
    ),
    TimelineEvent(
      kind: TimelineEventKind.journal,
      title: 'Journal',
      subtitle: 'Morning sunlight 20m',
      time: DateTime(today.year, today.month, today.day, 13, 10),
    ),
  ];

  static const List<MonitorReading> monitors = [
    MonitorReading(label: 'RHR', value: '54', unit: 'bpm', delta: '-2'),
    MonitorReading(label: 'HRV', value: '68', unit: 'ms', delta: '+5%'),
    MonitorReading(label: 'Resp.', value: '14.2', unit: '/min', delta: '-0.3'),
    MonitorReading(label: 'SpO₂', value: '97', unit: '%', delta: '0'),
    MonitorReading(label: 'Skin temp', value: '-0.2', unit: '°C', delta: ''),
    MonitorReading(label: 'Sleep', value: '7h 52m', unit: '', delta: '+22m'),
  ];

  static const List<Workout> workouts = [
    Workout(
      title: 'Outdoor Run',
      kind: 'Run',
      durationMin: 32,
      strain: 12.4,
      avgHr: 148,
      calories: 342,
      distanceKm: 5.2,
    ),
    Workout(
      title: 'Upper Body Strength',
      kind: 'Strength',
      durationMin: 46,
      strain: 8.1,
      avgHr: 118,
      calories: 268,
    ),
    Workout(
      title: 'Easy Walk',
      kind: 'Walk',
      durationMin: 24,
      strain: 2.2,
      avgHr: 96,
      calories: 88,
      distanceKm: 2.1,
    ),
  ];

  static List<StressSample> get stressToday {
    final rnd = Random(11);
    var value = 22.0;
    return List.generate(96, (i) {
      final hour = i * 15 / 60;
      final workoutBump = (hour >= 9 && hour < 9.7) ? 45 : 0;
      final workBump = (hour >= 10 && hour < 12.5) ? 18 : 0;
      final evening = (hour >= 20 && hour < 23) ? -8 : 0;
      value += rnd.nextDouble() * 6 - 3;
      value = (value * 0.85) + 22 * 0.15 + workoutBump + workBump + evening;
      return StressSample(
        DateTime(
          today.year,
          today.month,
          today.day,
        ).add(Duration(minutes: i * 15)),
        value.clamp(4, 96).round(),
      );
    });
  }

  static final List<Meal> meals = [
    Meal(name: 'Breakfast', kcal: 420, time: _t(8, 12)),
    Meal(name: 'Lunch', kcal: 560, time: _t(12, 45)),
    Meal(name: 'Snack', kcal: 150, time: _t(15, 30)),
    Meal(name: 'Dinner', kcal: 300, time: _t(19, 10)),
  ];

  static DateTime _t(int h, int m) => DateTime(2026, 10, 18, h, m);

  static List<double> get cardioLoad30 {
    final rnd = Random(5);
    var load = 42.0;
    return List.generate(30, (_) {
      load += rnd.nextDouble() * 14 - 7;
      return load.clamp(18, 72);
    });
  }

  static const List<List<int>> heartRateZones = [
    [38, 1], // zone, minutes
    [52, 2],
    [41, 3],
    [26, 4],
    [9, 5],
  ];

  static List<DailyScores> _generateScores() {
    final rnd = Random(7);
    var recovery = 61.0;
    var sleep = 74.0;
    var strain = 48.0;
    var stress = 37.0;
    var energy = 58.0;
    return List.generate(30, (i) {
      final date = DateTime(2026, 9, 19 + i);
      recovery = (recovery + rnd.nextDouble() * 16 - 8).clamp(28, 96);
      sleep = (sleep + rnd.nextDouble() * 18 - 9).clamp(42, 98);
      strain = (strain + rnd.nextDouble() * 24 - 12).clamp(8, 92);
      stress = (stress + rnd.nextDouble() * 14 - 7).clamp(9, 82);
      energy = (energy + rnd.nextDouble() * 14 - 7).clamp(15, 95);
      return DailyScores(
        date: date,
        recovery: recovery.round(),
        sleepScore: sleep.round(),
        strain: strain.round(),
        stress: stress.round(),
        energyBank: energy.round(),
        strainLow: 38,
        strainHigh: 62,
      );
    });
  }
}
