import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A saved endpoint: where it lives and the secret that unlocks it.
class IntegrationConfig {
  const IntegrationConfig({required this.url, required this.secret});

  final String url;

  /// The bearer token (companion) or API key (Lidarr).
  final String secret;

  bool get isComplete => url.isNotEmpty && secret.isNotEmpty;
}

/// The external services the app talks to besides the music server.
///
/// Add a value here for each new integration; the store keeps one URL and
/// one secret per value.
enum Integration { companion, lidarr }

/// Secure storage for the integrations' URLs and secrets, kept apart from
/// `StorageService` (which holds the server profiles).
///
/// Same approach as `StorageService`: everything goes to the platform's
/// secure storage, and if that throws (some Android and Linux set-ups) it
/// falls back to obfuscated `shared_preferences`.
class IntegrationConfigStore {
  IntegrationConfigStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
    Future<SharedPreferences>? prefs,
  })  : _secure = secureStorage,
        _prefsFuture = prefs;

  final FlutterSecureStorage _secure;
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs =>
      _prefsFuture ??= SharedPreferences.getInstance();

  static const String _entropyKey = '_integration_fallback_entropy_v1';

  String _urlKey(Integration i) => 'integration_${i.name}_url';
  String _secretKey(Integration i) => 'integration_${i.name}_secret';

  Future<IntegrationConfig?> load(Integration integration) async {
    final url = await _read(_urlKey(integration));
    final secret = await _read(_secretKey(integration));
    if (url == null || secret == null) return null;
    final config = IntegrationConfig(url: url, secret: secret);
    return config.isComplete ? config : null;
  }

  Future<void> save(Integration integration, IntegrationConfig config) async {
    await _write(_urlKey(integration), config.url);
    await _write(_secretKey(integration), config.secret);
  }

  Future<void> clear(Integration integration) async {
    await _delete(_urlKey(integration));
    await _delete(_secretKey(integration));
  }

  Future<String?> _read(String key) async {
    try {
      final val = await _secure.read(key: key);
      if (val != null) return val;
    } catch (e) {
      debugPrint('Integration secure read failed for $key: $e');
    }
    // Missing, or secure storage is unavailable: a write may have fallen back.
    final prefs = await _prefs;
    final val = prefs.getString('fallback_$key');
    return val == null ? null : await _deobfuscate(val);
  }

  Future<void> _write(String key, String value) async {
    try {
      await _secure.write(key: key, value: value);
    } catch (e) {
      debugPrint('Integration secure write failed for $key: $e');
      final prefs = await _prefs;
      await prefs.setString('fallback_$key', await _obfuscate(value));
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _secure.delete(key: key);
    } catch (e) {
      debugPrint('Integration secure delete failed for $key: $e');
    }
    final prefs = await _prefs;
    await prefs.remove('fallback_$key');
  }

  Future<List<int>> _fallbackKey() async {
    final prefs = await _prefs;
    var stored = prefs.getString(_entropyKey);
    if (stored == null || stored.isEmpty) {
      stored = const Uuid().v4() + const Uuid().v4();
      await prefs.setString(_entropyKey, stored);
    }
    return utf8.encode(stored);
  }

  Future<String> _obfuscate(String plain) async {
    final key = await _fallbackKey();
    final bytes = utf8.encode(plain);
    return base64Encode([
      for (var i = 0; i < bytes.length; i++) bytes[i] ^ key[i % key.length],
    ]);
  }

  Future<String> _deobfuscate(String obfuscated) async {
    try {
      final key = await _fallbackKey();
      final bytes = base64Decode(obfuscated);
      return utf8.decode([
        for (var i = 0; i < bytes.length; i++) bytes[i] ^ key[i % key.length],
      ]);
    } catch (_) {
      return '';
    }
  }
}
