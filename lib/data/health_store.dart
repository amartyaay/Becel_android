import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/estimates.dart';
import '../domain/metrics.dart';
import '../domain/performance.dart';
import '../domain/profile.dart';
import '../domain/strength.dart';
import 'health_connect_service.dart';
import 'local_store.dart';

/// One consistent read of every Health Connect surface Becel uses.
///
/// All tabs read from the same snapshot, so Today, Training, Sleep, and
/// Trends cannot disagree about the same night, session, or estimate.
class HealthSnapshot {
  const HealthSnapshot({
    required this.inspection,
    required this.summary,
    required this.heart,
    required this.sleep,
    required this.activity,
    required this.body,
    required this.trends,
    required this.age,
    required this.activityEstimate,
    required this.loadedAt,
    required this.performance,
    this.profile,
    this.cardioFitness,
  });

  final HealthConnectInspection inspection;
  final HealthSummary? summary;
  final HeartDetail? heart;
  final SleepDetail? sleep;
  final ActivityDetail? activity;
  final BodyDetail? body;
  final Trends7d? trends;
  final int? age;
  final ActivityEstimate? activityEstimate;
  final DateTime loadedAt;
  final Performance performance;
  final BodyProfile? profile;
  final CardioFitness? cardioFitness;

  bool get isAvailable => inspection.isAvailable;
  bool get hasAccess => inspection.hasAnyPermission;
  bool get allPermissionsGranted => inspection.allPermissionsGranted;
  bool get airMatched => summary?.fitbitAirMetadataMatched == true;
  SleepNight? get selectedNight => sleep?.selectedRecentSession;
  RecoveryReadiness get recoveryStatus => performance.recovery;
  RecoveryEstimate? get recovery => performance.recovery.estimate;
  List<RecoveryHistoryPoint> get recoveryHistory => performance.recoveryHistory;

  String? get error =>
      heart?.error ??
      sleep?.error ??
      activity?.error ??
      body?.error ??
      summary?.error ??
      trends?.error ??
      inspection.error;

  bool get hasAnyRecord =>
      summary?.stepCount != null ||
      summary?.heartRateBpm != null ||
      summary?.sleepSessionMinutes != null ||
      recovery != null ||
      (heart?.minuteSeries.isNotEmpty ?? false) ||
      (sleep?.sessions.isNotEmpty ?? false) ||
      (activity?.workouts.isNotEmpty ?? false) ||
      (trends?.steps.any((value) => value != null) ?? false) ||
      (trends?.hrAvg.any((value) => value != null) ?? false) ||
      (trends?.sleepMinutes.any((value) => value != null) ?? false);
}

/// Shared, coalesced Health Connect loader.
///
/// A permission change or explicit invalidation bumps
/// [HealthConnectService.dataRevision]; local edits (profile, lifts, sleep
/// corrections) recompute metrics without new platform reads.
class HealthStore extends ChangeNotifier {
  HealthStore._() {
    HealthConnectService.instance.dataRevision.addListener(_onRevision);
    LocalStore.instance.addListener(_onLocalChange);
  }

  static final instance = HealthStore._();
  static final _service = HealthConnectService.instance;

  HealthSnapshot? _snapshot;
  bool _loading = true;
  String? _error;
  Future<void>? _inFlight;
  int _generation = 0;
  _RawRead? _raw;

  HealthSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  String? get error => _error ?? _snapshot?.error;
  bool get hasSnapshot => _snapshot != null;

  void _onRevision() {
    _snapshot = null;
    _error = null;
    refresh(force: true);
  }

  void _onLocalChange() {
    final raw = _raw;
    if (raw == null || _inFlight != null) return;
    _snapshot = _compose(raw);
    notifyListeners();
  }

  /// True while the shown snapshot is the cached copy from the last launch
  /// and fresh Health Connect data is still loading.
  bool get showingCached => _showingCached;
  bool _showingCached = false;
  bool _restoreTried = false;

  Future<void> ensureLoaded() {
    if (_snapshot != null) return Future<void>.value();
    if (!_restoreTried) {
      _restoreTried = true;
      // Show the last read immediately, then refresh underneath it.
      _restoreCache();
    }
    return refresh();
  }

  Future<void> _restoreCache() async {
    final generation = _generation;
    try {
      await LocalStore.instance.ensureLoaded();
      final text = await LocalStore.instance.readSnapshotCache();
      if (text == null || text.isEmpty) return;
      final decoded = await compute(_decodeCache, text);
      if (decoded == null || generation != _generation || _raw != null) return;
      Map<String, dynamic> part(String key) =>
          (decoded[key] as Map?)?.cast<String, dynamic>() ?? const {};
      final raw = _RawRead(
        inspection: HealthConnectInspection.fromMap(part('inspect')),
        summary: HealthSummary.fromMap(part('summary')),
        heart: HeartDetail.fromMap(part('heart')),
        sleep: SleepDetail.fromMap(part('sleep')),
        activity: ActivityDetail.fromMap(part('activity')),
        body: BodyDetail.fromMap(part('body')),
        trends: Trends7d.fromMap(part('trends')),
        age: decoded['age'] as int?,
      );
      final snapshot = _compose(raw);
      // A live read may have finished while the cache was decoding.
      if (generation != _generation || _raw != null) return;
      _snapshot = snapshot;
      _showingCached = true;
      notifyListeners();
    } catch (_) {
      // A missing or outdated cache just means a normal first load.
    }
  }

  Future<void> _saveCache(int? age) async {
    final raw = Map<String, Object?>.from(_service.lastRaw)..['age'] = age;
    try {
      final text = await compute(_encodeCache, raw);
      if (text != null) await LocalStore.instance.writeSnapshotCache(text);
    } catch (_) {}
  }

  Future<void> refresh({bool force = false}) {
    final active = _inFlight;
    if (active != null) return active;
    _loading = true;
    notifyListeners();
    final request = _load(force: force);
    _inFlight = request;
    return request;
  }

  Future<void> _load({required bool force}) async {
    final generation = _generation;
    try {
      await LocalStore.instance.ensureLoaded();
      final inspection = await _service.inspect();
      HealthSummary? summary;
      HeartDetail? heart;
      SleepDetail? sleep;
      ActivityDetail? activity;
      BodyDetail? body;
      Trends7d? trends;
      if (inspection.isAvailable && inspection.hasAnyPermission) {
        final values = await Future.wait<Object?>([
          _service.readSummary(),
          _service.readHeartDetail(refresh: force),
          _service.readSleepDetail(),
          _service.readActivityDetail(),
          _service.readBodyDetail(),
          _service.readTrends7d(),
        ]);
        summary = values[0] as HealthSummary?;
        heart = values[1] as HeartDetail?;
        sleep = values[2] as SleepDetail?;
        activity = values[3] as ActivityDetail?;
        body = values[4] as BodyDetail?;
        trends = values[5] as Trends7d?;
      }
      if (generation != _generation) return;
      final age = await _service.readFitnessAge();
      if (generation != _generation) return;
      final raw = _RawRead(
        inspection: inspection,
        summary: summary,
        heart: heart,
        sleep: sleep,
        activity: activity,
        body: body,
        trends: trends,
        age: age,
      );
      _raw = raw;
      final snapshot = _compose(raw);
      if (generation != _generation) return;
      _snapshot = snapshot;
      _showingCached = false;
      _error = snapshot.error;
      if (snapshot.error == null && snapshot.hasAccess) _saveCache(age);
    } catch (error) {
      if (generation == _generation) _error = error.toString();
    } finally {
      if (generation == _generation) {
        _loading = false;
        _inFlight = null;
        notifyListeners();
      }
    }
    // Health Connect can reject the first read right after install or a
    // permission change while its cache settles. Retry once, quietly.
    final failed = _snapshot == null || (_snapshot?.error != null && !_retried);
    if (failed && !_retried && generation == _generation) {
      _retried = true;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (generation == _generation) await refresh(force: true);
    } else if (_snapshot?.error == null) {
      _retried = false;
    }
  }

  bool _retried = false;

  HealthSnapshot _compose(_RawRead raw) {
    final now = DateTime.now();
    final stored = LocalStore.instance.profile;
    final body = raw.body;
    // Measurements recorded in Google Health (or a scale app) win over the
    // fallback values typed in Settings.
    final profile = BodyProfile(
      age: stored?.age ?? raw.age,
      sex: stored?.sex,
      heightCm: body?.heightCm ?? stored?.heightCm,
      weightKg: body?.weightKg ?? stored?.weightKg,
      bodyFatPercent: body?.bodyFatPercent ?? stored?.bodyFatPercent,
      maxHrOverride: stored?.maxHrOverride,
      sleepNeedMinutes: stored?.sleepNeedMinutes,
      correctSleepOnset: stored?.correctSleepOnset ?? true,
    );
    final performance = buildPerformance(
      heart: raw.heart,
      sleep: raw.sleep,
      body: raw.body,
      activity: raw.activity,
      profile: profile,
      fallbackAge: raw.age,
      strengthSessions: [
        for (final workout in raw.activity?.workouts ?? const <WorkoutEntry>[])
          if (isStrengthWorkout(workout.type))
            StrengthSession(
              id: workout.start.toIso8601String(),
              start: workout.start,
              durationMinutes: workout.minutes,
              // Synced sessions carry no RPE; 6 maps to the Compendium's
              // moderate resistance-training MET (5.0).
              sessionRpe: 6,
            ),
      ],
      onsetOverrides: const {},
      now: now,
    );
    return HealthSnapshot(
      inspection: raw.inspection,
      summary: raw.summary,
      heart: raw.heart,
      sleep: raw.sleep,
      activity: raw.activity,
      body: raw.body,
      trends: raw.trends,
      age: profile.age ?? raw.age,
      activityEstimate: raw.heart == null
          ? null
          : _service.activityEstimateFor(raw.heart!, raw.age),
      loadedAt: now,
      performance: performance,
      profile: profile,
      cardioFitness: estimateCardioFitness(
        profile: profile,
        maxHr: performance.maxHr,
        restingBpm: performance.restingBpm,
      ),
    );
  }

  @visibleForTesting
  void resetForTest() {
    _generation++;
    _snapshot = null;
    _error = null;
    _loading = true;
    _inFlight = null;
    _raw = null;
    _retried = true; // Tests control their own retries.
    _showingCached = false;
    _restoreTried = true; // Tests start from live reads only.
  }
}

const _cacheVersion = 1;

Map<String, dynamic>? _decodeCache(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map || decoded['version'] != _cacheVersion) return null;
  return (decoded['raw'] as Map?)?.cast<String, dynamic>();
}

String? _encodeCache(Map<String, Object?> raw) {
  try {
    return jsonEncode({'version': _cacheVersion, 'raw': raw});
  } catch (_) {
    return null; // A value the platform sent that JSON cannot hold.
  }
}

class _RawRead {
  const _RawRead({
    required this.inspection,
    required this.summary,
    required this.heart,
    required this.sleep,
    required this.activity,
    required this.body,
    required this.trends,
    required this.age,
  });

  final HealthConnectInspection inspection;
  final HealthSummary? summary;
  final HeartDetail? heart;
  final SleepDetail? sleep;
  final ActivityDetail? activity;
  final BodyDetail? body;
  final Trends7d? trends;
  final int? age;
}
