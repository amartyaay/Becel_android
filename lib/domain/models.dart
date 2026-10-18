enum SleepStage { awake, rem, core, deep }

class DailyScores {
  const DailyScores({
    required this.date,
    required this.recovery,
    required this.sleepScore,
    required this.strain,
    required this.stress,
    required this.energyBank,
    required this.strainLow,
    required this.strainHigh,
  });

  final DateTime date;
  final int recovery;
  final int sleepScore;
  final int strain;
  final int stress;
  final int energyBank;
  final int strainLow;
  final int strainHigh;
}

enum TimelineEventKind { sleep, workout, meal, drink, journal }

class TimelineEvent {
  const TimelineEvent({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final TimelineEventKind kind;
  final String title;
  final String subtitle;
  final DateTime time;
}

class MonitorReading {
  const MonitorReading({
    required this.label,
    required this.value,
    required this.unit,
    required this.delta,
  });

  final String label;
  final String value;
  final String unit;
  final String delta;
}

class SleepSegment {
  const SleepSegment(this.stage, this.minutes);

  final SleepStage stage;
  final int minutes;
}

class Workout {
  const Workout({
    required this.title,
    required this.kind,
    required this.durationMin,
    required this.strain,
    required this.avgHr,
    required this.calories,
    this.distanceKm,
  });

  final String title;
  final String kind;
  final int durationMin;
  final double strain;
  final int avgHr;
  final int calories;
  final double? distanceKm;
}

class StressSample {
  const StressSample(this.time, this.value);

  final DateTime time;
  final int value;
}

class Meal {
  const Meal({required this.name, required this.kcal, required this.time});

  final String name;
  final int kcal;
  final DateTime time;
}
