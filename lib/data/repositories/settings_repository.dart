import 'dart:convert';

import '../models/app_settings.dart';
import '../storage/prefs_store.dart';

/// 设置仓库
class SettingsRepository {
  SettingsRepository(this._store);

  final PrefsStore _store;
  static const _key = 'settings.v1';

  AppSettings? _cache;

  Future<AppSettings> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = _store.readString(_key);
    if (raw == null || raw.isEmpty) {
      const defaults = AppSettings();
      _cache = defaults;
      return defaults;
    }

    AppSettings parsed;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        parsed = AppSettings.fromJson(decoded.cast<String, dynamic>());
      } else {
        parsed = const AppSettings();
      }
    } catch (_) {
      parsed = const AppSettings();
    }
    _cache = parsed;
    return parsed;
  }

  Future<void> save(AppSettings settings) async {
    _cache = settings;
    await _store.writeString(_key, jsonEncode(settings.toJson()));
  }
}
