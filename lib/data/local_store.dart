import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/profile.dart';

/// Becel is read-only for health data: everything it shows comes from
/// Health Connect. The only thing stored here is the small profile that
/// Health Connect does not carry (age, sex) plus optional calculation
/// settings. Nothing is uploaded.
class LocalStore extends ChangeNotifier {
  LocalStore._();

  static final instance = LocalStore._();
  static const _channel = MethodChannel('com.becel/local');

  BodyProfile? _profile;
  bool _loaded = false;
  Future<void>? _loadFuture;
  bool _nativeAvailable = true;

  BodyProfile? get profile => _profile;
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
        if (decoded is Map<String, dynamic> && decoded['profile'] is Map) {
          _profile = BodyProfile.fromJson(
            Map<String, dynamic>.from(decoded['profile'] as Map),
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

  Future<bool> saveProfile(BodyProfile profile) async {
    await ensureLoaded();
    _profile = profile;
    notifyListeners();
    return _persist();
  }

  Future<bool> clearLocalData() async {
    _profile = null;
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

  /// The last Health Connect read, cached on this phone only so the app can
  /// open with data instead of a blank screen.
  Future<String?> readSnapshotCache() async {
    try {
      return await _channel.invokeMethod<String>('readCache');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> writeSnapshotCache(String json) async {
    try {
      return await _channel.invokeMethod<bool>('writeCache', {'json': json}) ??
          false;
    } on MissingPluginException {
      return false;
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

  Future<bool> _persist() async {
    if (!_nativeAvailable) return true;
    try {
      final saved = await _channel.invokeMethod<bool>('write', {
        'json': jsonEncode({'version': 3, 'profile': _profile?.toJson()}),
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
    _profile = null;
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
