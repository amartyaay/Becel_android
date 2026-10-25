import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/profile.dart';
import '../domain/strength.dart';

/// Labels for the optional morning check-in.
const checkInTagLabels = <String, String>{
  'fresh': 'Fresh',
  'normal': 'Normal',
  'sore': 'Sore (DOMS)',
  'stressed': 'Stressed',
  'slept_badly': 'Slept badly',
  'unwell': 'Unwell',
};

class CheckIn {
  const CheckIn({
    required this.date,
    required this.tags,
    required this.at,
    this.note,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
    date: json['date'] as String? ?? '',
    tags: (json['tags'] as List? ?? const []).whereType<String>().toSet(),
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    note: (json['note'] as String?)?.trim().isEmpty == true
        ? null
        : json['note'] as String?,
  );

  final String date;
  final Set<String> tags;
  final DateTime at;
  final String? note;

  String get label =>
      tags.map((tag) => checkInTagLabels[tag] ?? tag).join(' · ');

  Map<String, Object?> toJson() => {
    'date': date,
    'tags': tags.toList()..sort(),
    'at': at.toIso8601String(),
    'note': note,
  };
}

class LocalLog {
  const LocalLog({
    this.checkIns = const [],
    this.strengthDays = const {},
    this.strengthSessions = const [],
    this.onsetOverrides = const {},
    this.profile,
  });

  static const empty = LocalLog();

  final List<CheckIn> checkIns;

  /// Legacy one-tap strength days (no session detail).
  final Set<String> strengthDays;
  final List<StrengthSession> strengthSessions;

  /// User-corrected sleep onset per wake date (yyyy-mm-dd).
  final Map<String, DateTime> onsetOverrides;
  final BodyProfile? profile;

  CheckIn? checkInFor(DateTime day) {
    final key = localDateKey(day);
    for (final checkIn in checkIns) {
      if (checkIn.date == key) return checkIn;
    }
    return null;
  }

  List<CheckIn> recentCheckIns({int days = 7, DateTime? now}) {
    final reference = now ?? DateTime.now();
    final cutoff = localDateKey(reference.subtract(Duration(days: days - 1)));
    final today = localDateKey(reference);
    return checkIns
        .where(
          (checkIn) =>
              checkIn.date.compareTo(cutoff) >= 0 &&
              checkIn.date.compareTo(today) <= 0,
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Every date with strength work: legacy days plus logged sessions.
  List<DateTime> get strengthDates => [
    for (final value in strengthDays)
      if (DateTime.tryParse(value) != null) DateTime.parse(value),
    for (final session in strengthSessions) session.start,
  ];

  LocalLog copyWith({
    List<CheckIn>? checkIns,
    Set<String>? strengthDays,
    List<StrengthSession>? strengthSessions,
    Map<String, DateTime>? onsetOverrides,
    BodyProfile? profile,
  }) => LocalLog(
    checkIns: checkIns ?? this.checkIns,
    strengthDays: strengthDays ?? this.strengthDays,
    strengthSessions: strengthSessions ?? this.strengthSessions,
    onsetOverrides: onsetOverrides ?? this.onsetOverrides,
    profile: profile ?? this.profile,
  );
}

/// Small local-only store for user-entered context.
///
/// Health records stay in Health Connect. Becel stores only what the user
/// typed: check-ins, strength sessions, sleep-onset corrections, and the
/// body profile. Nothing is uploaded.
class LocalStore extends ChangeNotifier {
  LocalStore._();

  static final instance = LocalStore._();
  static const _channel = MethodChannel('com.becel/local');

  LocalLog _log = LocalLog.empty;
  bool _loaded = false;
  Future<void>? _loadFuture;
  bool _nativeAvailable = true;

  LocalLog get log => _log;
  bool get loaded => _loaded;

  Future<void> ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _channel.invokeMethod<String>('read');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final overrides = <String, DateTime>{};
          final rawOverrides = decoded['onsetOverrides'];
          if (rawOverrides is Map) {
            for (final entry in rawOverrides.entries) {
              final at = DateTime.tryParse('${entry.value}');
              if (at != null) overrides['${entry.key}'] = at;
            }
          }
          _log = LocalLog(
            checkIns: (decoded['checkIns'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (entry) => CheckIn.fromJson(Map<String, dynamic>.from(entry)),
                )
                .toList(),
            strengthDays: (decoded['strengthDays'] as List? ?? const [])
                .whereType<String>()
                .toSet(),
            strengthSessions:
                (decoded['strengthSessions'] as List? ?? const [])
                    .whereType<Map>()
                    .map(
                      (entry) => StrengthSession.fromJson(
                        Map<String, dynamic>.from(entry),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => a.start.compareTo(b.start)),
            onsetOverrides: overrides,
            profile: decoded['profile'] is Map
                ? BodyProfile.fromJson(
                    Map<String, dynamic>.from(decoded['profile'] as Map),
                  )
                : null,
          );
        }
      }
    } on MissingPluginException {
      _nativeAvailable = false;
    } on PlatformException {
      _nativeAvailable = false;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<bool> saveCheckIn({
    required DateTime day,
    required Set<String> tags,
    String? note,
  }) async {
    await ensureLoaded();
    final key = localDateKey(day);
    final entry = CheckIn(
      date: key,
      tags: tags,
      at: DateTime.now(),
      note: note?.trim().isEmpty == true ? null : note?.trim(),
    );
    final updated = [
      for (final checkIn in _log.checkIns)
        if (checkIn.date != key) checkIn,
      entry,
    ]..sort((a, b) => a.date.compareTo(b.date));
    return _commit(_log.copyWith(checkIns: updated));
  }

  Future<bool> addStrengthDay(DateTime day) async {
    await ensureLoaded();
    final key = localDateKey(day);
    if (_log.strengthDays.contains(key)) return true;
    return _commit(_log.copyWith(strengthDays: {..._log.strengthDays, key}));
  }

  /// Inserts or replaces a session with the same id.
  Future<bool> saveStrengthSession(StrengthSession session) async {
    await ensureLoaded();
    final updated = [
      for (final existing in _log.strengthSessions)
        if (existing.id != session.id) existing,
      session,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return _commit(_log.copyWith(strengthSessions: updated));
  }

  Future<bool> deleteStrengthSession(String id) async {
    await ensureLoaded();
    return _commit(
      _log.copyWith(
        strengthSessions: [
          for (final session in _log.strengthSessions)
            if (session.id != id) session,
        ],
      ),
    );
  }

  /// Sets or clears (null) a user-corrected sleep onset for a wake date.
  Future<bool> setOnsetOverride(String wakeDate, DateTime? onset) async {
    await ensureLoaded();
    final updated = {..._log.onsetOverrides};
    if (onset == null) {
      updated.remove(wakeDate);
    } else {
      updated[wakeDate] = onset;
    }
    return _commit(_log.copyWith(onsetOverrides: updated));
  }

  Future<bool> saveProfile(BodyProfile profile) async {
    await ensureLoaded();
    return _commit(_log.copyWith(profile: profile));
  }

  Future<bool> clearLocalData() async {
    _log = LocalLog.empty;
    _loaded = true;
    notifyListeners();
    try {
      await _channel.invokeMethod<bool>('clear');
      return true;
    } on MissingPluginException {
      _nativeAvailable = false;
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> shareText(String text) async {
    try {
      return await _channel.invokeMethod<bool>('shareText', {'text': text}) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> exportCsv(String csv) async {
    try {
      return await _channel.invokeMethod<String>('exportCsv', {'csv': csv});
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> _commit(LocalLog log) {
    _log = log;
    notifyListeners();
    return _persist();
  }

  Future<bool> _persist() async {
    if (!_nativeAvailable) return true;
    try {
      final saved = await _channel.invokeMethod<bool>('write', {
        'json': jsonEncode({
          'version': 2,
          'checkIns': _log.checkIns.map((entry) => entry.toJson()).toList(),
          'strengthDays': _log.strengthDays.toList()..sort(),
          'strengthSessions': _log.strengthSessions
              .map((session) => session.toJson())
              .toList(),
          'onsetOverrides': {
            for (final entry in _log.onsetOverrides.entries)
              entry.key: entry.value.toIso8601String(),
          },
          'profile': _log.profile?.toJson(),
        }),
      });
      return saved ?? false;
    } on MissingPluginException {
      _nativeAvailable = false;
      return true;
    } on PlatformException {
      return false;
    }
  }

  @visibleForTesting
  void resetForTest() {
    _log = LocalLog.empty;
    _loaded = false;
    _loadFuture = null;
    _nativeAvailable = true;
  }
}

String localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
