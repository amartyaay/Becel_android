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
      error: message,
    );
  }

  final String status;
  final List<String> granted;
  final String? checkedAt;
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
  bool get fitbitAirDetected =>
      [
        heartRateDevice,
        sleepDevice,
        workoutDevice,
        heartRateSource,
        sleepSource,
        workoutSource,
      ].whereType<String>().any(
        (value) => value.toLowerCase().contains('fitbit air'),
      );

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
