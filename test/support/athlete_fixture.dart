import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const healthConnectChannel = MethodChannel('com.becel/health_connect');
const localChannel = MethodChannel('com.becel/local');

/// Deterministic synthetic dataset for a trained 34-year-old lifter who also
/// runs. Used only by tests and the screenshot harness; it is never shipped.
///
/// Values are generated relative to [now] so screens that read the clock
/// see a "last night" and a "today".
class AthleteFixture {
  AthleteFixture({DateTime? now, int seed = 7})
    : now = now ?? DateTime.now(),
      _random = math.Random(seed) {
    _build();
  }

  final DateTime now;
  final math.Random _random;

  static const days = 30;
  static const granted = [
    'android.permission.health.READ_STEPS',
    'android.permission.health.READ_HEART_RATE',
    'android.permission.health.READ_RESTING_HEART_RATE',
    'android.permission.health.READ_HEART_RATE_VARIABILITY',
    'android.permission.health.READ_SLEEP',
    'android.permission.health.READ_EXERCISE',
    'android.permission.health.READ_TOTAL_CALORIES_BURNED',
    'android.permission.health.READ_RESPIRATORY_RATE',
    'android.permission.health.READ_SKIN_TEMPERATURE',
  ];

  final heartMinutes = <List<int>>[];
  final restingHr = <List<Object>>[];
  final hrv = <List<Object>>[];
  final sleepSessions = <Map<String, Object?>>[];
  final workouts = <Map<String, Object?>>[];
  final stepBuckets = <List<int>>[];
  final dailySteps = <String, int>{};

  DateTime get today => DateTime(now.year, now.month, now.day);

  double _noise(double spread) => (_random.nextDouble() * 2 - 1) * spread;

  void _build() {
    for (var offset = days - 1; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final isToday = offset == 0;
      // Training plan: lift Mon/Wed/Fri, run Tue/Sat, intervals Thu, rest Sun.
      final weekday = day.weekday;
      final wake = DateTime(
        day.year,
        day.month,
        day.day,
        6,
        40 + _random.nextInt(35),
      );
      final bed = DateTime(
        day.year,
        day.month,
        day.day - 1,
        22,
        40 + _random.nextInt(60),
      );
      // A short night three days ago and a late night yesterday make the
      // recovery trend move.
      final shortNight = offset == 3;
      final sleepStart = shortNight
          ? bed.add(const Duration(minutes: 95))
          : bed;
      _addSleep(sleepStart, wake, shortNight: shortNight);

      final restingBase = 52.0 + (offset == 2 ? 4 : 0) + (offset == 0 ? 1 : 0);
      restingHr.add([
        wake.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
        (restingBase + _noise(1.5)).roundToDouble(),
      ]);

      // Daytime heart rate, steps, and workouts.
      final dayEnd = isToday
          ? now
          : DateTime(day.year, day.month, day.day, 22, 30);
      var cursor = wake;
      final workout = _workoutFor(weekday, day);
      var steps = 0;
      while (cursor.isBefore(dayEnd)) {
        var bpm = 72 + _noise(8);
        if (workout != null &&
            !cursor.isBefore(workout.start) &&
            cursor.isBefore(
              workout.start.add(Duration(minutes: workout.minutes)),
            )) {
          final progress =
              cursor.difference(workout.start).inMinutes / workout.minutes;
          bpm = workout.bpmAt(progress, _random);
        } else if (cursor.hour == 12 || cursor.hour == 17) {
          bpm = 96 + _noise(10); // commuting / walking
        }
        heartMinutes.add([cursor.millisecondsSinceEpoch, bpm.round()]);
        cursor = cursor.add(const Duration(minutes: 1));
      }
      // Steps in five-minute buckets with some incidental desk movement.
      var bucket = wake;
      while (bucket.isBefore(dayEnd)) {
        var count = 0;
        if (bucket.hour == 12 || bucket.hour == 17) {
          count = 420 + _random.nextInt(140);
        } else if (workout != null &&
            workout.isRun &&
            !bucket.isBefore(workout.start) &&
            bucket.isBefore(
              workout.start.add(Duration(minutes: workout.minutes)),
            )) {
          count = 780 + _random.nextInt(80);
        } else if (_random.nextDouble() < 0.35) {
          count = 4 + _random.nextInt(40); // incidental arm movement
        } else if (_random.nextDouble() < 0.15) {
          count = 120 + _random.nextInt(250);
        }
        if (count > 0) {
          stepBuckets.add([bucket.millisecondsSinceEpoch, count]);
          steps += count;
        }
        bucket = bucket.add(const Duration(minutes: 5));
      }
      dailySteps[_dateKey(day)] = steps;
      if (workout != null && workout.start.isBefore(now)) {
        workouts.add({
          'type': workout.type,
          'start': workout.start.toIso8601String(),
          'minutes': workout.minutes,
        });
      }
    }
    workouts.sort(
      (a, b) => (b['start'] as String).compareTo(a['start'] as String),
    );
  }

  _Workout? _workoutFor(int weekday, DateTime day) {
    DateTime at(int hour, int minute) =>
        DateTime(day.year, day.month, day.day, hour, minute);
    return switch (weekday) {
      DateTime.monday ||
      DateTime.wednesday ||
      DateTime.friday => _Workout('Strength training', at(7, 45), 62, 108, 142),
      DateTime.tuesday => _Workout('Run', at(18, 5), 46, 138, 158, isRun: true),
      DateTime.thursday => _Workout(
        'Run',
        at(18, 10),
        38,
        132,
        176,
        isRun: true,
        intervals: true,
      ),
      DateTime.saturday => _Workout('Run', at(9, 0), 75, 140, 156, isRun: true),
      _ => null,
    };
  }

  void _addSleep(DateTime start, DateTime end, {required bool shortNight}) {
    final intervals = <List<int>>[];
    var cursor = start.add(Duration(minutes: 8 + _random.nextInt(10)));
    var light = 0, deep = 0, rem = 0, awake = 0;
    var cycle = 0;
    while (cursor.isBefore(end)) {
      // ~90-minute cycles: deep early, REM late, brief wakes.
      final deepShare = cycle < 2 ? 30 : 8;
      final remShare = cycle < 2 ? 15 : 30;
      final lightMinutes = 90 - deepShare - remShare - 4;
      for (final (kind, minutes) in [
        ('light', lightMinutes),
        ('deep', deepShare),
        ('rem', remShare),
        ('awake', 4),
      ]) {
        final stageEnd = cursor.add(Duration(minutes: minutes));
        final clipped = stageEnd.isAfter(end) ? end : stageEnd;
        final length = clipped.difference(cursor).inMinutes;
        if (length <= 0) break;
        switch (kind) {
          case 'light':
            light += length;
          case 'deep':
            deep += length;
          case 'rem':
            rem += length;
          default:
            awake += length;
        }
        if (kind != 'awake') {
          intervals.add([
            cursor.millisecondsSinceEpoch,
            clipped.millisecondsSinceEpoch,
          ]);
          // HRV is written a few times inside asleep stages.
          if (kind == 'deep' || (kind == 'light' && cycle.isEven)) {
            final base = shortNight ? 48.0 : 64.0;
            hrv.add([
              cursor.add(Duration(minutes: length ~/ 2)).millisecondsSinceEpoch,
              (base + _noise(7)).roundToDouble(),
            ]);
          }
        }
        // Overnight heart rate.
        var minute = cursor;
        while (minute.isBefore(clipped)) {
          final sleepingBpm = kind == 'deep'
              ? 49
              : kind == 'rem'
              ? 57
              : 53;
          heartMinutes.add([
            minute.millisecondsSinceEpoch,
            (sleepingBpm + _noise(2.5) + (shortNight ? 3 : 0)).round(),
          ]);
          minute = minute.add(const Duration(minutes: 1));
        }
        cursor = clipped;
      }
      cycle++;
    }
    sleepSessions.add({
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'minutes': light + deep + rem,
      'awakeMinutes': awake + 8,
      'lightMinutes': light,
      'deepMinutes': deep,
      'remMinutes': rem,
      'asleepIntervals': intervals,
    });
  }

  List<List<int>> _bucketed(Iterable<List<int>> samples, int minutes) {
    final buckets = <int, List<int>>{};
    final size = minutes * 60 * 1000;
    for (final sample in samples) {
      final key = sample[0] ~/ size;
      (buckets[key] ??= []).add(sample[1]);
    }
    final keys = buckets.keys.toList()..sort();
    return [
      for (final key in keys)
        [
          key * size,
          (buckets[key]!.reduce((a, b) => a + b) / buckets[key]!.length)
              .round(),
        ],
    ];
  }

  Map<String, Object?> heartDetail() {
    final todayStart = today.millisecondsSinceEpoch;
    final weekStart = today
        .subtract(const Duration(days: 6))
        .millisecondsSinceEpoch;
    final sorted = [...heartMinutes]..sort((a, b) => a[0].compareTo(b[0]));
    final todaySamples = sorted.where((s) => s[0] >= todayStart).toList();
    final values = todaySamples.map((s) => s[1]).toList();
    return {
      'status': 'ready',
      'granted': granted,
      'checkedAt': now.toIso8601String(),
      'series': _bucketed(todaySamples, 5),
      'weeklySeries': _bucketed(sorted.where((s) => s[0] >= weekStart), 5),
      'minuteSeries': sorted,
      'todaySteps': stepBuckets.where((s) => s[0] >= todayStart).toList(),
      'stepBuckets': stepBuckets,
      'latestBpm': values.isEmpty ? null : values.last,
      'latestAt': todaySamples.isEmpty
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              todaySamples.last[0],
            ).toIso8601String(),
      'minBpm': values.isEmpty ? null : values.reduce(math.min),
      'avgBpm': values.isEmpty
          ? null
          : (values.reduce((a, b) => a + b) / values.length).round(),
      'maxBpm': values.isEmpty ? null : values.reduce(math.max),
      'restingHrBpm': (restingHr.last[1] as double).round(),
      'hrvRmssd': hrv.last[1],
      'restingHrSamples': restingHr,
      'hrvSamples': hrv,
      'activityEstimate': _activityEstimate(sorted),
    };
  }

  Map<String, Object?> _activityEstimate(List<List<int>> sorted) {
    const age = 34;
    final maxHr = 208 - 0.7 * age;
    final resting = restingHr.last[1] as double;
    final reserve = maxHr - resting;
    final zones = List<double>.filled(5, 0);
    final dates = <String>[];
    final dailyEq = <double?>[];
    final dailyCoverage = <double>[];
    for (var offset = 6; offset >= 0; offset--) {
      final day = today.subtract(Duration(days: offset));
      final start = day.millisecondsSinceEpoch;
      final end = day.add(const Duration(days: 1)).millisecondsSinceEpoch;
      final daySamples = sorted.where((s) => s[0] >= start && s[0] < end);
      var eq = 0.0;
      var coverage = 0.0;
      for (final sample in daySamples) {
        final hrr = (sample[1] - resting) / reserve;
        final zone = hrr < .3
            ? 0
            : hrr < .4
            ? 1
            : hrr < .6
            ? 2
            : hrr < .9
            ? 3
            : 4;
        zones[zone] += 1;
        coverage += 1;
        if (zone == 2) eq += 1;
        if (zone >= 3) eq += 2;
      }
      dates.add(_dateKey(day));
      dailyEq.add(coverage == 0 ? null : eq);
      dailyCoverage.add(coverage);
    }
    return {
      'age': age,
      'estimatedMaxHrBpm': maxHr.round(),
      'restingHrBpm': resting,
      'restingHrAt': restingHr.last[0],
      'moderateMinutes': zones[2],
      'vigorousMinutes': zones[3] + zones[4],
      'usableDays': dailyCoverage.where((m) => m > 0).length,
      'dailyDates': dates,
      'dailyEquivalentMinutes': dailyEq,
      'dailyCoverageMinutes': dailyCoverage,
      'zoneMinutes': zones,
      'zoneRanges': const ['<30%', '30–<40%', '40–<60%', '60–<90%', '≥90%'],
    };
  }

  Map<String, Object?> sleepDetail() => {
    'status': 'ready',
    'granted': granted,
    'checkedAt': now.toIso8601String(),
    'sessions': sleepSessions.reversed.toList(),
  };

  Map<String, Object?> summary() {
    final lastNight = sleepSessions.last;
    final latestWorkout = workouts.isEmpty ? null : workouts.first;
    return {
      'status': 'ready',
      'granted': granted,
      'checkedAt': now.toIso8601String(),
      'fitbitAirMetadataMatched': true,
      'stepCount': dailySteps[_dateKey(today)],
      'heartRateBpm': heartMinutes.last[1],
      'heartRateAt': DateTime.fromMillisecondsSinceEpoch(
        heartMinutes.last[0],
      ).toIso8601String(),
      'heartRateSource': 'Fitbit Air',
      'sleepSessionMinutes': lastNight['minutes'],
      'sleepStart': lastNight['start'],
      'sleepEnd': lastNight['end'],
      'sleepSource': 'Fitbit Air',
      'workoutType': latestWorkout?['type'],
      'workoutStart': latestWorkout?['start'],
      'workoutDurationMinutes': latestWorkout?['minutes'],
      'workoutSource': 'Fitbit Air',
    };
  }

  Map<String, Object?> activityDetail() => {
    'status': 'ready',
    'granted': granted,
    'checkedAt': now.toIso8601String(),
    'workouts': workouts,
    'caloriesTotalToday': 2310 + (now.hour * 60 + now.minute) ~/ 3,
  };

  Map<String, Object?> bodyDetail() => {
    'status': 'ready',
    'granted': granted,
    'checkedAt': now.toIso8601String(),
    'respiratoryRate': 14.9,
    'respiratoryBaseline': 14.4,
    'skinTempBaselineC': 33.9,
    'skinTempDeviationC': 0.2,
  };

  Map<String, Object?> trends7d() {
    final dates = [
      for (var offset = 6; offset >= 0; offset--)
        today.subtract(Duration(days: offset)),
    ];
    return {
      'status': 'ready',
      'granted': granted,
      'checkedAt': now.toIso8601String(),
      'dates': dates.map(_dateKey).toList(),
      'steps': dates.map((d) => dailySteps[_dateKey(d)]).toList(),
      'hrAvg': dates.map((_) => 70 + _random.nextInt(6)).toList(),
      'sleepMinutes': dates.map((d) {
        final match = sleepSessions.where(
          (s) => (s['end'] as String).startsWith(_dateKey(d)),
        );
        return match.isEmpty ? null : match.first['minutes'];
      }).toList(),
    };
  }

  Object? handle(MethodCall call) => switch (call.method) {
    'inspect' => {
      'availability': 'available',
      'granted': granted,
      'requested': granted,
      'checkedAt': now.toIso8601String(),
    },
    'readSummary' => summary(),
    'readHeartDetail' => heartDetail(),
    'readSleepDetail' => sleepDetail(),
    'readActivityDetail' => activityDetail(),
    'readBodyDetail' => bodyDetail(),
    'readTrends7d' => trends7d(),
    'readFitnessAge' => 34,
    'saveFitnessAge' => true,
    _ => <String, Object?>{},
  };

  /// A saved local log with a body profile and a few lifts.
  String localJson() => jsonEncode({
    'version': 2,
    'checkIns': [
      {
        'date': _dateKey(today),
        'tags': ['normal'],
        'at': now.toIso8601String(),
        'note': null,
      },
    ],
    'strengthDays': const <String>[],
    'profile': {
      'age': 34,
      'sex': 'male',
      'heightCm': 180.0,
      'weightKg': 82.0,
      'bodyFatPercent': 15.0,
    },
  });

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(healthConnectChannel, (call) async {
      return handle(call);
    });
  }
}

class _Workout {
  _Workout(
    this.type,
    this.start,
    this.minutes,
    this.lowBpm,
    this.highBpm, {
    this.isRun = false,
    this.intervals = false,
  });

  final String type;
  final DateTime start;
  final int minutes;
  final int lowBpm;
  final int highBpm;
  final bool isRun;
  final bool intervals;

  double bpmAt(double progress, math.Random random) {
    final jitter = (random.nextDouble() * 2 - 1) * 5;
    if (progress < 0.12) return lowBpm - 20 + progress * 160 + jitter;
    if (intervals) {
      final minute = (progress * minutes).floor();
      return (minute % 4 < 2 ? highBpm : lowBpm) + jitter;
    }
    if (type.contains('Strength')) {
      final minute = (progress * minutes).floor();
      return (minute % 3 == 0 ? highBpm : lowBpm) + jitter;
    }
    return lowBpm + (highBpm - lowBpm) * progress + jitter;
  }
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
