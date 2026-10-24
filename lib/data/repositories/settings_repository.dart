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
    if (_cache != null) return _cache!;
    final raw = _store.readString(_key);
    if (raw == null || raw.isEmpty) return AppSettings();
    try {
      final decoded = jsonDecodeSafe(raw);
      _cache = AppSettings.fromJson(decoded);
    } catch (_) {
      _cache = AppSettings();
    }
    return _cache!;
  }

  Future<void> save(AppSettings settings) async {
    _cache = settings;
    await _store.writeString(_key, jsonEncode(settings.toJson()));
  }
}

Map<String, dynamic> jsonDecodeSafe(String raw) =>
    (jsonDecode(raw) as Map).cast<String, dynamic>();
