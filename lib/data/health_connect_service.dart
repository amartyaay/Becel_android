import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class HealthConnectService {
  HealthConnectService._();

  static final instance = HealthConnectService._();
  static const _channel = MethodChannel('com.becel/health_connect');

  final dataRevision = ValueNotifier<int>(0);

  void notifyDataChanged() => dataRevision.value++;

  Future<HealthConnectInspection> inspect() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('inspect');
      return HealthConnectInspection.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return HealthConnectInspection.error(error.message ?? error.code);
    } on MissingPluginException {
      return HealthConnectInspection.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<HealthConnectInspection> requestPermissions() async {
    try {
      await _channel.invokeMapMethod<String, dynamic>('requestPermissions');
      return inspect();
    } on PlatformException catch (error) {
      return HealthConnectInspection.error(error.message ?? error.code);
    } on MissingPluginException {
      return HealthConnectInspection.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<HealthSummary> readSummary() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readSummary',
      );
      return HealthSummary.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return HealthSummary.error(error.message ?? error.code);
    } on MissingPluginException {
      return HealthSummary.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<HeartDetail> readHeartDetail() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readHeartDetail',
      );
      return HeartDetail.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return HeartDetail.error(error.message ?? error.code);
    } on MissingPluginException {
      return HeartDetail.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<SleepDetail> readSleepDetail() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readSleepDetail',
      );
      return SleepDetail.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return SleepDetail.error(error.message ?? error.code);
    } on MissingPluginException {
      return SleepDetail.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<Trends7d> readTrends7d() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readTrends7d',
      );
      return Trends7d.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return Trends7d.error(error.message ?? error.code);
    } on MissingPluginException {
      return Trends7d.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<ActivityDetail> readActivityDetail() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readActivityDetail',
      );
      return ActivityDetail.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return ActivityDetail.error(error.message ?? error.code);
    } on MissingPluginException {
      return ActivityDetail.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<BodyDetail> readBodyDetail() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readBodyDetail',
      );
      return BodyDetail.fromMap(result ?? const {});
    } on PlatformException catch (error) {
      return BodyDetail.error(error.message ?? error.code);
    } on MissingPluginException {
      return BodyDetail.error(
        'Health Connect is available in the Android app only.',
      );
    }
  }

  Future<bool> openProviderStore() async {
    try {
      return await _channel.invokeMethod<bool>('openProviderStore') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

class HealthConnectInspection {
  const HealthConnectInspection({
    required this.availability,
    required this.granted,
    required this.requested,
    this.checkedAt,
    this.error,
  });

  factory HealthConnectInspection.fromMap(Map<String, dynamic> map) {
    return HealthConnectInspection(
      availability: map['availability'] as String? ?? 'unavailable',
      granted: _stringList(map['granted']),
      requested: _stringList(map['requested']),
      checkedAt: map['checkedAt'] as String?,
    );
  }

  factory HealthConnectInspection.error(String message) {
    return HealthConnectInspection(
      availability: 'error',
      granted: const [],
      requested: const [],
      error: message,
    );
  }

  final String availability;
  final List<String> granted;
  final List<String> requested;
  final String? checkedAt;
  final String? error;

  bool get isAvailable => availability == 'available';
  bool get hasAnyPermission => granted.isNotEmpty;
  bool get allPermissionsGranted => requested.every(granted.contains);

  String get stateLabel => switch (availability) {
    'available' when allPermissionsGranted => 'Access allowed',
    'available' when hasAnyPermission => 'Partial access',
    'available' => 'Ready to connect',
    'needsUpdate' => 'Update needed',
    'unavailable' => 'Not available',
    _ => 'Check status',
  };

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }
}

class HealthSummary {
  const HealthSummary({
    required this.status,
    required this.granted,
    required this.checkedAt,
    this.fitbitAirMetadataMatched = false,
    this.stepCount,
    this.heartRateBpm,
    this.heartRateAt,
    this.heartRateSource,
    this.heartRateDevice,
    this.sleepSessionMinutes,
    this.sleepStart,
    this.sleepEnd,
    this.sleepSource,
    this.sleepDevice,
    this.workoutType,
    this.workoutStart,
    this.workoutDurationMinutes,
    this.workoutSource,
    this.workoutDevice,
    this.error,
  });

  factory HealthSummary.fromMap(Map<String, dynamic> map) {
    return HealthSummary(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      fitbitAirMetadataMatched: map['fitbitAirMetadataMatched'] == true,
      stepCount: _intValue(map['stepCount']),
      heartRateBpm: _intValue(map['heartRateBpm']),
      heartRateAt: map['heartRateAt'] as String?,
      heartRateSource: map['heartRateSource'] as String?,
      heartRateDevice: map['heartRateDevice'] as String?,
      sleepSessionMinutes: _intValue(map['sleepSessionMinutes']),
      sleepStart: map['sleepStart'] as String?,
      sleepEnd: map['sleepEnd'] as String?,
      sleepSource: map['sleepSource'] as String?,
      sleepDevice: map['sleepDevice'] as String?,
      workoutType: map['workoutType'] as String?,
      workoutStart: map['workoutStart'] as String?,
      workoutDurationMinutes: _intValue(map['workoutDurationMinutes']),
      workoutSource: map['workoutSource'] as String?,
      workoutDevice: map['workoutDevice'] as String?,
    );
  }

  factory HealthSummary.error(String message) {
    return HealthSummary(
      status: 'error',
      granted: const [],
      checkedAt: null,
      fitbitAirMetadataMatched: false,
      error: message,
    );
  }

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final bool fitbitAirMetadataMatched;
  final int? stepCount;
  final int? heartRateBpm;
  final String? heartRateAt;
  final String? heartRateSource;
  final String? heartRateDevice;
  final int? sleepSessionMinutes;
  final String? sleepStart;
  final String? sleepEnd;
  final String? sleepSource;
  final String? sleepDevice;
  final String? workoutType;
  final String? workoutStart;
  final int? workoutDurationMinutes;
  final String? workoutSource;
  final String? workoutDevice;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get isReady => status == 'ready' && hasAccess;
  bool get canReadSteps =>
      granted.contains('android.permission.health.READ_STEPS');
  bool get canReadHeartRate =>
      granted.contains('android.permission.health.READ_HEART_RATE');
  bool get canReadSleep =>
      granted.contains('android.permission.health.READ_SLEEP');
  bool get canReadExercise =>
      granted.contains('android.permission.health.READ_EXERCISE');

  static int? _intValue(Object? value) => switch (value) {
    final int number => number,
    final num number => number.round(),
    _ => null,
  };
}

int? _intFrom(Object? value) => switch (value) {
  final int number => number,
  final num number => number.round(),
  _ => null,
};

double? _doubleFrom(Object? value) => switch (value) {
  final num number => number.toDouble(),
  _ => null,
};

List<int?> _intListFrom(Object? value) {
  if (value is! List) return const [];
  return value.map(_intFrom).toList();
}

class HeartSample {
  const HeartSample({required this.at, required this.bpm});

  final DateTime at;
  final int bpm;
}

class HeartDetail {
  const HeartDetail({
    required this.status,
    required this.granted,
    this.checkedAt,
    this.series = const [],
    this.latestBpm,
    this.latestAt,
    this.minBpm,
    this.avgBpm,
    this.maxBpm,
    this.zoneMinutes = const [0, 0, 0, 0, 0],
    this.restingHrBpm,
    this.restingHrBaseline,
    this.hrvRmssd,
    this.hrvBaseline,
    this.error,
  });

  factory HeartDetail.fromMap(Map<String, dynamic> map) {
    final rawSeries = map['series'];
    final samples = <HeartSample>[];
    if (rawSeries is List) {
      for (final entry in rawSeries) {
        if (entry is! List || entry.length < 2) continue;
        final millis = _intFrom(entry[0]);
        final bpm = _intFrom(entry[1]);
        if (millis == null || bpm == null) continue;
        samples.add(
          HeartSample(at: DateTime.fromMillisecondsSinceEpoch(millis), bpm: bpm),
        );
      }
    }
    return HeartDetail(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      series: samples,
      latestBpm: _intFrom(map['latestBpm']),
      latestAt: map['latestAt'] as String?,
      minBpm: _intFrom(map['minBpm']),
      avgBpm: _intFrom(map['avgBpm']),
      maxBpm: _intFrom(map['maxBpm']),
      zoneMinutes: _intListFrom(map['zoneMinutes']).map((e) => e ?? 0).toList(),
      restingHrBpm: _intFrom(map['restingHrBpm']),
      restingHrBaseline: _intFrom(map['restingHrBaseline']),
      hrvRmssd: _doubleFrom(map['hrvRmssd']),
      hrvBaseline: _doubleFrom(map['hrvBaseline']),
    );
  }

  factory HeartDetail.error(String message) => HeartDetail(
    status: 'error',
    granted: const [],
    error: message,
  );

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final List<HeartSample> series;
  final int? latestBpm;
  final String? latestAt;
  final int? minBpm;
  final int? avgBpm;
  final int? maxBpm;
  final List<int> zoneMinutes;
  final int? restingHrBpm;
  final int? restingHrBaseline;
  final double? hrvRmssd;
  final double? hrvBaseline;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get canReadHeartRate =>
      granted.contains('android.permission.health.READ_HEART_RATE');
  bool get canReadRestingHr =>
      granted.contains('android.permission.health.READ_RESTING_HEART_RATE');
  bool get canReadHrv => granted.contains(
    'android.permission.health.READ_HEART_RATE_VARIABILITY',
  );
}

class SleepNight {
  const SleepNight({
    required this.start,
    required this.end,
    required this.minutes,
    required this.awakeMinutes,
    required this.lightMinutes,
    required this.deepMinutes,
    required this.remMinutes,
  });

  factory SleepNight.fromMap(Map<String, dynamic> map) {
    return SleepNight(
      start: DateTime.parse(map['start'] as String),
      end: DateTime.parse(map['end'] as String),
      minutes: _intFrom(map['minutes']) ?? 0,
      awakeMinutes: _intFrom(map['awakeMinutes']) ?? 0,
      lightMinutes: _intFrom(map['lightMinutes']) ?? 0,
      deepMinutes: _intFrom(map['deepMinutes']) ?? 0,
      remMinutes: _intFrom(map['remMinutes']) ?? 0,
    );
  }

  final DateTime start;
  final DateTime end;
  final int minutes;
  final int awakeMinutes;
  final int lightMinutes;
  final int deepMinutes;
  final int remMinutes;

  int get deepRemMinutes => deepMinutes + remMinutes;
}

class SleepDetail {
  const SleepDetail({
    required this.status,
    required this.granted,
    this.checkedAt,
    this.sessions = const [],
    this.error,
  });

  factory SleepDetail.fromMap(Map<String, dynamic> map) {
    final rawSessions = map['sessions'];
    final sessions = <SleepNight>[];
    if (rawSessions is List) {
      for (final entry in rawSessions) {
        if (entry is Map) {
          try {
            sessions.add(SleepNight.fromMap(entry.cast<String, dynamic>()));
          } on FormatException {
            continue;
          }
        }
      }
    }
    return SleepDetail(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      sessions: sessions,
    );
  }

  factory SleepDetail.error(String message) => SleepDetail(
    status: 'error',
    granted: const [],
    error: message,
  );

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final List<SleepNight> sessions;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get canReadSleep =>
      granted.contains('android.permission.health.READ_SLEEP');

  SleepNight? get lastNight {
    final now = DateTime.now();
    final recent = sessions
        .where((session) => now.difference(session.end).inHours <= 24)
        .toList();
    if (recent.isEmpty) return sessions.isEmpty ? null : sessions.first;
    recent.sort((a, b) => b.minutes.compareTo(a.minutes));
    return recent.first;
  }
}

class Trends7d {
  const Trends7d({
    required this.status,
    required this.granted,
    this.checkedAt,
    this.dates = const [],
    this.steps = const [],
    this.hrAvg = const [],
    this.sleepMinutes = const [],
    this.error,
  });

  factory Trends7d.fromMap(Map<String, dynamic> map) {
    final rawDates = map['dates'];
    return Trends7d(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      dates: rawDates is List ? rawDates.whereType<String>().toList() : const [],
      steps: _intListFrom(map['steps']),
      hrAvg: _intListFrom(map['hrAvg']),
      sleepMinutes: _intListFrom(map['sleepMinutes']),
    );
  }

  factory Trends7d.error(String message) => Trends7d(
    status: 'error',
    granted: const [],
    error: message,
  );

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final List<String> dates;
  final List<int?> steps;
  final List<int?> hrAvg;
  final List<int?> sleepMinutes;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get canReadSteps =>
      granted.contains('android.permission.health.READ_STEPS');
  bool get canReadHeartRate =>
      granted.contains('android.permission.health.READ_HEART_RATE');
  bool get canReadSleep =>
      granted.contains('android.permission.health.READ_SLEEP');
}

class WorkoutEntry {
  const WorkoutEntry({required this.type, required this.start, required this.minutes});

  factory WorkoutEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutEntry(
      type: map['type'] as String? ?? 'Workout',
      start: DateTime.parse(map['start'] as String),
      minutes: _intFrom(map['minutes']) ?? 0,
    );
  }

  final String type;
  final DateTime start;
  final int minutes;
}

class ActivityDetail {
  const ActivityDetail({
    required this.status,
    required this.granted,
    this.checkedAt,
    this.workouts = const [],
    this.distanceMetersToday,
    this.floorsToday,
    this.caloriesTotalToday,
    this.caloriesActiveToday,
    this.error,
  });

  factory ActivityDetail.fromMap(Map<String, dynamic> map) {
    final rawWorkouts = map['workouts'];
    final workouts = <WorkoutEntry>[];
    if (rawWorkouts is List) {
      for (final entry in rawWorkouts) {
        if (entry is Map) {
          try {
            workouts.add(WorkoutEntry.fromMap(entry.cast<String, dynamic>()));
          } on FormatException {
            continue;
          }
        }
      }
    }
    return ActivityDetail(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      workouts: workouts,
      distanceMetersToday: _intFrom(map['distanceMetersToday']),
      floorsToday: _intFrom(map['floorsToday']),
      caloriesTotalToday: _intFrom(map['caloriesTotalToday']),
      caloriesActiveToday: _intFrom(map['caloriesActiveToday']),
    );
  }

  factory ActivityDetail.error(String message) => ActivityDetail(
    status: 'error',
    granted: const [],
    error: message,
  );

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final List<WorkoutEntry> workouts;
  final int? distanceMetersToday;
  final int? floorsToday;
  final int? caloriesTotalToday;
  final int? caloriesActiveToday;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get canReadExercise =>
      granted.contains('android.permission.health.READ_EXERCISE');
  bool get canReadDistance =>
      granted.contains('android.permission.health.READ_DISTANCE');
  bool get canReadFloors =>
      granted.contains('android.permission.health.READ_FLOORS_CLIMBED');
  bool get canReadCaloriesTotal =>
      granted.contains('android.permission.health.READ_TOTAL_CALORIES_BURNED');
  bool get canReadCaloriesActive => granted.contains(
    'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
  );
}

class BodyDetail {
  const BodyDetail({
    required this.status,
    required this.granted,
    this.checkedAt,
    this.spo2Percent,
    this.spo2Baseline,
    this.respiratoryRate,
    this.respiratoryBaseline,
    this.skinTempBaselineC,
    this.skinTempDeviationC,
    this.vo2Max,
    this.error,
  });

  factory BodyDetail.fromMap(Map<String, dynamic> map) {
    return BodyDetail(
      status: map['status'] as String? ?? 'unavailable',
      granted: HealthConnectInspection._stringList(map['granted']),
      checkedAt: map['checkedAt'] as String?,
      spo2Percent: _doubleFrom(map['spo2Percent']),
      spo2Baseline: _doubleFrom(map['spo2Baseline']),
      respiratoryRate: _doubleFrom(map['respiratoryRate']),
      respiratoryBaseline: _doubleFrom(map['respiratoryBaseline']),
      skinTempBaselineC: _doubleFrom(map['skinTempBaselineC']),
      skinTempDeviationC: _doubleFrom(map['skinTempDeviationC']),
      vo2Max: _doubleFrom(map['vo2Max']),
    );
  }

  factory BodyDetail.error(String message) => BodyDetail(
    status: 'error',
    granted: const [],
    error: message,
  );

  final String status;
  final List<String> granted;
  final String? checkedAt;
  final double? spo2Percent;
  final double? spo2Baseline;
  final double? respiratoryRate;
  final double? respiratoryBaseline;
  final double? skinTempBaselineC;
  final double? skinTempDeviationC;
  final double? vo2Max;
  final String? error;

  bool get hasAccess => granted.isNotEmpty;
  bool get canReadSpo2 =>
      granted.contains('android.permission.health.READ_OXYGEN_SATURATION');
  bool get canReadRespiratory =>
      granted.contains('android.permission.health.READ_RESPIRATORY_RATE');
  bool get canReadSkinTemp =>
      granted.contains('android.permission.health.READ_SKIN_TEMPERATURE');
  bool get canReadVo2Max =>
      granted.contains('android.permission.health.READ_VO2_MAX');
}
